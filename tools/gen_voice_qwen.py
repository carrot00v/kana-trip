#!/usr/bin/env python3
"""Qwen3-TTS(MLX)로 가나 한 글자 발음 소리를 시험한다 (6차, docs/design/voice/samples6).

VOICEVOX용 tools/gen_voice.py와 따로 둔다. 앱 파일(KanaTrip/Resources/Voice)은 건드리지 않는다.
준비(Python 3.11~3.13 필요. 이 Mac에는 Comfy Desktop에 든 3.13만 있어 그것으로 가상환경을 만들었다):

    <python3.13> -m venv .venv-tts
    .venv-tts/bin/pip install -U mlx-audio soundfile

실행:

    .venv-tts/bin/python -I tools/gen_voice_qwen.py speakers        # 화자·언어 목록
    .venv-tts/bin/python -I tools/gen_voice_qwen.py round6          # Q1·Q2·Q3, 단어, 미리듣기
    .venv-tts/bin/python -I tools/gen_voice_qwen.py round6 --takes 2 --letters あ,は   # 일부만

모델 mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16 은 첫 실행 때 ~/.cache/huggingface/hub/에 받아진다(4.5GB).
측정은 numpy로 한다. 정의는 gen_voice.py의 measure4와 맞췄다(소리 구간 -45 dBFS, 10ms 창, F0는 정규화 자기상관).
"""

from __future__ import annotations

import argparse
import json
import math
import statistics as st
import time
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parent.parent

CFG = {
    "model": "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16",
    "speaker": "Ono_Anna",
    "language": "Japanese",
    "output_dir": "docs/design/voice/samples6",
    "takes_dir": "build/voice6/takes",          # 후보 전부(커밋하지 않음, build/는 gitignore)
    "app_wav_dir": "docs/design/voice/final/kana",
    "letters": [["あ", "a"], ["か", "ka"], ["さ", "sa"], ["た", "ta"], ["な", "na"], ["は", "ha"],
                ["ま", "ma"], ["や", "ya"], ["ら", "ra"], ["ん", "n"], ["を", "wo"]],
    "words": [["すし", "sushi", 2], ["でぐち", "deguchi", 3], ["おんせん", "onsen", 4]],  # 마지막은 모라 수
    "takes": 5,
    # 샘플링: 기본값(temperature 0.9)은 한 글자 입력에서 3~15초짜리 엉뚱한 말이 자주 붙었다(6차 README).
    # 0.5로 낮추고, 글자는 max_tokens로 길이를 막는다(12.5Hz라 40토큰 = 3.2초). 끝까지 가면 뒤는 무음이라 잘라 낸다.
    "temperature": 0.5,
    "methods": {
        "Q1": {"kind": "single", "text": "{k}。", "max_tokens": 40, "comment": "한 글자만(마침표)"},
        "Q1b": {"kind": "single", "text": "{k}", "max_tokens": 40, "comment": "추가 비교: 한 글자만(마침표 없음)"},
        "Q2": {"kind": "middle", "text": "{k}、{k}、{k}。", "max_tokens": 80,
               "comment": "세 번 읽고 가운데를 무음 기준으로 잘라 냄"},
        "Q3": {"kind": "single", "text": "{k}。", "max_tokens": 40,
               "instruct": "日本語の先生が、ひらがなを一文字だけ、ゆっくりはっきり、落ち着いた声で読み上げる。",
               "comment": "중립 지시문 + 한 글자"},
    },
    "sentence": "すみません、出口はどこですか。",  # 목소리 판단용 문장 하나(짧은 입력이 아니면 안정적인지 비교)
    "word_takes": 4,
    "word_mora_s": 0.2,  # 단어 후보는 소리 길이가 모라 수 x 0.2초에 가까운 것을 고른다(긴 것은 말이 붙은 것)
    "word_max_tokens": 60,
    "measure": {"frame_ms": 10, "silence_dbfs": -45.0, "floor_dbfs": -60.0},
    "f0": {"win_s": 0.025, "hop_s": 0.01, "fmin": 150, "fmax": 700, "periodic_nacf": 0.7, "edge_s": 0.02},
    "split": {"seg_dbfs": -40.0, "min_gap_s": 0.04, "min_seg_s": 0.04, "fade_s": 0.008},
    "post": {"lead_s": 0.05, "tail_s": 0.10, "fade_in_s": 0.005, "fade_out_s": 0.01,
             "rms_dbfs": -20.0, "peak_dbfs": -1.0},
    "limits": {"voiced_min": 0.3, "voiced_max": 0.6, "jump_c": 300, "silent_rms": -60.0},
    "preview_gap_s": 0.5,
}

