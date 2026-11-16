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
    .venv-tts/bin/python -I tools/gen_voice_qwen.py probe7          # 7차: 지시문 언어·화자별 문장 톤 지표 (build/voice7)
    .venv-tts/bin/python -I tools/gen_voice_qwen.py round7          # 7차: 톤 변형 T0~T4 (docs/design/voice/samples7)

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


def check_speaker(model, name: str | None = None) -> None:
    name = name or CFG["speaker"]
    spk = getattr(model.config.talker_config, "spk_id", None) or {}
    if name.lower() not in spk:
        # mlx-audio는 모르는 화자를 조용히 무시하므로 여기서 멈춘다
        raise SystemExit(f"화자 {name}가 없다. 있는 화자: {sorted(spk)}")


def synth(model, text: str, instruct: str | None, seed: int, max_tokens: int,
          speaker: str | None = None) -> tuple[np.ndarray, float]:
    import mlx.core as mx
    mx.random.seed(seed)
    t0 = time.perf_counter()
    res = list(model.generate_custom_voice(text=text, speaker=speaker or CFG["speaker"], language=CFG["language"],
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


# ---------------------------------------------------------------- 7차: 톤(더 귀엽고 어리게)

TONE = {
    # 사용자: "좋긴 한데 톤이 너무 야하다, 좀 더 귀엽고 어린 톤". 숨소리 섞임, 낮고 느린 톤, 끝을 끄는 말투를 피하게 쓴다.
    "instructs": {
        "ja1": "明るくてかわいい、元気な小さな女の子の声。息を混ぜず、ささやかず、高めの声で、はきはきと一音ずつはっきり話す。語尾は伸ばさず短く切る。",
        "en1": "A bright, cute, cheerful little girl's voice. Clear and crisp with no breathiness and no whispering. "
               "Higher pitch, lively and articulate, every sound distinct, short clean endings without trailing off.",
        "zh1": "明亮、可爱、清脆的小女孩声音。不要气声，不要耳语。音调偏高，活泼开朗，每个音都清清楚楚，句尾干脆利落，不拖音。",
        "ja2": "アニメのマスコットキャラクターのような、とても幼い女の子の声。高くて弾むような、元気いっぱいの明るい声。"
               "息っぽさ、ささやき、色っぽさは一切なし。テンポよく、はきはきと短く話す。",
        "en2": "A very young girl's voice like an anime mascot character. High-pitched, bouncy, super energetic and bright. "
               "Absolutely no breathiness, no whispering, no sultry or sensual tone. Quick, crisp and short.",
        "zh2": "像动画吉祥物角色一样的非常年幼的小女孩声音。声音很高，蹦蹦跳跳，元气满满，非常明亮。"
               "完全没有气声、耳语或性感的感觉。节奏轻快，干脆短促。",
    },
    "letter_suffix": {"ja": "ひらがなを一文字だけ読む。", "en": "Read just this one kana.", "zh": "只读这一个假名。"},
    "sentence": "すみません、出口はどこですか。",
    "sentence_moras": 14,  # す み ま せ ん で ぐ ち は ど こ で す か
    "probe_seeds": [11, 12, 13],
    "output_dir": "docs/design/voice/samples7",
    "takes_dir": "build/voice7/takes",
    "letter_takes": 10,
    "letter_max_tokens": 40,
}


def tone_metrics(y: np.ndarray, moras: int | None = None) -> dict:
    """톤 지표.
    f0_mean: 주기 창(NACF 0.7 이상) F0 평균(Hz). f0_p90: 90백분위(높은 쪽).
    hnr_db: 소리 창(-45 dBFS 위)의 NACF r로 10*log10(r/(1-r))의 중앙값. 숨소리가 섞이면 낮아진다.
    breath_pct: 소리 창 중 NACF 0.45 미만(주기가 거의 없는 잡음) 비율. 무성 자음도 들어간다.
    hf_db: 소리 구간에서 4kHz 위 에너지 / 전체(dB). 숨소리·마찰음이 많으면, 또 맑은 고음이면 커진다.
    rate: 모라 / 소리 창 시간(초). 쉼은 빼고 센다.
    tail_s: 마지막 소리 창의 끝 감쇠(measure의 decay_s와 같은 정의)."""
    f = CFG["f0"]
    tr = f0_track(y, f)
    on = [(t, fr, c) for t, fr, c in tr if c > 0]  # f0_track은 -45 dBFS 아래 창을 c=0으로 둔다
    per = [fr for t, fr, c in on if fr and c >= f["periodic_nacf"]]
    rs = np.clip(np.array([c for _, _, c in on]), 1e-3, 0.999) if on else np.array([0.5])
    hnr = 10 * np.log10(rs / (1 - rs))
    vs, ve = voiced_bounds(y, -45.0)
    seg = y[vs:ve]
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2 if len(seg) else np.ones(2)
    freqs = np.fft.rfftfreq(len(seg), 1 / SR) if len(seg) else np.array([0, 1])
    active = len(on) * f["hop_s"]
    res = {"f0_mean": round(float(np.mean(per)), 1) if per else None,
           "f0_p90": round(float(np.percentile(per, 90)), 1) if per else None,
           "hnr_db": round(float(np.median(hnr)), 1),
           "breath_pct": round(100 * float(np.mean(rs < 0.45)), 1),
           "hf_db": round(10 * math.log10(spec[freqs >= 4000].sum() / spec.sum()), 1),
           "active_s": round(active, 2), "tail_s": measure(y)["decay_s"]}
    if moras:
        res["rate"] = round(moras / active, 2) if active else None
    return res


def variants() -> dict:
    """T0은 6차 기준(지시문 없음). T1~T4는 probe 결과로 고른 것(README 7차)."""
    ins = TONE["instructs"]
    return {
        "T0": {"speaker": "Ono_Anna", "instruct": None, "lang": None, "comment": "6차 기준: Ono_Anna, 지시문 없음"},
        "T1": {"speaker": "Ono_Anna", "instruct": ins["en1"], "lang": "en",
               "comment": "Ono_Anna + 귀엽고 어린 톤(영어 지시문: probe에서 숨소리 지표가 가장 낮고 F0가 오름)"},
        "T2": {"speaker": "Ono_Anna", "instruct": ins["zh2"], "lang": "zh",
               "comment": "Ono_Anna + 더 강하게(중국어 지시문: probe에서 F0가 가장 많이 오름. 영어 en2는 거의 안 바뀜)"},
        "T3": {"speaker": "Vivian", "instruct": ins["en1"], "lang": "en", "comment": "Vivian(밝고 또렷한 젊은 여성) + T1 지시문"},
        "T4": {"speaker": "Serena", "instruct": ins["en1"], "lang": "en",
               "comment": "Serena + T1 지시문(Sohee는 zh1에서 소리가 무너지고 en1에서 F0가 오르지 않아 뺐다)"},
    }


def cmd_probe7() -> None:
    """지시문 언어·화자 고르기: 문장 하나를 시드 3개로 만들어 톤 지표를 잰다."""
    model, _ = load()
    out = ROOT / TONE["takes_dir"] / "probe"
    rows = []
    combos = [("Ono_Anna", None)] + [("Ono_Anna", k) for k in TONE["instructs"]]
    combos += [(spk, k) for spk in ("Vivian", "Serena", "Sohee") for k in (None, "ja1", "zh1", "en1")]
    for spk, key in combos:
        check_speaker(model, spk)
        ms = []
        for seed in TONE["probe_seeds"]:
            raw, gen_s = synth(model, TONE["sentence"], TONE["instructs"].get(key), seed, 200, spk)
            y = normalize(trim_pad(raw), -20.0, -1.0)
            write(out / f"{spk}_{key}_{seed}.wav", y)
            ms.append(tone_metrics(y, TONE["sentence_moras"]))
        agg = {k: round(st.median(m[k] for m in ms if m[k] is not None), 2) for k in ms[0]}
        rows.append({"speaker": spk, "instruct": key, **agg, "takes": ms})
        print(f"{spk:9s} {str(key):4s} " + " ".join(f"{k} {v}" for k, v in agg.items()), flush=True)
    (out / "probe.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def cmd_round7(names: list[str]) -> None:
    out = ROOT / TONE["output_dir"]
    tdir = ROOT / TONE["takes_dir"]
    p = CFG["post"]
    model, _ = load()
    synth(model, "あ。", None, 0, 40)
    mpath = out / "measurements.json"
    report = json.loads(mpath.read_text(encoding="utf-8")) if mpath.exists() else {}
    report.setdefault("variants", {})
    for name in names:
        v = variants()[name]
        spk, ins = v["speaker"], v["instruct"]
        check_speaker(model, spk)
        letter_ins = (ins + " " + TONE["letter_suffix"][v["lang"]]) if ins else CFG["methods"]["Q3"]["instruct"]
        rec = {**v, "letter_instruct": letter_ins, "sentence": [], "words": [], "letters": []}
        files: list[Path] = []
        # 문장: 시드 3개 중 길이가 중앙값인 것
        cands = []
        for seed in TONE["probe_seeds"]:
            raw, gen_s = synth(model, TONE["sentence"], ins, seed, 200, spk)
            y = normalize(trim_pad(raw), p["rms_dbfs"], p["peak_dbfs"])
            write(tdir / name / f"sentence_{seed}.wav", y)
            cands.append({"seed": seed, "gen_s": round(gen_s, 2), **tone_metrics(y, TONE["sentence_moras"])})
        best = sorted(cands, key=lambda c: c["active_s"])[len(cands) // 2]
        rec["sentence"] = {"best": best["seed"], "takes": cands}
        y, _ = sf.read(tdir / name / f"sentence_{best['seed']}.wav", dtype="float64")
        write(out / name / "sentence.wav", y)
        files.append(out / name / "sentence.wav")
        # 단어: 6차와 같은 선택(이상치 없고 소리 길이가 모라 x 0.2초에 가까운 것)
        for word, rom, moras in CFG["words"]:
            wc = []
            for t in range(1, CFG["word_takes"] + 1):
                raw, gen_s = synth(model, f"{word}。", ins, 2000 * t + len(word), CFG["word_max_tokens"], spk)
                y = normalize(trim_pad(raw), p["rms_dbfs"], p["peak_dbfs"])
                write(tdir / name / f"word_{rom}_{t}.wav", y)
                m = measure(y)
                m["flags"] = [f for f in m["flags"] if f not in ("long", "extra_segment")]
                wc.append({"take": t, "gen_s": round(gen_s, 2), **m, **tone_metrics(y, moras)})
            b = min(wc, key=lambda c: (len(c["flags"]), abs(c["voiced"] - moras * CFG["word_mora_s"])))
            y, _ = sf.read(tdir / name / f"word_{rom}_{b['take']}.wav", dtype="float64")
            write(out / name / f"word_{rom}.wav", y)
            files.append(out / name / f"word_{rom}.wav")
            rec["words"].append({"word": word, "rom": rom, "best": b["take"], "takes": wc})
        # 글자: 6차 Q3와 같은 선택
        for kana, rom in CFG["letters"]:
            lc = []
            for t in range(1, TONE["letter_takes"] + 1):
                raw, gen_s = synth(model, f"{kana}。", letter_ins, 1000 * t + ord(kana), TONE["letter_max_tokens"], spk)
                y = normalize(trim_pad(raw), p["rms_dbfs"], p["peak_dbfs"])
                write(tdir / name / f"kana_{rom}_{t}.wav", y)
                m = measure(y)
                lc.append({"take": t, "gen_s": round(gen_s, 2), **m, "score": score(m), **tone_metrics(y)})
            b = min(lc, key=lambda c: c["score"])
            y, _ = sf.read(tdir / name / f"kana_{rom}_{b['take']}.wav", dtype="float64")
            write(out / name / f"kana_{rom}.wav", y)
            files.append(out / name / f"kana_{rom}.wav")
            rec["letters"].append({"kana": kana, "rom": rom, "best": b["take"], "takes": lc})
            print(f"{name} {kana}: best t{b['take']} voiced {b['voiced']} flags {b['flags']} "
                  f"clean {sum(1 for c in lc if not c['flags'])}/10", flush=True)
        write(out / f"preview-{name}.wav", concat(files, CFG["preview_gap_s"]))
        report["variants"][name] = rec
        mpath.write_text(json.dumps(report, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print("wrote", out / f"preview-{name}.wav", flush=True)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("speakers")
    sub.add_parser("probe7")
    r7 = sub.add_parser("round7")
    r7.add_argument("--variants", default="T0,T1,T2,T3,T4")
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
    elif a.cmd == "probe7":
        cmd_probe7()
    elif a.cmd == "round7":
        cmd_round7([x for x in a.variants.split(",") if x])
    else:
        cmd_round6(a.takes, [x for x in a.letters.split(",") if x] or None,
                   [x for x in a.methods.split(",") if x], not a.no_words)


if __name__ == "__main__":
    main()