SR = 24000


# ---------------------------------------------------------------- 측정

def db(x: float) -> float:
    return round(20 * math.log10(x), 1) if x > 0 else -120.0


def frame_rms(y: np.ndarray, n: int) -> np.ndarray:
    k = len(y) // n
    if k == 0:
        return np.zeros(0)
    return np.sqrt(np.mean(y[:k * n].reshape(k, n) ** 2, axis=1))


def voiced_bounds(y: np.ndarray, thr_dbfs: float, frame_ms: int = 10) -> tuple[int, int]:
    n = SR * frame_ms // 1000
    r = frame_rms(y, n)
    idx = np.nonzero(r >= 10 ** (thr_dbfs / 20))[0]
    if len(idx) == 0:
        return 0, 0
    return int(idx[0] * n), int(min(len(y), (idx[-1] + 1) * n))


def segments(y: np.ndarray, thr_dbfs: float, min_gap_s: float, min_seg_s: float) -> list[tuple[int, int]]:
    """thr 이상인 10ms 창의 묶음. min_gap보다 짧은 틈은 잇고, min_seg보다 짧은 묶음은 버린다."""
    n = SR // 100
    on = frame_rms(y, n) >= 10 ** (thr_dbfs / 20)
    segs: list[list[int]] = []
    for i, v in enumerate(on):
        if not v:
            continue
        if segs and (i - segs[-1][1]) * n / SR < min_gap_s:
            segs[-1][1] = i + 1
        else:
            segs.append([i, i + 1])
    return [(a * n, b * n) for a, b in segs if (b - a) * n / SR >= min_seg_s]


def f0_track(y: np.ndarray, f: dict) -> list[tuple[float, float | None, float]]:
    W, H = int(SR * f["win_s"]), int(SR * f["hop_s"])
    tmin, tmax = int(SR / f["fmax"]), int(SR / f["fmin"]) + 1
    out = []
    floor = 10 ** (-45 / 20)
    for s in range(0, len(y) - W - tmax - 1, H):
        t = (s + W / 2) / SR
        x0 = y[s:s + W]
        if np.sqrt(np.mean(x0 ** 2)) < floor:
            out.append((t, None, 0.0))
            continue
        e0 = float(np.dot(x0, x0))
        # 지연마다 정규화 자기상관
        frames = np.lib.stride_tricks.sliding_window_view(y[s:s + W + tmax + 1], W)[tmin:tmax + 1]
        num = frames @ x0
        e1 = np.einsum("ij,ij->i", frames, frames)
        nacf = num / np.sqrt(e0 * np.maximum(e1, 1e-12))
        cmax = float(nacf.max())
        best = None
        for j in range(1, len(nacf) - 1):  # 최댓값의 90% 이상인 첫 봉우리(옥타브 아래 오검출 방지)
            if nacf[j] >= 0.9 * cmax and nacf[j] >= nacf[j - 1] and nacf[j] >= nacf[j + 1]:
                best = j
                break
        if best is None:
            out.append((t, None, cmax))
            continue
        a, b, c = nacf[best - 1], nacf[best], nacf[best + 1]
        den = a - 2 * b + c
        off = 0.5 * (a - c) / den if den else 0.0
        out.append((t, SR / (tmin + best + off), cmax))
    return out


def measure(y: np.ndarray) -> dict:
    """앞뒤 처리 뒤의 파일을 잰다.
    voiced: -45 dBFS 위 구간 길이. decay_s: 소리 구간 RMS의 절반(-6dB) 이상인 마지막 창 끝에서 -45로 사라질 때까지.
    f0_sd_c / f0_jump_c: 주기가 또렷한 창(NACF 0.7 이상, 앞뒤 20ms 제외)의 F0 표준편차와 이웃 창 사이 최대 변화(센트).
    onset_noise_s: 소리 시작에서 첫 주기 창까지(は가 ha인지 보는 근거. 무성 h가 있으면 길어진다).
    segs: -40 dBFS 위 묶음 수(1보다 크면 말이 더 붙었을 수 있다)."""
    m, f, lim = CFG["measure"], CFG["f0"], CFG["limits"]
    vs, ve = voiced_bounds(y, m["silence_dbfs"])
    seg = y[vs:ve]
    rms = float(np.sqrt(np.mean(seg ** 2))) if len(seg) else 0.0
    n = SR // 100
    res = {"duration": round(len(y) / SR, 3), "voiced": round((ve - vs) / SR, 3),
           "rms_dbfs": db(rms), "peak_dbfs": db(float(np.max(np.abs(y))) if len(y) else 0.0)}
    loud = [i for i in range(vs, ve, n) if np.sqrt(np.mean(y[i:i + n] ** 2)) >= rms / 2] if rms else []
    res["decay_s"] = round(max(0.0, (ve - (loud[-1] + n)) / SR), 3) if loud else 0.0
    res["segs"] = len(segments(y, CFG["split"]["seg_dbfs"], 0.06, 0.03))
    tr = f0_track(y, f)
    per = [(t, fr) for t, fr, c in tr if fr and c >= f["periodic_nacf"] and vs / SR <= t <= ve / SR]
    res["periodic"] = round(len(per) / max(1, sum(1 for t, _, _ in tr if vs / SR <= t <= ve / SR)), 2)
    res["onset_noise_s"] = round(per[0][0] - vs / SR, 3) if per else None
    core = [(t, fr) for t, fr in per if per[0][0] + f["edge_s"] <= t <= per[-1][0] - f["edge_s"]] if per else []
    if len(core) >= 3:
        med = st.median(fr for _, fr in core)
        cents = [1200 * math.log2(fr / med) for _, fr in core]
        jumps = [abs(cents[i + 1] - cents[i]) for i in range(len(cents) - 1)
                 if core[i + 1][0] - core[i][0] < 0.015]
        res.update(f0=round(med), f0_sd_c=round(st.pstdev(cents), 1),
                   f0_jump_c=round(max(jumps), 1) if jumps else 0.0,
                   f0_range_c=round(max(cents) - min(cents)))
    else:
        res.update(f0=None, f0_sd_c=None, f0_jump_c=None, f0_range_c=None)
    flags = []
    if res["rms_dbfs"] <= lim["silent_rms"]:
        flags.append("silent")
    if res["voiced"] < lim["voiced_min"]:
        flags.append("short")
    if res["voiced"] > lim["voiced_max"]:
        flags.append("long")
    if res["segs"] > 1:
        flags.append("extra_segment")
    if res["f0_jump_c"] is None:
        flags.append("no_pitch")
    elif res["f0_jump_c"] > lim["jump_c"]:
        flags.append("pitch_jump")
    res["flags"] = flags
    return res


def echo_index(y: np.ndarray) -> float | None:
    """40ms 메아리 지표(약한 근거). 소리 구간 실수 켑스트럼에서 35~45ms 봉우리가
    20~80ms(35~45ms 제외)의 중앙값보다 몇 배인지. 메아리가 있으면 커진다. 앱 소리와 견주어 본다."""
    vs, ve = voiced_bounds(y, -45.0)
    x = y[vs:ve]
    if len(x) < int(0.15 * SR):
        return None
    nfft = 1 << int(math.ceil(math.log2(len(x) * 2)))
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)), nfft)) + 1e-9
    cep = np.abs(np.fft.irfft(np.log(spec)))
    q = np.arange(len(cep)) / SR
    band = (q >= 0.035) & (q <= 0.045)
    ref = ((q >= 0.02) & (q <= 0.08)) & ~band
    return round(float(cep[band].max() / np.median(cep[ref])), 2)


# ---------------------------------------------------------------- 뒤처리

def fade(y: np.ndarray, fin: float, fout: float) -> np.ndarray:
    y = y.copy()
    a, b = int(SR * fin), int(SR * fout)
    if a:
        y[:a] *= np.linspace(0, 1, a, endpoint=False)
    if b:
        y[-b:] *= np.linspace(1, 0, b)
    return y


def trim_pad(y: np.ndarray) -> np.ndarray:
    p = CFG["post"]
    s, e = voiced_bounds(y, CFG["measure"]["floor_dbfs"])
    y = fade(y[s:e], p["fade_in_s"], p["fade_out_s"])
    return np.concatenate([np.zeros(int(SR * p["lead_s"])), y, np.zeros(int(SR * p["tail_s"]))])


def normalize(y: np.ndarray, rms_dbfs: float, peak_dbfs: float) -> np.ndarray:
    s, e = voiced_bounds(y, CFG["measure"]["silence_dbfs"])
    seg = y[s:e]
    if not len(seg):
        return y
    g = 10 ** (rms_dbfs / 20) / float(np.sqrt(np.mean(seg ** 2)))
    g = min(g, 10 ** (peak_dbfs / 20) / float(np.max(np.abs(y))))
    return y * g


def cut_middle(y: np.ndarray) -> tuple[np.ndarray | None, int]:
    """'X、X、X。'에서 가운데 묶음을 잘라 낸다. 묶음이 3개가 아니면 None.
    경계는 묶음 바깥으로 -60 dBFS까지 넓히되 이웃 틈의 가운데를 넘지 않는다."""
    sp = CFG["split"]
    segs = segments(y, sp["seg_dbfs"], sp["min_gap_s"], sp["min_seg_s"])
    if len(segs) != 3:
        return None, len(segs)
    (_, e0), (s1, e1), (s2, _) = segs
    lo, hi = (e0 + s1) // 2, (e1 + s2) // 2
    n = SR // 100
    thr = 10 ** (CFG["measure"]["floor_dbfs"] / 20)
    a = s1
    while a - n >= lo and np.sqrt(np.mean(y[a - n:a] ** 2)) >= thr:
        a -= n
    b = e1
    while b + n <= hi and np.sqrt(np.mean(y[b:b + n] ** 2)) >= thr:
        b += n
    return fade(y[a:b], sp["fade_s"], sp["fade_s"]), 3


def write(path: Path, y: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, np.clip(y, -1, 1), SR, subtype="PCM_16")


def concat(paths: list[Path], gap: float) -> np.ndarray:
    parts = []
    for p in paths:
        y, sr = sf.read(p, dtype="float64")
        assert sr == SR, (p, sr)
        parts += [y, np.zeros(int(SR * gap))]
    return np.concatenate(parts[:-1]) if parts else np.zeros(0)


# ---------------------------------------------------------------- 모델

def load():
    from mlx_audio.tts.utils import load_model
    t0 = time.perf_counter()
    model = load_model(CFG["model"])
    return model, time.perf_counter() - t0


def check_speaker(model) -> None:
    spk = getattr(model.config.talker_config, "spk_id", None) or {}
    if CFG["speaker"].lower() not in spk:
        # mlx-audio는 모르는 화자를 조용히 무시하므로 여기서 멈춘다
        raise SystemExit(f"화자 {CFG['speaker']}가 없다. 있는 화자: {sorted(spk)}")


def synth(model, text: str, instruct: str | None, seed: int, max_tokens: int) -> tuple[np.ndarray, float]:
    import mlx.core as mx
    mx.random.seed(seed)
    t0 = time.perf_counter()
    res = list(model.generate_custom_voice(text=text, speaker=CFG["speaker"], language=CFG["language"],
                                           instruct=instruct, temperature=CFG["temperature"],
                                           max_tokens=max_tokens))
    audio = np.concatenate([np.array(r.audio, dtype=np.float64).reshape(-1) for r in res])
    assert res[0].sample_rate == SR, res[0].sample_rate
    return audio, time.perf_counter() - t0


# ---------------------------------------------------------------- 명령

def cmd_speakers() -> None:
    model, sec = load()
    tc = model.config.talker_config
    print(f"load {sec:.1f}s")
    print("speakers:", json.dumps(getattr(tc, "spk_id", None), ensure_ascii=False))
    print("dialect:", json.dumps(getattr(tc, "spk_is_dialect", None), ensure_ascii=False))
    print("languages:", model.get_supported_languages())
    print("model type:", model.config.tts_model_type)


def score(m: dict) -> float:
    """작을수록 좋다. 이상치 하나에 10점, 그다음 길이 0.45초에서 먼 정도, F0 흔들림."""
    s = 10.0 * len(m["flags"]) + 2.0 * abs(m["voiced"] - 0.45)
    s += (m["f0_sd_c"] or 100) / 100 + (m["f0_jump_c"] or 300) / 300
    return round(s, 3)


def cmd_round6(takes: int, only: list[str] | None, methods: list[str], words: bool = True) -> None:
    out = ROOT / CFG["output_dir"]
    tdir = ROOT / CFG["takes_dir"]
    p = CFG["post"]
    model, load_s = load()
    check_speaker(model)
    print(f"model load {load_s:.1f}s")
    synth(model, "あ。", None, 0, 40)  # 첫 호출 준비(시간 측정에서 뺀다)

    letters = [l for l in CFG["letters"] if not only or l[0] in only]
    mpath = out / "measurements.json"
    old = json.loads(mpath.read_text(encoding="utf-8")) if mpath.exists() else {}
    report: dict = {"model": CFG["model"], "speaker": CFG["speaker"], "language": CFG["language"],
                    "temperature": CFG["temperature"], "load_s": round(load_s, 1),
                    "methods": old.get("methods", {}), "words": [], "app": []}  # 일부 방식만 돌리면 나머지는 이전 값 유지
    for mk in methods:
        meth = CFG["methods"][mk]
        rows = []
        for kana, rom in letters:
            text = meth["text"].format(k=kana)
            cands = []
            for t in range(1, takes + 1):
                raw, gen_s = synth(model, text, meth.get("instruct"), 1000 * t + ord(kana), meth["max_tokens"])
                write(tdir / mk / f"kana_{rom}_{t}_raw.wav", raw)
                info = {"take": t, "gen_s": round(gen_s, 2), "raw_s": round(len(raw) / SR, 3)}
                y = raw
                if meth["kind"] == "middle":
                    y, nseg = cut_middle(raw)
                    info["split_segs"] = nseg
                    if y is None:
                        info["flags"] = ["split_fail"]
                        info["score"] = 99.0
                        cands.append(info)
                        print(f"{mk} {kana} take{t}: 묶음 {nseg}개라 자르지 못함 ({gen_s:.2f}s)")
                        continue
                y = normalize(trim_pad(y), p["rms_dbfs"], p["peak_dbfs"])
                write(tdir / mk / f"kana_{rom}_{t}.wav", y)
                info.update(measure(y))
                info["score"] = score(info)
                cands.append(info)
                print(f"{mk} {kana} take{t}: voiced {info['voiced']:.3f} decay {info['decay_s']:.3f} "
                      f"sd {info['f0_sd_c']} jump {info['f0_jump_c']} onset {info['onset_noise_s']} "
                      f"flags {info['flags']} ({gen_s:.2f}s)")
            ok = [c for c in cands if "voiced" in c]
            best = min(ok, key=lambda c: c["score"]) if ok else None
            if best:
                y, _ = sf.read(tdir / mk / f"kana_{rom}_{best['take']}.wav", dtype="float64")
                write(out / mk / f"kana_{rom}.wav", y)
            rows.append({"kana": kana, "rom": rom, "text": text, "best": best["take"] if best else None,
                         "takes": cands})
        report["methods"][mk] = {"comment": meth["comment"], "text": meth["text"], "max_tokens": meth["max_tokens"],
                                 "instruct": meth.get("instruct"), "letters": rows}
        files = [out / mk / f"kana_{r['rom']}.wav" for r in rows if r["best"]]
        write(out / f"preview-{mk}.wav", concat(files, CFG["preview_gap_s"]))

    # 단어: 목소리 판단용
    wfiles = []
    for word, rom, moras in CFG["words"] if words else []:
        cands = []
        for t in range(1, CFG["word_takes"] + 1):
            raw, gen_s = synth(model, f"{word}。", None, 2000 * t + len(word), CFG["word_max_tokens"])
            y = normalize(trim_pad(raw), p["rms_dbfs"], p["peak_dbfs"])
            write(tdir / "words" / f"word_{rom}_{t}.wav", y)
            m = measure(y)
            m["flags"] = [f for f in m["flags"] if f not in ("long", "extra_segment")]
            cands.append({"take": t, "gen_s": round(gen_s, 2), **m, "echo40": echo_index(y)})
        best = min(cands, key=lambda c: (len(c["flags"]), abs(c["voiced"] - moras * CFG["word_mora_s"])))
        y, _ = sf.read(tdir / "words" / f"word_{rom}_{best['take']}.wav", dtype="float64")
        write(out / "words" / f"word_{rom}.wav", y)
        wfiles.append(out / "words" / f"word_{rom}.wav")
        report["words"].append({"word": word, "rom": rom, "best": best["take"], "takes": cands})
        print(f"word {word}: " + ", ".join(f"t{c['take']} {c['voiced']:.2f}s jump {c['f0_jump_c']}" for c in cands))
    if words:
        write(out / "preview-words.wav", concat(wfiles, CFG["preview_gap_s"]))
        raw, gen_s = synth(model, CFG["sentence"], None, 3001, 200)
        y = normalize(trim_pad(raw), p["rms_dbfs"], p["peak_dbfs"])
        write(out / "preview-sentence.wav", y)
        report["sentence"] = {"text": CFG["sentence"], "gen_s": round(gen_s, 2), "voiced": measure(y)["voiced"],
                              "echo40": echo_index(y)}
        print(f"sentence: {report['sentence']}")
    else:
        report["words"] = old.get("words", [])
        report["sentence"] = old.get("sentence")

    # 지금 앱 소리(같은 11자, 같은 측정)
    app_dir = ROOT / CFG["app_wav_dir"]
    afiles = []
    for kana, rom in letters:
        path = app_dir / f"kana_{rom}.wav"
        y, sr = sf.read(path, dtype="float64")
        assert sr == SR
        afiles.append(path)
        report["app"].append({"kana": kana, "rom": rom, **measure(y), "echo40": echo_index(y)})
    write(out / "preview-app.wav", concat(afiles, CFG["preview_gap_s"]))
    # 앱 단어(つむぎ)의 메아리 지표: Qwen 단어와 견주는 기준
    report["app_words_echo40"] = {w: echo_index(sf.read(ROOT / "docs/design/voice/final/word" / f"word_{w}.wav",
                                                        dtype="float64")[0])
                                  for w in ("sushi", "deguchi", "onsen")
                                  if (ROOT / "docs/design/voice/final/word" / f"word_{w}.wav").exists()}

    mpath.write_text(json.dumps(report, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("wrote", out)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("speakers")
    r6 = sub.add_parser("round6")
    r6.add_argument("--takes", type=int, default=CFG["takes"])
    r6.add_argument("--letters", default="", help="쉼표로 구분한 가나(기본: 11자 전부)")
    r6.add_argument("--methods", default="Q1,Q1b,Q2,Q3")
    r6.add_argument("--no-words", action="store_true")
    r6.add_argument("--temperature", type=float, default=CFG["temperature"])
    a = ap.parse_args()
    if a.cmd == "round6":
        CFG["temperature"] = a.temperature
    if a.cmd == "speakers":
        cmd_speakers()
    else:
        cmd_round6(a.takes, [x for x in a.letters.split(",") if x] or None,
                   [x for x in a.methods.split(",") if x], not a.no_words)


if __name__ == "__main__":
    main()
