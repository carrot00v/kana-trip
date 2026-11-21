#!/usr/bin/env python3
"""VOICEVOX CORE로 발음 소리를 만든다 (1~3차 시험과 앱에 넣는 최종본).

준비와 실행 방법은 docs/design/voice/README.md 참고. 설정은 tools/voice.json.

    .voicevox/venv/bin/python -I tools/gen_voice.py final    # 앱용: 글자·단어 m4a와 voice_index.json (KanaTrip/Resources/Voice)
    .voicevox/venv/bin/python -I tools/gen_voice.py final --kana-only  # 글자만 다시(단어 m4a는 그대로)

    .voicevox/venv/bin/python -I tools/gen_voice.py metas    # 0.vvm에 든 목소리·스타일 id
    .voicevox/venv/bin/python -I tools/gen_voice.py round1   # 1차: 글자 A/B/C, 단어 2속도 (docs/design/voice/samples)
    .voicevox/venv/bin/python -I tools/gen_voice.py shake    # 2차: 글자 떨림 비교 (samples2/shake)
    .voicevox/venv/bin/python -I tools/gen_voice.py giri     # 2차: 기리 목소리 후보 (samples2)
    .voicevox/venv/bin/python -I tools/gen_voice.py round4   # 4차: 글자 0.3~0.45초 후보 A~D (samples4)
    .voicevox/venv/bin/python -I tools/gen_voice.py round5   # 5차: 노래 모델(s0.vvm)로 글자 한 박 (samples5)

외부 패키지 없이 표준 라이브러리만 쓴다(voicevox_core 제외). F0는 정규화 자기상관(NACF)으로 잰다.
"""

from __future__ import annotations

import argparse
import array
import dataclasses
import glob
import io
import json
import math
import statistics as st
import time
import wave
from pathlib import Path

from voicevox_core import AudioQuery
from voicevox_core.blocking import Onnxruntime, OpenJtalk, Synthesizer, VoiceModelFile

ROOT = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------- 준비

def load_config(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def open_synthesizer(cfg: dict) -> tuple[Synthesizer, VoiceModelFile, float]:
    t0 = time.perf_counter()
    core = ROOT / cfg["core_dir"]
    libs = sorted(glob.glob(str(core / "onnxruntime" / "lib" / "libvoicevox_onnxruntime*.dylib")))
    if not libs:
        raise SystemExit(f"ONNX Runtime이 없다: {core / 'onnxruntime/lib'}")
    ort = Onnxruntime.load_once(filename=libs[0])
    dict_dirs = sorted(p for p in (core / "dict").glob("open_jtalk_dic_utf_8-*") if p.is_dir())
    if not dict_dirs:
        raise SystemExit(f"Open JTalk 사전이 없다: {core / 'dict'}")
    synth = Synthesizer(ort, OpenJtalk(dict_dirs[-1]), cpu_num_threads=cfg["cpu_num_threads"])
    model = VoiceModelFile.open(core / cfg["vvm"])
    synth.load_voice_model(model)
    return synth, model, time.perf_counter() - t0


def metas_of(model: VoiceModelFile) -> list[dict]:
    return [
        {"name": c.name, "styles": [{"name": s.name, "id": int(s.id), "type": s.type} for s in c.styles]}
        for c in model.metas
    ]


# ---------------------------------------------------------------- audio query

def phonemes(query: AudioQuery) -> list[str]:
    """박마다 '자음+모음'을 적는다. 무음 박(pause)은 'pau'."""
    out = []
    for ap in query.accent_phrases:
        for m in ap.moras:
            out.append(f"{m.consonant or ''}{'+' if m.consonant else ''}{m.vowel}")
        if ap.pause_mora is not None:
            out.append("pau")
    return out


def mora_detail(query: AudioQuery) -> list[dict]:
    return [
        {
            "text": m.text,
            "consonant": m.consonant,
            "consonant_length": None if m.consonant_length is None else round(m.consonant_length, 3),
            "vowel": m.vowel,
            "vowel_length": round(m.vowel_length, 3),
            "pitch": round(m.pitch, 3),
        }
        for ap in query.accent_phrases
        for m in ap.moras
    ]


def stretch_moras(query: AudioQuery, mora_seconds: float, min_vowel: float,
                  only_index: int | None = None) -> AudioQuery:
    """각 박의 자음+모음 길이가 mora_seconds가 되도록 모음을 늘린다(자음은 그대로). 쉼 박은 그대로.
    only_index를 주면 전체에서 그 순번의 박만 늘린다."""
    phrases = []
    k = 0
    for ap in query.accent_phrases:
        moras = []
        for m in ap.moras:
            if only_index is None or k == only_index:
                cons = m.consonant_length or 0.0
                m = dataclasses.replace(m, vowel_length=max(min_vowel, mora_seconds - cons))
            moras.append(m)
            k += 1
        phrases.append(dataclasses.replace(ap, moras=moras))
    return dataclasses.replace(query, accent_phrases=phrases)


def flatten_pitch(query: AudioQuery, pitch: float) -> AudioQuery:
    """유성 박(높이 > 0)의 높이를 모두 같은 값으로 둔다."""
    phrases = []
    for ap in query.accent_phrases:
        moras = [dataclasses.replace(m, pitch=pitch) if m.pitch > 0 else m for m in ap.moras]
        phrases.append(dataclasses.replace(ap, moras=moras))
    return dataclasses.replace(query, accent_phrases=phrases)


def timeline(query: AudioQuery) -> list[dict]:
    """합성된 wav 기준으로 박마다 시작·모음 시작·끝 시각(초)을 계산한다. speed_scale을 반영한다."""
    sp = query.speed_scale
    t = query.pre_phoneme_length / sp
    out = []
    for i, ap in enumerate(query.accent_phrases):
        for m in ap.moras:
            c = (m.consonant_length or 0.0) / sp
            v = m.vowel_length / sp
            out.append({"phrase": i, "text": m.text, "vowel": m.vowel, "pitch": m.pitch,
                        "start": t, "vowel_start": t + c, "end": t + c + v})
            t += c + v
        pm = ap.pause_mora
        if pm is not None:  # 코어가 dict로 돌려줄 때가 있다
            t += (pm["vowel_length"] if isinstance(pm, dict) else pm.vowel_length) / sp
    return out


# ---------------------------------------------------------------- 소리 처리

def pcm_of(wav_bytes: bytes) -> tuple[array.array, int]:
    with wave.open(io.BytesIO(wav_bytes)) as w:
        assert w.getsampwidth() == 2, "16bit PCM만 처리한다"
        rate, ch = w.getframerate(), w.getnchannels()
        data = array.array("h", w.readframes(w.getnframes()))
    if ch == 2:
        data = array.array("h", data[0::2])
    return data, rate


def read_wav(path: Path) -> tuple[array.array, int]:
    return pcm_of(path.read_bytes())


def write_wav(path: Path, samples: array.array, rate: int) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(samples.tobytes())


def dbfs(value: float) -> float:
    return round(20 * math.log10(value / 32768), 1) if value > 0 else -120.0


def voiced_bounds(samples: array.array, rate: int, frame_ms: int, silence_dbfs: float) -> tuple[int, int]:
    n = max(1, rate * frame_ms // 1000)
    threshold = 32768 * 10 ** (silence_dbfs / 20)
    idx = []
    for k, i in enumerate(range(0, len(samples), n)):
        frame = samples[i:i + n]
        if math.sqrt(sum(s * s for s in frame) / len(frame)) >= threshold:
            idx.append(k)
    if not idx:
        return 0, 0
    return idx[0] * n, min(len(samples), (idx[-1] + 1) * n)


def measure(samples: array.array, rate: int, frame_ms: int, silence_dbfs: float) -> dict:
    start, end = voiced_bounds(samples, rate, frame_ms, silence_dbfs)
    voiced = samples[start:end]
    rms_voiced = math.sqrt(sum(s * s for s in voiced) / len(voiced)) if voiced else 0.0
    return {
        "duration": round(len(samples) / rate, 3),
        "voiced": round((end - start) / rate, 3),
        "lead_silence": round(start / rate, 3),
        "tail_silence": round((len(samples) - end) / rate, 3),
        "peak_dbfs": dbfs(max((abs(s) for s in samples), default=0)),
        "rms_dbfs": dbfs(rms_voiced),
    }


def silence(rate: int, seconds: float) -> array.array:
    return array.array("h", [0] * int(round(rate * seconds)))


def fade(samples: array.array, rate: int, fade_in: float = 0.0, fade_out: float = 0.0,
         out_end: int | None = None) -> array.array:
    """선형 페이드. out_end를 주면 그 지점에서 끝나는 페이드아웃을 걸고 그 뒤는 0으로 둔다."""
    out = array.array("h", samples)
    n_in = int(rate * fade_in)
    for i in range(min(n_in, len(out))):
        out[i] = int(out[i] * i / n_in)
    if fade_out > 0:
        end = len(out) if out_end is None else out_end
        n_out = int(rate * fade_out)
        begin = max(0, end - n_out)
        for i in range(begin, end):
            out[i] = int(out[i] * (end - i) / n_out)
        for i in range(end, len(out)):
            out[i] = 0
    return out


def normalize(samples: array.array, rate: int, m_cfg: dict, n_cfg: dict) -> tuple[array.array, float]:
    """소리 구간 RMS를 목표값으로 맞춘다. 피크가 한계를 넘으면 이득을 줄인다. 이득(dB)을 돌려준다."""
    s, e = voiced_bounds(samples, rate, m_cfg["frame_ms"], m_cfg["silence_dbfs"])
    seg = samples[s:e]
    if not seg:
        return array.array("h", samples), 0.0
    rms = math.sqrt(sum(x * x for x in seg) / len(seg))
    peak = max(abs(x) for x in samples)
    gain = 10 ** (n_cfg["rms_dbfs"] / 20) * 32768 / rms
    gain = min(gain, 10 ** (n_cfg["peak_dbfs"] / 20) * 32767 / peak)
    out = array.array("h", (max(-32768, min(32767, int(round(x * gain)))) for x in samples))
    return out, round(20 * math.log10(gain), 1)


# ---------------------------------------------------------------- F0 (NACF)

def f0_track(samples: array.array, rate: int, f: dict) -> list[tuple[float, float | None, float]]:
    """(시각, F0 Hz 또는 None, NACF 최댓값) 목록. rate_div배 줄여 계산한다."""
    d = f["rate_div"]
    y = [sum(samples[i:i + d]) / d for i in range(0, len(samples) - d + 1, d)]
    r = rate / d
    W = int(r * f["win_s"])
    H = int(r * f["hop_s"])
    tmin, tmax = int(r / f["fmax"]), int(r / f["fmin"]) + 1
    out = []
    for s in range(0, len(y) - W - tmax - 1, H):
        t = (s + W / 2) / r
        x0 = y[s:s + W]
        e0 = sum(v * v for v in x0)
        if e0 / W < (32768 * 10 ** (-45 / 20)) ** 2:
            out.append((t, None, 0.0))
            continue
        e1 = sum(v * v for v in y[s + tmin:s + tmin + W])
        nacf = {}
        for tau in range(tmin, tmax + 1):
            num = 0.0
            for j in range(W):
                num += x0[j] * y[s + j + tau]
            nacf[tau] = num / math.sqrt(e0 * e1) if e1 > 0 else 0.0
            e1 += y[s + tau + W] ** 2 - y[s + tau] ** 2
        cmax = max(nacf.values())
        # 옥타브 아래로 잘못 잡지 않도록, 최댓값의 90% 이상인 첫 봉우리를 고른다
        best = None
        for tau in range(tmin + 1, tmax):
            if nacf[tau] >= 0.9 * cmax and nacf[tau] >= nacf[tau - 1] and nacf[tau] >= nacf[tau + 1]:
                best = tau
                break
        if best is None:
            out.append((t, None, cmax))
            continue
        a, b, c = nacf[best - 1], nacf[best], nacf[best + 1]
        den = a - 2 * b + c
        off = 0.5 * (a - c) / den if den else 0.0
        out.append((t, r / (best + off), cmax))
    return out


def shake_stats(track, t0: float, t1: float, f: dict) -> dict | None:
    """t0~t1 구간의 떨림 수치.

    periodic: NACF가 기준 이상(주기가 또렷한)인 창의 비율
    jitter_c: 이웃한 주기 창 사이 F0 변화의 평균(센트, 10ms당)
    sd_c, range_c: 주기 창 F0의 표준편차·최대-최소(센트, 중앙값 기준)
    """
    frames = [(fr, c) for t, fr, c in track if t0 <= t <= t1]
    if len(frames) < 3:
        return None
    thr = f["periodic_nacf"]
    per = [fr if (fr and c >= thr) else None for fr, c in frames]
    vals = [v for v in per if v]
    res = {"frames": len(frames), "periodic": round(len(vals) / len(frames), 2),
           "nacf_med": round(st.median(c for _, c in frames), 2)}
    if len(vals) < 3:
        return {**res, "f0": None, "jitter_c": None, "sd_c": None, "range_c": None}
    med = st.median(vals)
    cents = [1200 * math.log2(v / med) if v else None for v in per]
    # 중앙값에서 700센트 넘게 벗어난 창은 옥타브 오검출로 보고 뺀다(개수는 따로 센다)
    octave = sum(1 for c in cents if c is not None and abs(c) > 700)
    cents = [c if (c is not None and abs(c) <= 700) else None for c in cents]
    diffs = [abs(cents[i + 1] - cents[i]) for i in range(len(cents) - 1)
             if cents[i] is not None and cents[i + 1] is not None]
    cs = [c for c in cents if c is not None]
    if len(cs) < 3:
        return {**res, "f0": round(med), "jitter_c": None, "sd_c": None, "range_c": None, "octave_err": octave}
    return {**res, "f0": round(med), "jitter_c": round(st.mean(diffs), 1) if diffs else None,
            "sd_c": round(st.pstdev(cs), 1), "range_c": round(max(cs) - min(cs)), "octave_err": octave}


# ---------------------------------------------------------------- 1차

def cmd_round1(cfg: dict, synth: Synthesizer, model: VoiceModelFile, load_seconds: float) -> None:
    out_dir = ROOT / cfg["output_dir"]
    out_dir.mkdir(parents=True, exist_ok=True)
    m_cfg = cfg["measure"]
    results = []
    preview_parts: dict[str, list[array.array]] = {}
    rate_seen = None

    def kana_query(candidates: list[str], style_id: int) -> tuple[AudioQuery, str, list[str]]:
        errors = []
        for kana in candidates:
            try:
                return synth.create_audio_query_from_kana(kana, style_id), kana, errors
            except Exception as e:  # 받아들이지 않는 표기면 다음 후보
                errors.append(f"{kana}: {type(e).__name__}: {e}")
        raise RuntimeError("; ".join(errors))

    def emit(voice: dict, name: str, kind: str, query: AudioQuery, extra: dict) -> None:
        nonlocal rate_seen
        t = time.perf_counter()
        wav_bytes = synth.synthesis(query, voice["style_id"])
        synth_seconds = time.perf_counter() - t
        samples, rate = pcm_of(wav_bytes)
        rate_seen = rate_seen or rate
        path = out_dir / f"{voice['slug']}-{name}.wav"
        write_wav(path, samples, rate)
        row = {
            "file": path.name, "voice": voice["slug"], "kind": kind,
            "synth_seconds": round(synth_seconds, 3), "phonemes": phonemes(query),
            "query_kana": query.kana, "speed_scale": query.speed_scale,
            "pre": query.pre_phoneme_length, "post": query.post_phoneme_length,
            "moras": mora_detail(query), "sampling_rate": rate, "bytes": path.stat().st_size,
            **extra, **measure(samples, rate, m_cfg["frame_ms"], m_cfg["silence_dbfs"]),
        }
        results.append(row)
        print(f"{row['file']:<40} {row['duration']:>6.3f}s  소리 {row['voiced']:>6.3f}s  "
              f"rms {row['rms_dbfs']:>6.1f}dB  {' '.join(row['phonemes'])}  ({synth_seconds:.2f}s)")
        if extra.get("preview"):
            preview_parts.setdefault(voice["slug"], []).append(samples)

    pv = cfg["preview"]
    for voice in cfg["voices"]:
        sid = voice["style_id"]
        for letter in cfg["letters"]:
            base, used, rejected = kana_query(letter["aquestalk"], sid)
            for key, var in cfg["letter_variants"].items():
                q = base
                if "speed_scale" in var:
                    q = dataclasses.replace(q, speed_scale=var["speed_scale"])
                if "mora_seconds" in var:
                    q = stretch_moras(q, var["mora_seconds"], var["min_vowel_seconds"])
                if "pre_phoneme_length" in var:
                    q = dataclasses.replace(q, pre_phoneme_length=var["pre_phoneme_length"],
                                            post_phoneme_length=var["post_phoneme_length"])
                emit(voice, f"{letter['romaji']}-{key}", "letter", q, {
                    "input": used, "rejected_inputs": rejected, "kana": letter["kana"], "variant": key,
                    "preview": key == pv["letter_variant"],
                })
        for word in cfg["words"]:
            base = synth.create_audio_query(word["text"], sid)
            for key, speed in cfg["word_speeds"].items():
                q = dataclasses.replace(base, speed_scale=speed)
                emit(voice, f"{word['romaji']}-{key}", "word", q, {
                    "input": word["text"], "variant": key, "preview": key == pv["word_speed"],
                })

    # 미리듣기: 목소리별로 글자 C안 → 단어 느린 속도 순서, 사이 gap_seconds
    gap = silence(rate_seen, pv["gap_seconds"])
    joined = array.array("h")
    for voice in cfg["voices"]:
        for part in preview_parts.get(voice["slug"], []):
            joined.extend(part)
            joined.extend(gap)
    write_wav(out_dir / pv["file"], joined, rate_seen)
    print(f"{pv['file']}: {len(joined) / rate_seen:.1f}s")

    summary = {"voicevox_core": "0.17.1", "vvm": cfg["vvm"], "cpu_num_threads": cfg["cpu_num_threads"],
               "load_seconds": round(load_seconds, 2), "metas": metas_of(model), "files": results}
    with (out_dir / "measurements.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- 2차: 글자 하나 만들기

@dataclasses.dataclass
class Letter:
    samples: array.array
    rate: int
    vowel_span: tuple[float, float]   # 출력 파일 기준 모음 구간(초)
    query: AudioQuery
    synth_seconds: float


def make_letter(synth: Synthesizer, style_id: int, kana: str, method: dict, common: dict,
                voice_adj: dict | None = None) -> Letter:
    """글자 한 박을 method대로 만든다. voice_adj는 후보 목소리의 pitch/intonation/speed 조정."""
    voice_adj = voice_adj or {}
    n_ctx = method.get("context", 1)
    carrier = method.get("carrier")  # 글자 뒤에 붙여 합성하고 잘라 낼 박 (예: "ッ", "タ")
    if carrier:
        text = kana + carrier
    else:
        text = "、".join([kana] * n_ctx)
    q = synth.create_audio_query_from_kana(text, style_id)
    if "mora_seconds" in method:
        q = stretch_moras(q, method["mora_seconds"], common["min_vowel_seconds"],
                          only_index=0 if carrier else None)
    if method.get("flat_pitch"):
        tl = timeline(q)
        q = flatten_pitch(q, tl[0 if carrier else len(tl) // 2]["pitch"])
    q = dataclasses.replace(
        q,
        pre_phoneme_length=common["pre"], post_phoneme_length=common["post"],
        intonation_scale=method.get("intonation_scale", voice_adj.get("intonation_scale", q.intonation_scale)),
        pitch_scale=voice_adj.get("pitch_scale", q.pitch_scale),
        speed_scale=voice_adj.get("speed_scale", q.speed_scale),
    )
    t = time.perf_counter()
    samples, rate = pcm_of(synth.synthesis(q, style_id))
    synth_seconds = time.perf_counter() - t
    tl = timeline(q)

    if carrier:
        m = tl[0]
        a = max(0, int((m["start"] - 0.02) * rate))
        b = min(len(samples), int((m["end"] + method.get("carrier_tail", 0.0)) * rate))
        body = fade(samples[a:b], rate, fade_in=common["fade_in"], fade_out=method.get("fade_out", 0.03))
        out = silence(rate, common["pre"])
        out.extend(body)
        out.extend(silence(rate, common["post"]))
        off = common["pre"] - (m["start"] - 0.02)
        span = (m["vowel_start"] + off, m["end"] + off - method.get("fade_out", 0.03))
    elif n_ctx > 1:
        mid = [m for m in tl if m["phrase"] == n_ctx // 2]
        start, vstart, end = mid[0]["start"], mid[0]["vowel_start"], mid[-1]["end"]
        a = max(0, int((start - 0.02) * rate))
        b = min(len(samples), int((end + common["ctx_tail"]) * rate))
        body = fade(samples[a:b], rate, fade_in=common["fade_in"], fade_out=0.03)
        out = silence(rate, common["pre"])
        out.extend(body)
        out.extend(silence(rate, common["post"]))
        off = common["pre"] - (start - 0.02)
        span = (vstart + off, end + off)
    else:
        m = tl[0]
        span = (m["vowel_start"], m["end"])
        out = fade(samples, rate, fade_in=0.0)
        if method.get("fade_out"):
            s, e = voiced_bounds(out, rate, 10, -45.0)
            out = fade(out, rate, fade_out=method["fade_out"], out_end=e)
    return Letter(out, rate, span, q, synth_seconds)


def analyze_letter(letter: Letter, cfg2: dict, m_cfg: dict) -> dict:
    f = cfg2["f0"]
    tr = f0_track(letter.samples, letter.rate, f)
    v0, v1 = letter.vowel_span
    edge = f["edge_s"]
    return {
        **measure(letter.samples, letter.rate, m_cfg["frame_ms"], m_cfg["silence_dbfs"]),
        "vowel_span": [round(v0, 3), round(v1, 3)],
        "shake": shake_stats(tr, v0 + edge, v1 - edge, f),
        "shake_tail": shake_stats(tr, max(v0 + edge, v1 - 0.10), v1 - edge, f),
    }


def word_vowel_baseline(synth: Synthesizer, cfg: dict, cfg2: dict, style_id: int) -> dict:
    """1차 단어(기본 속도) 속 모음들의 떨림 수치. 글자와 비교할 기준선."""
    f = cfg2["f0"]
    rows = []
    for word in cfg["words"]:
        q = synth.create_audio_query(word["text"], style_id)
        samples, rate = pcm_of(synth.synthesis(q, style_id))
        tr = f0_track(samples, rate, f)
        for m in timeline(q):
            if m["vowel"] in ("a", "i", "u", "e", "o") and m["pitch"] > 0 and m["end"] - m["vowel_start"] >= 0.06:
                s = shake_stats(tr, m["vowel_start"] + 0.01, m["end"] - 0.01, f)
                if s:
                    rows.append({"word": word["text"], "mora": m["text"], **s})
    def med(key):
        vals = [r[key] for r in rows if r.get(key) is not None]
        return round(st.median(vals), 2) if vals else None
    return {"segments": rows, "median": {k: med(k) for k in ("periodic", "nacf_med", "jitter_c", "sd_c", "range_c")}}


def cmd_shake(cfg: dict, synth: Synthesizer) -> None:
    cfg2 = cfg["round2"]
    sh = cfg2["shake"]
    m_cfg = cfg["measure"]
    out_dir = ROOT / cfg2["output_dir"] / "shake"
    out_dir.mkdir(parents=True, exist_ok=True)
    sid = sh["voice"]["style_id"]

    baseline = word_vowel_baseline(synth, cfg, cfg2, sid)
    print("단어 속 모음 기준선(중앙값):", baseline["median"])

    rows = []
    for letter in sh["letters"]:
        for key, method in sh["methods"].items():
            try:
                lt = make_letter(synth, sid, letter["aquestalk"], method, sh["common"])
            except Exception as e:
                rows.append({"romaji": letter["romaji"], "method": key, "error": f"{type(e).__name__}: {e}"})
                print(f"{letter['romaji']}-{key}: 실패 {e}")
                continue
            name = f"{sh['voice']['slug']}-{letter['romaji']}-{key}.wav"
            write_wav(out_dir / name, lt.samples, lt.rate)
            a = analyze_letter(lt, cfg2, m_cfg)
            row = {"file": name, "kana": letter["kana"], "romaji": letter["romaji"], "method": key,
                   "input": letter["aquestalk"], "query_kana": lt.query.kana, "phonemes": phonemes(lt.query),
                   "synth_seconds": round(lt.synth_seconds, 3), **a}
            rows.append(row)
            s = a["shake"] or {}
            print(f"{name:<34} 소리 {a['voiced']:.2f}s rms {a['rms_dbfs']:>6.1f} "
                  f"주기 {s.get('periodic')} nacf {s.get('nacf_med')} jit {s.get('jitter_c')} sd {s.get('sd_c')}")

    # 방법별 요약
    summary = {}
    for key in sh["methods"]:
        rs = [r for r in rows if r.get("method") == key and "error" not in r]
        def agg(fn, k):
            vals = [r["shake"][k] for r in rs if r.get("shake") and r["shake"].get(k) is not None]
            return round(fn(vals), 2) if vals else None
        summary[key] = {
            "letters": len(rs),
            "voiced_min": min((r["voiced"] for r in rs), default=None),
            "voiced_mean": round(st.mean(r["voiced"] for r in rs), 3) if rs else None,
            "periodic_med": agg(st.median, "periodic"),
            "periodic_min": agg(min, "periodic"),
            "jitter_med": agg(st.median, "jitter_c"),
            "jitter_max": agg(max, "jitter_c"),
            "sd_med": agg(st.median, "sd_c"),
            "sd_max": agg(max, "sd_c"),
            "rms_range": [min((r["rms_dbfs"] for r in rs), default=None), max((r["rms_dbfs"] for r in rs), default=None)],
            "broken": [r["romaji"] for r in rs if r["voiced"] < 0.2 or not r.get("shake") or (r["shake"]["periodic"] or 0) < 0.3],
        }
        print(key, summary[key])

    with (out_dir / "measurements.json").open("w", encoding="utf-8") as f:
        json.dump({"voice": sh["voice"], "methods": sh["methods"], "baseline_word_vowels": baseline,
                   "summary": summary, "files": rows}, f, ensure_ascii=False, indent=1)

    # 떨림 비교 미리듣기: 글자마다 1차 C안 → 새 방법(giri.letter_method), 음량을 맞춘다
    pv = sh["preview"]
    new_key = cfg2["giri"]["letter_method"]
    gap = None
    joined = array.array("h")
    for rom in pv["letters"]:
        old, rate = read_wav(ROOT / pv["round1_dir"] / pv["round1_pattern"].format(romaji=rom))
        new, _ = read_wav(out_dir / f"{sh['voice']['slug']}-{rom}-{new_key}.wav")
        gap = gap or silence(rate, pv["gap_seconds"])
        for part in (old, new):
            joined.extend(normalize(part, rate, m_cfg, cfg2["normalize"])[0])
            joined.extend(gap)
    write_wav(ROOT / cfg2["output_dir"] / pv["file"], joined, rate)
    print(f"{pv['file']}: {len(joined) / rate:.1f}s (1차 C안 → {new_key})")


# ---------------------------------------------------------------- 2차: 기리 목소리 후보

def cmd_giri(cfg: dict, synth: Synthesizer) -> None:
    cfg2 = cfg["round2"]
    g = cfg2["giri"]
    sh = cfg2["shake"]
    m_cfg = cfg["measure"]
    out_dir = ROOT / cfg2["output_dir"]
    out_dir.mkdir(parents=True, exist_ok=True)
    method = sh["methods"][g["letter_method"]]
    letters = {l["romaji"]: l for l in sh["letters"]}
    rows = []

    for cand in g["candidates"]:
        sid = cand["style_id"]
        adj = {k: cand[k] for k in ("pitch_scale", "intonation_scale", "speed_scale") if k in cand}
        parts = []

        def keep(name: str, kind: str, samples: array.array, rate: int, extra: dict) -> None:
            norm, gain = normalize(samples, rate, m_cfg, cfg2["normalize"])
            path = out_dir / f"{cand['slug']}-{name}.wav"
            write_wav(path, norm, rate)
            row = {"file": path.name, "candidate": cand["slug"], "kind": kind, "gain_db": gain,
                   **extra, **measure(norm, rate, m_cfg["frame_ms"], m_cfg["silence_dbfs"])}
            rows.append(row)
            parts.append((norm, rate))
            sh_ = extra.get("shake") or {}
            print(f"{path.name:<44} {row['duration']:.2f}s 소리 {row['voiced']:.2f}s rms {row['rms_dbfs']:>6.1f} "
                  f"peak {row['peak_dbfs']:>5.1f} 이득 {gain:+.1f}dB  {extra.get('query_kana')}  "
                  f"주기 {sh_.get('periodic')} jit {sh_.get('jitter_c')}")

        for rom in g["letters"]:
            lt = make_letter(synth, sid, letters[rom]["aquestalk"], method, sh["common"], adj)
            a = analyze_letter(lt, cfg2, m_cfg)
            keep(rom, "letter", lt.samples, lt.rate, {
                "query_kana": lt.query.kana, "phonemes": phonemes(lt.query), "shake": a["shake"],
                "synth_seconds": round(lt.synth_seconds, 3)})

        for w in g["words"] + [g["phrase"]]:
            is_phrase = w is g["phrase"]
            q = (synth.create_audio_query_from_kana(w["kana"], sid) if "kana" in w
                 else synth.create_audio_query(w["text"], sid))
            speed = (w.get("speed", 1.0) if is_phrase else g["word_speed"]) * adj.get("speed_scale", 1.0)
            q = dataclasses.replace(q, speed_scale=speed,
                                    pitch_scale=adj.get("pitch_scale", q.pitch_scale),
                                    intonation_scale=adj.get("intonation_scale", q.intonation_scale))
            t = time.perf_counter()
            samples, rate = pcm_of(synth.synthesis(q, sid))
            keep(w["romaji"], "phrase" if is_phrase else "word", samples, rate, {
                "input": w.get("kana") or w["text"], "query_kana": q.kana, "phonemes": phonemes(q),
                "moras": mora_detail(q), "synth_seconds": round(time.perf_counter() - t, 3)})

        rate = parts[0][1]
        gap = silence(rate, g["gap_seconds"])
        joined = array.array("h")
        for s, _ in parts:
            joined.extend(s)
            joined.extend(gap)
        write_wav(out_dir / f"preview-{cand['slug']}.wav", joined, rate)
        print(f"preview-{cand['slug']}.wav: {len(joined) / rate:.1f}s")

    with (out_dir / "measurements.json").open("w", encoding="utf-8") as f:
        json.dump({"letter_method": g["letter_method"], "normalize": cfg2["normalize"],
                   "candidates": g["candidates"], "files": rows}, f, ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- 3차: 주기 단위 측정

def pitch_marks(samples: array.array, rate: int, t0: float, t1: float, f0_hint: float) -> list[int]:
    """t0~t1 구간에서 한 주기마다 표시(봉우리 위치)를 찍는다. 극성은 주기 편차가 작은 쪽을 고른다."""
    w = 5
    a, b = max(0, int(t0 * rate)), min(len(samples), int(t1 * rate))
    if b - a < 4 * rate / f0_hint:
        return []
    x = [sum(samples[i:i + w]) / w for i in range(a, b)]
    best = []
    for sign in (1, -1):
        T = rate / f0_hint
        lo, hi = 0, int(T)
        m = max(range(lo, min(hi, len(x))), key=lambda k: sign * x[k])
        marks = [m]
        T0 = T
        while True:
            lo, hi = m + max(1, int(0.7 * T)), m + int(1.3 * T) + 1
            if hi >= len(x):
                break
            n = max(range(lo, hi), key=lambda k: sign * x[k])
            # 주기 추정이 처음 값의 0.6~1.6배를 벗어나지 않게 묶는다(0으로 줄어 무한 반복하는 것 방지)
            T = min(1.6 * T0, max(0.6 * T0, 0.7 * T + 0.3 * (n - m)))
            marks.append(n)
            m = n
        per = [marks[i + 1] - marks[i] for i in range(len(marks) - 1)]
        if len(per) >= 3:
            cv = st.pstdev(per) / st.mean(per)
            if not best or cv < best[0]:
                best = [cv, [a + k for k in marks]]
    return best[1] if best else []


def mod_peaks(series: list[float], fs: float, bands: list[tuple[float, float]]) -> dict:
    """해닝 창 DFT로 대역별 최대 사인파 진폭과 그 주파수를 구한다."""
    n = len(series)
    w = [0.5 - 0.5 * math.cos(2 * math.pi * k / (n - 1)) for k in range(n)]
    sw = sum(w)
    out = {}
    for lo, hi in bands:
        best = (0.0, None)
        f = lo
        while f <= hi:
            re = im = 0.0
            for k in range(n):
                ang = 2 * math.pi * f * k / fs
                re += w[k] * series[k] * math.cos(ang)
                im -= w[k] * series[k] * math.sin(ang)
            amp = 2 * math.hypot(re, im) / sw
            if amp > best[0]:
                best = (amp, f)
            f += 1.0
        out[f"{lo:g}-{hi:g}"] = {"amp": round(best[0], 2), "hz": best[1]}
    return out


def polyfit_resid(t: list[float], y: list[float], deg: int) -> tuple[list[float], list[float]]:
    """최소제곱 다항식 맞춤(deg 1~2). (맞춘 값, 잔차)를 돌려준다."""
    n = deg + 1
    A = [[sum(tk ** (i + j) for tk in t) for j in range(n)] for i in range(n)]
    v = [sum(yk * tk ** i for tk, yk in zip(t, y)) for i in range(n)]
    for c in range(n):  # 가우스 소거
        p = max(range(c, n), key=lambda r: abs(A[r][c]))
        A[c], A[p], v[c], v[p] = A[p], A[c], v[p], v[c]
        for r in range(n):
            if r != c and A[c][c]:
                k = A[r][c] / A[c][c]
                A[r] = [A[r][j] - k * A[c][j] for j in range(n)]
                v[r] -= k * v[c]
    coef = [v[i] / A[i][i] if A[i][i] else 0.0 for i in range(n)]
    fit = [sum(coef[i] * tk ** i for i in range(n)) for tk in t]
    return fit, [yk - fk for yk, fk in zip(y, fit)]


def cycle_analysis(samples: array.array, rate: int, t0: float, t1: float, f: dict, bands: list) -> dict:
    """주기 단위 F0·진폭 궤적으로 기울기, 변조 깊이(대역별), jitter·shimmer를 잰다."""
    tr = f0_track(samples, rate, f)
    vals = [fr for t, fr, c in tr if t0 <= t <= t1 and fr and c >= f["periodic_nacf"]]
    per_frac = shake_stats(tr, t0, t1, f)
    res = {"dur": round(t1 - t0, 3), "periodic": per_frac["periodic"] if per_frac else None}
    if len(vals) < 3:
        return {**res, "ok": False}
    marks = pitch_marks(samples, rate, t0, t1, st.median(vals))
    if len(marks) < 6:
        return {**res, "ok": False}
    P = [marks[i + 1] - marks[i] for i in range(len(marks) - 1)]
    A = [math.sqrt(sum(samples[k] ** 2 for k in range(marks[i], marks[i + 1])) / P[i]) or 1.0
         for i in range(len(P))]
    tc = [(marks[i] + marks[i + 1]) / 2 / rate for i in range(len(P))]
    f0s = [rate / p for p in P]
    med = st.median(f0s)
    cents = [1200 * math.log2(x / med) for x in f0s]
    dbs = [20 * math.log10(a) for a in A]
    jitter = st.mean(abs(P[i + 1] - P[i]) for i in range(len(P) - 1)) / st.mean(P) * 100
    shimmer = st.mean(abs(dbs[i + 1] - dbs[i]) for i in range(len(dbs) - 1))
    # 1kHz 등간격으로 다시 뽑기
    fs = 1000.0
    grid = [tc[0] + k / fs for k in range(int((tc[-1] - tc[0]) * fs))]
    def interp(ys):
        out, j = [], 0
        for g in grid:
            while j < len(tc) - 2 and tc[j + 1] < g:
                j += 1
            u = (g - tc[j]) / (tc[j + 1] - tc[j])
            out.append(ys[j] + u * (ys[j + 1] - ys[j]))
        return out
    gc, gd = interp(cents), interp(dbs)
    lin, _ = polyfit_resid(grid, gc, 1)
    _, rc = polyfit_resid(grid, gc, 2)
    _, rd = polyfit_resid(grid, gd, 2)
    return {
        **res, "ok": True, "cycles": len(P), "f0": round(med),
        "jitter_pct": round(jitter, 2), "shimmer_db": round(shimmer, 2),
        "slope_c": round(lin[-1] - lin[0]),
        "f0_resid_c": round(math.sqrt(st.mean(x * x for x in rc)), 1),
        "amp_resid_db": round(math.sqrt(st.mean(x * x for x in rd)), 2),
        "f0_mod": mod_peaks(rc, fs, bands),
        "amp_mod": mod_peaks(rd, fs, bands),
    }


def psola_stretch(samples: array.array, rate: int, marks: list[int], i0: int, i1: int,
                  alpha: float) -> tuple[array.array, int]:
    """marks[i0]~marks[i1] 구간을 alpha배로 늘린다(피치 동기 겹침-더하기, 음높이 유지).
    늘어난 샘플 수도 돌려준다."""
    m0, m1 = marks[i0], marks[i1]
    out = [float(s) for s in samples[:m0]]
    P0 = marks[i0 + 1] - m0
    for k in range(P0):  # 앞부분 끝은 내려가는 반창
        j = m0 - P0 + k
        if j >= 0:
            out[j] *= 0.5 + 0.5 * math.cos(math.pi * k / P0)
    out.extend([0.0] * int((m1 - m0) * alpha + 4 * P0))
    s = float(m0)
    region = marks[i0:i1 + 1]
    while True:
        ta = m0 + (s - m0) / alpha
        if ta >= m1:
            break
        k = min(range(len(region) - 1), key=lambda q: abs(region[q] - ta))
        c = region[k]
        P = region[k + 1] - region[k]
        for j in range(-P, P):
            src = c + j
            dst = int(s) + j
            if 0 <= src < len(samples) and 0 <= dst < len(out):
                out[dst] += samples[src] * (0.5 + 0.5 * math.cos(math.pi * j / P))
        s += P
    # 뒷부분: m1부터 원래대로, 첫 주기는 올라가는 반창
    P1 = marks[i1] - marks[i1 - 1]
    base = int(s) - P1
    tail = samples[m1 - P1:]
    need = base + len(tail) - len(out)
    if need > 0:
        out.extend([0.0] * need)
    for k, v in enumerate(tail):
        g = 0.5 - 0.5 * math.cos(math.pi * k / P1) if k < P1 else 1.0
        out[base + k] += v * g
    end = base + len(tail)
    out = out[:end]
    return array.array("h", (max(-32768, min(32767, int(round(v)))) for v in out)), int(s) - m1


@dataclasses.dataclass
class Letter3:
    samples: array.array
    rate: int
    span: tuple[float, float]
    kana_in: str
    query_kana: str | None
    phonemes: list[str]


def make_letter3(synth: Synthesizer, sid: int, letter: dict, method: dict, common: dict,
                 adj: dict | None = None) -> Letter3:
    """3차 방법. kind: c40 / carrier(e-ta, N) / long(L) / text(T)."""
    adj = adj or {}
    kind = method["kind"]
    if kind == "text":
        q = synth.create_audio_query(letter["text"] + method["suffix"], sid)
        kana_in = letter["text"] + method["suffix"]
    else:
        kana_in = {"single": letter["aquestalk"], "carrier": letter["aquestalk"] + method.get("carrier", ""),
                   "long": letter["long"] + method.get("carrier", "")}[kind]
        q = synth.create_audio_query_from_kana(kana_in, sid)
    if "mora_seconds" in method:
        q = stretch_moras(q, method["mora_seconds"], common["min_vowel_seconds"],
                          only_index=0 if kind == "carrier" else None)
    if method.get("flat_pitch"):
        q = flatten_pitch(q, timeline(q)[0]["pitch"])
    q = dataclasses.replace(
        q, pre_phoneme_length=common["pre"], post_phoneme_length=common["post"],
        speed_scale=method.get("speed_scale", 1.0) * adj.get("speed_scale", 1.0),
        pitch_scale=adj.get("pitch_scale", q.pitch_scale),
        intonation_scale=adj.get("intonation_scale", q.intonation_scale),
    )
    samples, rate = pcm_of(synth.synthesis(q, sid))
    tl = timeline(q)
    fo = method.get("fade_out", 0.0)
    if kind in ("carrier", "long"):
        m = tl[0]
        if kind == "carrier":
            end = m["end"]
        else:  # 장음: 첫 박 시작부터 cut_s 지점, 두 번째 박 끝을 넘지 않게
            end = min(m["start"] + method["cut_s"], tl[1]["end"])
        a = max(0, int((m["start"] - 0.02) * rate))
        b = min(len(samples), int(end * rate))
        body = fade(samples[a:b], rate, fade_in=common["fade_in"], fade_out=fo)
        out = silence(rate, common["pre"])
        out.extend(body)
        out.extend(silence(rate, common["post"]))
        off = common["pre"] - (m["start"] - 0.02)
        span = (m["vowel_start"] + off, end + off - fo)
    else:  # single(c40), text: 그대로. 유성 박들의 모음 구간
        voiced = [m for m in tl if m["pitch"] > 0] or tl
        span = (voiced[0]["vowel_start"], voiced[-1]["end"])
        out = samples
    return Letter3(out, rate, span, kana_in, q.kana, phonemes(q))


def analyze3(lt: Letter3, cfg: dict) -> dict:
    r3 = cfg["round3"]
    f = cfg["round2"]["f0"]
    e = r3["edge_s"]
    return {**measure(lt.samples, lt.rate, cfg["measure"]["frame_ms"], cfg["measure"]["silence_dbfs"]),
            "span": [round(lt.span[0], 3), round(lt.span[1], 3)],
            **cycle_analysis(lt.samples, lt.rate, lt.span[0] + e, lt.span[1] - e, f, r3["bands"])}


def apply_psola(lt: Letter3, cfg: dict, target_voiced: float) -> Letter3 | None:
    """짧은 합성(N)의 모음 정상 구간을 늘려 소리 구간을 target_voiced초로 만든다."""
    f = cfg["round2"]["f0"]
    v0, v1 = lt.span
    tr = f0_track(lt.samples, lt.rate, f)
    vals = [fr for t, fr, c in tr if v0 <= t <= v1 and fr and c >= f["periodic_nacf"]]
    if len(vals) < 3:
        return None
    marks = pitch_marks(lt.samples, lt.rate, v0 + 0.02, v1 - 0.02, st.median(vals))
    if len(marks) < 8:
        return None
    i0, i1 = 2, len(marks) - 3
    s, e = voiced_bounds(lt.samples, lt.rate, 10, -45.0)
    cur = (e - s) / lt.rate
    steady = (marks[i1] - marks[i0]) / lt.rate
    alpha = max(1.0, 1 + (target_voiced - cur) / steady)
    out, added = psola_stretch(lt.samples, lt.rate, marks, i0, i1, alpha)
    return Letter3(out, lt.rate, (v0, v1 + added / lt.rate), lt.kana_in + " +PSOLA", lt.query_kana, lt.phonemes)


def apply_loop(lt: Letter3, cfg: dict, method: dict) -> Letter3 | None:
    """모음 앞부분에서 가장 고른 한 주기를 골라, 그 주기를 같은 간격으로 겹쳐 이어 붙인다(샘플러의 서스테인 루프).
    자음과 모음 시작은 원래 소리 그대로 두고, 고른 주기부터 끝까지는 그 한 주기만 반복한다."""
    f = cfg["round2"]["f0"]
    rate = lt.rate
    v0, v1 = lt.span
    tr = f0_track(lt.samples, rate, f)
    vals = [fr for t, fr, c in tr if v0 <= t <= v1 and fr and c >= f["periodic_nacf"]]
    if len(vals) < 3:
        return None
    lo, hi = method["search"]
    s0, _ = voiced_bounds(lt.samples, rate, 10, -45.0)
    base = max(v0, s0 / rate)  # 모음 시작이 무음인 글자가 있어, 실제 소리가 시작된 곳부터 찾는다
    marks = pitch_marks(lt.samples, rate, base + lo, min(v1, base + hi), st.median(vals))
    if len(marks) < 5:
        return None
    # 이웃 세 주기의 길이 차가 가장 작은 곳의 가운데 주기
    best = min(range(1, len(marks) - 2),
               key=lambda i: abs(marks[i] - marks[i - 1] - (marks[i + 1] - marks[i]))
               + abs(marks[i + 2] - marks[i + 1] - (marks[i + 1] - marks[i])))
    m = marks[best]
    P = marks[best + 1] - m
    end = s0 + int(method["target_voiced"] * rate)
    if m - P < 0 or end <= m + 2 * P + int(method["fade_out"] * rate):
        return None  # 고른 주기가 너무 늦어 늘릴 자리가 없다
    out = [float(x) for x in lt.samples[:m]]
    for k in range(P):  # 원래 소리 끝은 내려가는 반창
        out[m - P + k] *= 0.5 + 0.5 * math.cos(math.pi * k / P)
    grain = [lt.samples[m + j] * (0.5 + 0.5 * math.cos(math.pi * j / P)) for j in range(-P, P)]
    out.extend([0.0] * (end - m + 2 * P))
    s = m
    while s < end:
        for j in range(2 * P):
            out[s - P + j] += grain[j]
        s += P
    out = out[:end]
    nf = int(method["fade_out"] * rate)
    for k in range(nf):
        out[end - nf + k] *= 1 - k / nf
    out.extend([0.0] * int(cfg["round2"]["shake"]["common"]["post"] * rate))
    samples = array.array("h", (max(-32768, min(32767, int(round(v)))) for v in out))
    return Letter3(samples, rate, (v0, end / rate - method["fade_out"]),
                   lt.kana_in + " +loop", lt.query_kana, lt.phonemes)


def ref_word_moras(synth: Synthesizer, cfg: dict, sid: int, out_dir: Path) -> list[dict]:
    """단어 속 같은 박(기준). 단어를 기본 속도로 합성하고 지정한 박의 모음 구간을 잰다."""
    r3 = cfg["round3"]
    rows = []
    for ref in r3["ref_words"]:
        q = synth.create_audio_query(ref["text"], sid)
        samples, rate = pcm_of(synth.synthesis(q, sid))
        write_wav(out_dir / f"ref-{ref['romaji']}.wav", samples, rate)
        tl = timeline(q)
        m = tl[ref["mora"]]
        lt = Letter3(samples, rate, (m["vowel_start"], m["end"]), ref["text"], q.kana, phonemes(q))
        rows.append({"file": f"ref-{ref['romaji']}.wav", "letter": ref["letter"], "word": ref["text"],
                     "mora": m["text"], "query_kana": q.kana, **analyze3(lt, cfg)})
    return rows


def cmd_round3(cfg: dict, synth: Synthesizer) -> None:
    r3 = cfg["round3"]
    n_cfg = cfg["round2"]["normalize"]
    m_cfg = cfg["measure"]
    common = cfg["round2"]["shake"]["common"]
    out_dir = ROOT / r3["output_dir"]
    (out_dir / "ref").mkdir(parents=True, exist_ok=True)
    letters = {l["romaji"]: l for l in r3["letters"]}
    rows = []

    def short(a: dict) -> str:
        if not a.get("ok"):
            return f"주기 {a.get('periodic')} (주기 표시 실패)"
        fm, am = a["f0_mod"], a["amp_mod"]
        return (f"주기 {a['periodic']} jit {a['jitter_pct']}% shim {a['shimmer_db']}dB 기울기 {a['slope_c']}c "
                f"F0변조 4-12:{fm['4-12']['amp']}c 12-40:{fm['12-40']['amp']}c 40-120:{fm['40-120']['amp']}c | "
                f"진폭변조 4-12:{am['4-12']['amp']}dB 12-40:{am['12-40']['amp']}dB 40-120:{am['40-120']['amp']}dB")

    def keep(voice: dict, rom: str, key: str, lt: Letter3) -> None:
        norm, gain = normalize(lt.samples, lt.rate, m_cfg, n_cfg)
        lt = dataclasses.replace(lt, samples=norm)
        name = f"{voice['slug']}-{rom}-{key}.wav"
        write_wav(out_dir / name, norm, lt.rate)
        a = analyze3(lt, cfg)
        rows.append({"file": name, "voice": voice["slug"], "letter": rom, "method": key, "input": lt.kana_in,
                     "query_kana": lt.query_kana, "phonemes": lt.phonemes, "gain_db": gain, **a})
        print(f"{name:<34} 소리 {a['voiced']:.2f}s  {short(a)}")

    # 기준: 단어 속 같은 박 (四国めたん ノーマル)
    refs = ref_word_moras(synth, cfg, r3["voice"]["style_id"], out_dir / "ref")
    for r in refs:
        print(f"ref {r['word']}({r['mora']}) 길이 {r['dur']}s  {short(r)}")

    # 四国めたん ノーマル: 8자 × 방법
    voice = r3["voice"]
    for rom in r3["letter_order"]:
        letter = letters[rom]
        for key, method in r3["methods"].items():
            if method["kind"] in ("psola", "loop"):
                src = make_letter3(synth, voice["style_id"], letter, r3["methods"][method["source"]], common)
                lt = (apply_psola(src, cfg, method["target_voiced"]) if method["kind"] == "psola"
                      else apply_loop(src, cfg, method))
                if lt is None:
                    print(f"{rom}-{key}: 주기 표시 실패로 건너뜀")
                    rows.append({"voice": voice["slug"], "letter": rom, "method": key, "error": "pitch marks"})
                    continue
            else:
                lt = make_letter3(synth, voice["style_id"], letter, method, common)
            keep(voice, rom, key, lt)

    # (S) 화자·pitch_scale 영향
    for sv in r3["speakers"]:
        adj = {k: sv[k] for k in ("pitch_scale", "intonation_scale", "speed_scale") if k in sv}
        for rom in r3["letter_order"]:
            for key in r3["speaker_methods"]:
                method = r3["methods"][key]
                if method["kind"] in ("psola", "loop"):
                    src = make_letter3(synth, sv["style_id"], letters[rom], r3["methods"][method["source"]], common, adj)
                    lt = (apply_psola(src, cfg, method["target_voiced"]) if method["kind"] == "psola"
                          else apply_loop(src, cfg, method))
                    if lt is None:
                        continue
                else:
                    lt = make_letter3(synth, sv["style_id"], letters[rom], method, common, adj)
                keep(sv, rom, key, lt)

    with (out_dir / "measurements.json").open("w", encoding="utf-8") as fp:
        json.dump({"bands_hz": r3["bands"], "methods": r3["methods"], "speakers": r3["speakers"],
                   "ref_word_moras": refs, "files": rows}, fp, ensure_ascii=False, indent=1)

    # 미리듣기
    def join(names: list[str], gap_s: float) -> tuple[array.array, int]:
        joined, rate = array.array("h"), 24000
        for nm in names:
            p = out_dir / nm
            if not p.exists():
                continue
            s, rate = read_wav(p)
            joined.extend(s)
            joined.extend(silence(rate, gap_s))
        return joined, rate
    pv = r3["preview"]
    names = [f"{voice['slug']}-{rom}-{key}.wav" for rom in pv["shake_letters"] for key in pv["shake_methods"]]
    s, rate = join(names, pv["gap_seconds"])
    write_wav(out_dir / "preview-shake3.wav", s, rate)
    print("preview-shake3.wav", f"{len(s) / rate:.1f}s", names)
    for slug in pv["best_voices"]:
        names = [f"{slug}-{rom}-{r3['best_method']}.wav" for rom in r3["letter_order"]]
        s, rate = join(names, pv["gap_seconds"])
        write_wav(out_dir / f"preview-best3-{slug}.wav", s, rate)
        print(f"preview-best3-{slug}.wav", f"{len(s) / rate:.1f}s")


# ---------------------------------------------------------------- 최종: 앱에 넣는 소리

def hira_to_kata(text: str) -> str:
    return "".join(chr(ord(c) + 0x60) if "ぁ" <= c <= "ゖ" else c for c in text)


def trim_pad(samples: array.array, rate: int, lead: float, tail: float, floor_dbfs: float) -> array.array:
    """floor_dbfs보다 작은 앞뒤 10ms 창을 잘라 내고 앞 lead초, 뒤 tail초 무음을 붙인다.
    자음(s, h)이 작게 시작해도 잘리지 않도록 소리 구간 판정(-45)보다 낮은 값을 쓴다."""
    s, e = voiced_bounds(samples, rate, 10, floor_dbfs)
    out = silence(rate, lead)
    out.extend(fade(samples[s:e], rate, fade_in=0.003, fade_out=0.005))
    out.extend(silence(rate, tail))
    return out


def word_reading(word: dict, kanji: dict[str, str]) -> str:
    """단어의 가나 읽기. 한자 칸은 설정의 읽기로 바꾼다(없으면 멈춘다)."""
    parts = []
    for u in word["units"]:
        if u.get("kanji"):
            if u["kana"] not in kanji:
                raise SystemExit(f"한자 읽기가 설정에 없다: {u['kana']} ({word['text']})")
            parts.append(kanji[u["kana"]])
        else:
            parts.append(u["kana"])
    return "".join(parts)


def ascii_name(text: str) -> str:
    table = str.maketrans({"ā": "a", "ī": "i", "ū": "u", "ē": "e", "ō": "o", " ": "_", "-": "_", "'": ""})
    name = text.lower().translate(table)
    if not name or any(not (c.isascii() and (c.isalnum() or c == "_")) for c in name):
        raise SystemExit(f"ASCII 이름으로 바꿀 수 없다: {text!r} → {name!r}")
    return name


def unit_matches(units: list[str], moras: list[str]) -> list[str]:
    """엔진이 읽은 박(가타카나)이 단어 글자와 맞는지 본다. 맞지 않는 곳을 돌려준다.
    장음은 같은 단의 모음(ヨウ→ヨオ), を는 オ로 읽는 것을 맞음으로 본다."""
    expect = hira_to_kata("".join(units)).replace("ヲ", "オ")
    got = "".join(moras)
    if len(expect) != len(got):
        return [f"길이 {expect} / {got}"]
    bad = []
    for i, (a, b) in enumerate(zip(expect, got)):
        if a == b:
            continue
        if a == "ウ" and b == "オ" and i > 0 and expect[i - 1] in "オコソトノホモヨロゴゾドボポョ":
            continue  # おう·よう 장음
        if a == "イ" and b == "エ" and i > 0 and expect[i - 1] in "エケセテネヘメレゲゼデベペ":
            continue  # えい 장음
        bad.append(f"{i}:{a}→{b}")
    return bad


def letter_carrier(synth: Synthesizer, sid: int, kana_in: str, carrier: str, method: dict,
                   common: dict) -> tuple[array.array, int, tuple[float, float], AudioQuery]:
    """3차 (N) 방식: 'X' + carrier를 길이 그대로 합성하고 글자 박만 잘라 짧은 페이드를 건다."""
    q = synth.create_audio_query_from_kana(kana_in + carrier, sid)
    if method.get("flat_pitch"):
        q = flatten_pitch(q, timeline(q)[0]["pitch"])
    q = dataclasses.replace(q, pre_phoneme_length=common["pre"], post_phoneme_length=common["post"],
                            speed_scale=method["speed_scale"])
    samples, rate = pcm_of(synth.synthesis(q, sid))
    m = timeline(q)[0]
    fo = method["fade_out"]
    a = max(0, int((m["start"] - 0.02) * rate))
    b = min(len(samples), int(m["end"] * rate))
    body = fade(samples[a:b], rate, fade_in=common["fade_in"], fade_out=fo)
    off = -(m["start"] - 0.02)
    return body, rate, (m["vowel_start"] + off, m["end"] + off - fo), q


def cmd_final(cfg: dict, synth: Synthesizer, kana_only: bool = False) -> None:
    """앱 번들용 소리. kana_only면 글자만 다시 만들고, 단어 m4a·wav와 P-loop 비교본은 건드리지 않는다
    (단어 목록과 수치는 이전 voice_index.json, measurements.json에서 그대로 옮긴다)."""
    import subprocess

    fc = cfg["final"]
    m_cfg = cfg["measure"]
    n_cfg = fc["normalize"]
    sid = fc["voice"]["style_id"]
    out_dir = ROOT / fc["output_dir"]
    app_dir = ROOT / fc["app_dir"]
    for d in (out_dir / "kana", out_dir / "word", out_dir / "ploop", app_dir):
        d.mkdir(parents=True, exist_ok=True)
    prev_index = load_config(app_dir / "voice_index.json") if kana_only else None
    prev_summary = load_config(out_dir / "measurements.json") if kana_only else None
    for old in app_dir.glob("kana_*.m4a" if kana_only else "*.m4a"):
        old.unlink()
    for old in (out_dir / "kana").glob("*.wav"):
        old.unlink()

    scenes = load_config(ROOT / fc["scenes"])
    strokes = load_config(ROOT / fc["strokes"])
    base = [(k["char"], k["romaji"]) for k in strokes["kana"]]
    base_set = {c for c, _ in base}

    # 탭으로 읽히는 글자: 기본 46자 + 단어 칸 중 한자가 아닌 글자(WordBlock이 칸마다 .speaks(kana:)를 붙인다)
    words, unit_romaji = [], {}
    for scene in scenes["scenes"]:
        for step in scene["steps"]:
            for w in step["words"]:
                words.append(w)
                for u in w["units"]:
                    if not u.get("kanji"):
                        unit_romaji.setdefault(u["kana"], u["romaji"])
    extra = sorted((c, r) for c, r in unit_romaji.items() if c not in base_set)
    silent = [c for c, _ in extra if c in fc["silent_kana"]]
    letters = [(c, r, True) for c, r in base] + [(c, r, False) for c, r in extra if c not in silent]

    def pass_through(samples: array.array, rate: int) -> tuple[array.array, float]:
        samples = trim_pad(samples, rate, fc["lead_silence"], fc["tail_silence"], fc["trim_floor_dbfs"])
        return normalize(samples, rate, m_cfg, n_cfg)

    def encode(wav: Path, name: str) -> dict:
        dst = app_dir / f"{name}.m4a"
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", str(fc["aac_bitrate"]), "-c", "1",
                        str(wav), str(dst)], check=True)
        # 다시 풀어 길이·음량을 확인한다(인코딩으로 소리가 사라지거나 잘리지 않았는지)
        back = out_dir / "_decoded.wav"
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", str(dst), str(back)], check=True)
        s, r = read_wav(back)
        back.unlink()
        mm = measure(s, r, m_cfg["frame_ms"], m_cfg["silence_dbfs"])
        return {"m4a_bytes": dst.stat().st_size, "m4a_duration": mm["duration"],
                "m4a_voiced": mm["voiced"], "m4a_rms_dbfs": mm["rms_dbfs"], "m4a_peak_dbfs": mm["peak_dbfs"]}

    names: dict[str, str] = {}

    def claim(name: str, owner: str) -> str:
        if name in names:
            raise SystemExit(f"파일 이름이 겹친다: {name} ({names[name]}, {owner})")
        names[name] = owner
        return name

    # 글자: 5차 노래 합성 flatM40(2026-11-16 사용자 선택). 한 박을 0.40초 음표로, f0 평탄, 음량 mono.
    song = fc["kana_song"]
    s0 = VoiceModelFile.open(ROOT / cfg["core_dir"] / song["vvm"])
    synth.load_voice_model(s0)
    teacher, singer = song["teacher_style_id"], song["singer_style_id"]
    lim = song["limits"]
    kana_rows, kana_index, missing_kana = [], {}, []
    for char, romaji, is_base in letters:
        try:
            raw, rate, info = song_letter(synth, song, char, song["target_hz"], teacher, singer)
        except Exception as e:
            missing_kana.append(char)
            kana_rows.append({"kana": char, "romaji": romaji, "base46": is_base, "file": None,
                              "error": f"{type(e).__name__}: {e}"})
            print(f"{char} 실패: {type(e).__name__}: {e}")
            continue
        name = claim(f"kana_{ascii_name(romaji)}", char)
        norm, gain = pass_through(raw, rate)
        wav = out_dir / "kana" / f"{name}.wav"
        write_wav(wav, norm, rate)
        a = measure4(norm, rate, cfg)
        clipped = sum(1 for x in norm if abs(x) >= 32767)
        flags = []
        if a["voiced"] < lim["min_voiced"]:
            flags.append(f"짧음 {a['voiced']}s")
        if a["rms_dbfs"] <= lim["silent_rms_dbfs"]:
            flags.append(f"무음 {a['rms_dbfs']}dBFS")
        if clipped or a["peak_dbfs"] > lim["max_peak_dbfs"]:
            flags.append(f"클리핑 {clipped}샘플 peak {a['peak_dbfs']}")
        if not a.get("ok"):
            flags.append("주기 측정 실패")
        row = {"kana": char, "romaji": romaji, "base46": is_base, "file": name, "gain_db": gain,
               "clipped_samples": clipped, "flags": flags, **info, **a, **encode(wav, name)}
        kana_rows.append(row)
        kana_index[char] = name
        print(f"{char} {name:<10} 가사 {info['lyric']} {' '.join(p for p, _ in info['phonemes'] if p != 'pau'):<5} "
              f"소리 {a['voiced']:.2f}s 길이 {a['duration']:.2f}s rms {a['rms_dbfs']} peak {a['peak_dbfs']} "
              f"F0 {a.get('f0')} sd {a.get('f0_sd_c')}c jit {a.get('jitter_pct')} 4-12 {a.get('f0_mod_4_12_c')}c "
              f"m4a {row['m4a_bytes']}B {' '.join(flags)}")

    if kana_only:
        loop_rows = prev_summary["ploop"]
        word_rows = prev_summary["words"]
        word_index = prev_index["word"]
        missing_words = prev_index["missingWords"]
        for name in word_index.values():
            if not (app_dir / f"{name}.m4a").exists():
                raise SystemExit(f"단어 파일이 없다: {name}.m4a (kana_only는 단어를 만들지 않는다)")
    else:
        # P-loop 비교본(앱에는 넣지 않음): 46자, 3차 방법 그대로
        r3 = cfg["round3"]
        loop_m = r3["methods"]["P-loop"]
        src_m = r3["methods"][loop_m["source"]]
        loop_common = cfg["round2"]["shake"]["common"]
        loop_rows = []
        for char, romaji in base:
            aq = fc["kana_input"].get(char, hira_to_kata(char) + "'")
            letter = {"aquestalk": aq, "long": aq, "text": char}  # make_letter3는 세 키를 모두 읽는다
            try:
                src = make_letter3(synth, sid, letter, src_m, loop_common)
                lt = apply_loop(src, cfg, loop_m)
            except Exception as e:
                lt, err = None, f"{type(e).__name__}: {e}"
            else:
                err = "pitch marks"
            if lt is None:
                loop_rows.append({"kana": char, "romaji": romaji, "file": None, "error": err})
                print(f"P-loop {char}: 실패 ({err})")
                continue
            norm, gain = pass_through(lt.samples, lt.rate)
            name = f"kana_{ascii_name(romaji)}"
            write_wav(out_dir / "ploop" / f"{name}.wav", norm, lt.rate)
            loop_rows.append({"kana": char, "romaji": romaji, "file": f"ploop/{name}.wav", "gain_db": gain,
                              **measure(norm, lt.rate, m_cfg["frame_ms"], m_cfg["silence_dbfs"])})

        # 단어
        word_rows, word_index, missing_words = [], {}, []
        fixes = fc["word_kana"]
        for w in words:
            reading = word_reading(w, fc["kanji_readings"])
            name = claim(f"word_{ascii_name(w['reading'])}", w["text"])
            text_q = synth.create_audio_query(reading, sid)
            engine = {"query_kana": text_q.kana, "phrases": len(text_q.accent_phrases)}
            if w["text"] in fixes:
                q = synth.create_audio_query_from_kana(fixes[w["text"]]["kana"], sid)
                source = "kana"
            else:
                q = text_q
                source = "text"
            q = dataclasses.replace(q, speed_scale=fc["word_speed"])
            moras = [m.text for ap in q.accent_phrases for m in ap.moras]
            mismatch = unit_matches([reading], moras)
            samples, rate = pcm_of(synth.synthesis(q, sid))
            norm, gain = pass_through(samples, rate)
            wav = out_dir / "word" / f"{name}.wav"
            write_wav(wav, norm, rate)
            row = {"text": w["text"], "reading": reading, "file": name, "source": source, "engine_text": engine,
                   "query_kana": q.kana, "phrases": len(q.accent_phrases), "phonemes": phonemes(q),
                   "mismatch": mismatch, "gain_db": gain,
                   **measure(norm, rate, m_cfg["frame_ms"], m_cfg["silence_dbfs"]), **encode(wav, name)}
            if w["text"] in fixes:
                row["fix_note"] = fixes[w["text"]].get("note")
            word_rows.append(row)
            word_index[w["text"]] = name
            flag = " 읽기 확인 필요 " + ",".join(mismatch) if mismatch else ""
            print(f"{w['text']:<10} {name:<28} {q.kana:<24} 구 {row['phrases']} 소리 {row['voiced']:.2f}s "
                  f"rms {row['rms_dbfs']} peak {row['peak_dbfs']}{flag}")

    # 미리듣기: あ행부터 10자, 앱처럼 글자마다 한 번, 글자 사이 letter_gap
    pv = fc["preview"]
    joined, rate = array.array("h"), 24000
    for romaji in pv["letters"]:
        p = out_dir / "kana" / f"kana_{romaji}.wav"
        if not p.exists():
            continue
        smp, rate = read_wav(p)
        joined.extend(smp)
        joined.extend(silence(rate, pv["letter_gap"]))
    write_wav(out_dir / "preview-kana.wav", joined, rate)
    print(f"preview-kana.wav {len(joined) / rate:.1f}s")

    index = {
        "comment": "tools/gen_voice.py final이 만든다. 값은 번들 안 m4a 파일 이름(확장자 제외).",
        # credit은 쓰지 않는다: 2026-11-21 사용자 결정으로 앱의 VOICEVOX 표기를 지웠다(이슈 #6).
        # 이 도구로 VOICEVOX 소리를 다시 번들에 넣으려면 정보 화면 표기부터 사용자에게 확인한다.
        "generated": fc["generated"],
        "kana": kana_index, "word": word_index,
        "silentKana": silent, "missingKana": missing_kana, "missingWords": missing_words,
    }
    with (app_dir / "voice_index.json").open("w", encoding="utf-8") as fp:
        json.dump(index, fp, ensure_ascii=False, indent=1, sort_keys=True)

    total = sum(p.stat().st_size for p in app_dir.glob("*.m4a"))
    summary = {
        "voice": fc["voice"], "generated": fc["generated"], "voicevox_core": "0.17.1",
        "kana_song": song, "word_speed": fc["word_speed"], "kana_only_run": kana_only,
        "normalize": n_cfg, "lead_silence": fc["lead_silence"], "tail_silence": fc["tail_silence"],
        "aac_bitrate": fc["aac_bitrate"], "m4a_files": len(list(app_dir.glob("*.m4a"))), "m4a_bytes": total,
        "silent_kana": silent, "missing_kana": missing_kana,
        "kana_flags": {r["kana"]: r["flags"] for r in kana_rows if r.get("flags")},
        "kana": kana_rows, "ploop": loop_rows, "words": word_rows,
    }
    with (out_dir / "measurements.json").open("w", encoding="utf-8") as fp:
        json.dump(summary, fp, ensure_ascii=False, indent=1)
    print(f"m4a {summary['m4a_files']}개 {total} B, 빠진 글자 {missing_kana}, 소리 없는 글자 {silent}")


# ---------------------------------------------------------------- 4차: 짧지도 떨리지도 않은 글자

VOWEL_KANA = {"a": "ア", "i": "イ", "u": "ウ", "e": "エ", "o": "オ", "N": "ン"}


def voiced_mora(m, fallback_pitch: float):
    """무성화된 박(모음 대문자, 높이 0)을 유성으로 되돌린다."""
    if m.vowel in ("A", "I", "U", "E", "O"):
        m = dataclasses.replace(m, vowel=m.vowel.lower())
    if m.pitch <= 0:
        m = dataclasses.replace(m, pitch=fallback_pitch)
    return m


def replace_last_mora(query: AudioQuery, fn) -> AudioQuery:
    aps = list(query.accent_phrases)
    last = aps[-1]
    aps[-1] = dataclasses.replace(last, moras=list(last.moras[:-1]) + [fn(last.moras[-1])])
    return dataclasses.replace(query, accent_phrases=aps)


def psola_repeat(samples: array.array, rate: int, marks: list[int], i0: int, i1: int,
                 alpha: float) -> array.array:
    """marks[i0]~marks[i1]의 주기들을 순서대로 alpha배 써서 늘린다(alpha 2면 각 주기를 두 번씩).
    한 주기만 반복하지 않으므로 원래 주기들의 미세한 변화가 남는다."""
    m0, m1 = marks[i0], marks[i1]
    out = [float(s) for s in samples[:m0]]
    P0 = marks[i0 + 1] - m0
    for k in range(P0):
        j = m0 - P0 + k
        if j >= 0:
            out[j] *= 0.5 + 0.5 * math.cos(math.pi * k / P0)
    n_out = int(round((i1 - i0) * alpha))
    out.extend([0.0] * int((m1 - m0) * alpha + 6 * P0))
    s = m0
    for n in range(n_out):
        k = i0 + min(i1 - i0 - 1, int(n / alpha))
        c, P = marks[k], marks[k + 1] - marks[k]
        for j in range(-P, P):
            src, dst = c + j, s + j
            if 0 <= src < len(samples) and 0 <= dst < len(out):
                out[dst] += samples[src] * (0.5 + 0.5 * math.cos(math.pi * j / P))
        s += P
    P1 = marks[i1] - marks[i1 - 1]
    base = s - P1
    tail = samples[m1 - P1:]
    need = base + len(tail) - len(out)
    if need > 0:
        out.extend([0.0] * need)
    for k, v in enumerate(tail):
        out[base + k] += v * (0.5 - 0.5 * math.cos(math.pi * k / P1) if k < P1 else 1.0)
    out = out[:base + len(tail)]
    return array.array("h", (max(-32768, min(32767, int(round(v)))) for v in out))


def cosine_tail(samples: array.array, rate: int, seconds: float) -> array.array:
    """소리 구간 끝 seconds초에 코사인 페이드를 건다."""
    out = array.array("h", samples)
    _, e = voiced_bounds(out, rate, 10, -60.0)
    n = int(seconds * rate)
    for k in range(n):
        i = e - n + k
        if 0 <= i < len(out):
            out[i] = int(out[i] * (0.5 + 0.5 * math.cos(math.pi * k / n)))
    for i in range(e, len(out)):
        out[i] = 0
    return out


def measure4(samples: array.array, rate: int, cfg: dict) -> dict:
    """후보 공통 측정. 구간을 합성 정보 없이 파형에서 정한다: 주기가 또렷한 첫 창~마지막 창(앞뒤 20ms 제외).
    decay_s: 소리 구간 RMS보다 6dB 낮아진 마지막 지점에서 -45dBFS로 사라질 때까지(클수록 끝이 천천히 잦아듦)."""
    f = cfg["round2"]["f0"]
    m_cfg = cfg["measure"]
    m = measure(samples, rate, m_cfg["frame_ms"], m_cfg["silence_dbfs"])
    vs, ve = voiced_bounds(samples, rate, 10, m_cfg["silence_dbfs"])
    n = rate // 100
    seg = samples[vs:ve]
    rms = math.sqrt(sum(x * x for x in seg) / len(seg)) if seg else 1.0
    loud = [i for i in range(vs, ve, n)
            if math.sqrt(sum(x * x for x in samples[i:i + n]) / max(1, len(samples[i:i + n]))) >= rms / 2]
    decay = (ve - (loud[-1] + n)) / rate if loud else 0.0
    tr = f0_track(samples, rate, f)
    per = [t for t, fr, c in tr if fr and c >= f["periodic_nacf"]]
    sh = shake_stats(tr, vs / rate, ve / rate, f) or {}
    res = {**m, "decay_s": round(max(0.0, decay), 3), "periodic": sh.get("periodic"), "f0_sd_c": sh.get("sd_c")}
    if len(per) < 3:
        return {**res, "ok": False}
    t0, t1 = per[0] + f["edge_s"], per[-1] - f["edge_s"]
    ca = cycle_analysis(samples, rate, t0, t1, f, cfg["round3"]["bands"])
    res["pitched_s"] = round(per[-1] - per[0], 3)
    if not ca.get("ok"):
        return {**res, "ok": False}
    return {**res, "ok": True, "cycles": ca["cycles"], "f0": ca["f0"], "jitter_pct": ca["jitter_pct"],
            "shimmer_db": ca["shimmer_db"], "slope_c": ca["slope_c"], "f0_resid_c": ca["f0_resid_c"],
            "f0_mod_4_12_c": ca["f0_mod"]["4-12"]["amp"], "amp_mod_4_12_db": ca["amp_mod"]["4-12"]["amp"],
            "f0_mod_12_40_c": ca["f0_mod"]["12-40"]["amp"]}


def cmd_round4(cfg: dict, synth: Synthesizer) -> None:
    r4 = cfg["round4"]
    fc = cfg["final"]
    m_cfg = cfg["measure"]
    sid = r4["style_id"]
    common = r4["common"]
    out_dir = ROOT / r4["output_dir"]
    out_dir.mkdir(parents=True, exist_ok=True)
    final_rows = {r["kana"]: r for r in load_config(ROOT / fc["n_measurements"])["kana"]}

    def synth_q(q: AudioQuery) -> tuple[array.array, int]:
        q = dataclasses.replace(q, pre_phoneme_length=common["pre"], post_phoneme_length=common["post"])
        return pcm_of(synth.synthesis(q, sid))

    def fallback_pitch(kana: str) -> float:
        return timeline(synth.create_audio_query_from_kana(kana, sid))[-1]["pitch"]

    def make(key: str, char: str) -> tuple[array.array, int, dict]:
        c = r4["candidates"][key]
        kana_in = fc["kana_input"].get(char, hira_to_kata(char) + "'")
        kind = c["kind"]
        if kind == "single":  # A
            q = synth.create_audio_query_from_kana(kana_in, sid)
            q = replace_last_mora(q, lambda m: voiced_mora(m, fallback_pitch("ア'")))
            q = dataclasses.replace(q, speed_scale=c["speed_scale"])
            s, rate = synth_q(q)
            return s, rate, {"input": kana_in, "query_kana": q.kana, "phonemes": phonemes(q)}
        if kind == "repeat":  # B
            q = synth.create_audio_query_from_kana(kana_in, sid)
            m = voiced_mora(q.accent_phrases[0].moras[0], fallback_pitch("ア'"))
            lo, hi = c["mora_vowel_s"]
            m = dataclasses.replace(m, vowel_length=min(hi, max(lo, m.vowel_length)))
            moras = [m]
            for k in range(1, c["moras"]):
                moras.append(dataclasses.replace(
                    m, text=VOWEL_KANA[m.vowel], consonant=None, consonant_length=None,
                    pitch=m.pitch + k * math.log(1 - c["step_down"])))
            ap = dataclasses.replace(q.accent_phrases[0], moras=moras)
            q = dataclasses.replace(q, accent_phrases=[ap], speed_scale=c["speed_scale"])
            s, rate = synth_q(q)
            return s, rate, {"input": kana_in, "query_kana": q.kana, "phonemes": phonemes(q),
                             "moras": mora_detail(q)}
        if kind == "stretch":  # C
            row = final_rows[char]
            body, rate, span, q = letter_carrier(
                synth, sid, fc["kana_input"].get(char, hira_to_kata(char) + "'"), row["carrier"],
                {**fc["kana_method"], "fade_out": 0.0}, fc["common"])
            hint = math.exp(timeline(q)[0]["pitch"])
            marks = pitch_marks(body, rate, span[0] + 0.01, span[1] - 0.005, hint)
            if len(marks) < 6:
                raise RuntimeError(f"주기 표시 {len(marks)}개")
            i0, i1 = 1, len(marks) - 2
            s0, e0 = voiced_bounds(body, rate, 10, -45.0)
            cur = (e0 - s0) / rate
            steady = (marks[i1] - marks[i0]) / rate
            lo, hi = c["alpha"]
            alpha = min(hi, max(lo, 1 + (c["target_voiced"] - cur) / steady))
            out = psola_repeat(body, rate, marks, i0, i1, alpha)
            out = cosine_tail(out, rate, c["fade_s"])
            return out, rate, {"input": kana_in + row["carrier"], "query_kana": q.kana, "phonemes": phonemes(q),
                               "alpha": round(alpha, 2), "steady_s": round(steady, 3)}
        if kind == "sentence_end":  # D
            text = c["prefix"] + kana_in
            q = synth.create_audio_query_from_kana(text, sid)
            q = replace_last_mora(q, lambda m: voiced_mora(m, fallback_pitch(c["prefix"] + "ア'")))
            q = dataclasses.replace(q, speed_scale=c["speed_scale"])
            s, rate = synth_q(q)
            tl = timeline(q)
            a = int((tl[-1]["start"] - c["lead_s"]) * rate)
            body = fade(s[a:], rate, fade_in=0.005)
            return body, rate, {"input": text, "query_kana": q.kana, "phonemes": phonemes(q),
                                "last_mora": {k: round(v, 3) if isinstance(v, float) else v
                                              for k, v in tl[-1].items()}}
        raise SystemExit(f"모르는 kind: {kind}")

    rows = []
    for key in r4["candidates"]:
        (out_dir / key).mkdir(exist_ok=True)
        for char, romaji in r4["letters"]:
            try:
                s, rate, info = make(key, char)
            except Exception as e:
                rows.append({"cand": key, "kana": char, "error": f"{type(e).__name__}: {e}"})
                print(f"{key} {char}: 실패 {e}")
                continue
            s = trim_pad(s, rate, fc["lead_silence"], fc["tail_silence"], fc["trim_floor_dbfs"])
            s, gain = normalize(s, rate, m_cfg, fc["normalize"])
            write_wav(out_dir / key / f"kana_{romaji}.wav", s, rate)
            a = measure4(s, rate, cfg)
            rows.append({"cand": key, "kana": char, "romaji": romaji, "gain_db": gain, **info, **a})
            print(f"{key:<4} {char} 소리 {a['voiced']:.2f}s 감쇠 {a['decay_s']:.2f}s 주기 {a['periodic']} "
                  f"jit {a.get('jitter_pct')} F0 4-12 {a.get('f0_mod_4_12_c')}c 진폭 {a.get('amp_mod_4_12_db')}dB "
                  f"{' '.join(info['phonemes'])}")

    # 기준: 2026-11-15 앱에 들어갔던 N(final/kanaN)
    for char, romaji in r4["letters"]:
        s, rate = read_wav(ROOT / fc["n_kana_dir"] / f"kana_{romaji}.wav")
        a = measure4(s, rate, cfg)
        rows.append({"cand": "N", "kana": char, "romaji": romaji, **a})
        print(f"N    {char} 소리 {a['voiced']:.2f}s 감쇠 {a['decay_s']:.2f}s 주기 {a['periodic']} "
              f"jit {a.get('jitter_pct')} F0 4-12 {a.get('f0_mod_4_12_c')}c 진폭 {a.get('amp_mod_4_12_db')}dB")

    # 후보별 요약과 미리듣기
    summary = {}
    for key in ["N"] + list(r4["candidates"]):
        rs = [r for r in rows if r["cand"] == key and "error" not in r]
        def med(k):
            v = [r[k] for r in rs if r.get(k) is not None]
            return round(st.median(v), 3) if v else None
        summary[key] = {
            "made": len(rs), "voiced_min": min((r["voiced"] for r in rs), default=None),
            "voiced_max": max((r["voiced"] for r in rs), default=None),
            "voiced_med": med("voiced"), "decay_med": med("decay_s"), "periodic_med": med("periodic"),
            "jitter_med": med("jitter_pct"), "jitter_max": max((r["jitter_pct"] for r in rs if r.get("ok")), default=None),
            "f0_mod_4_12_med": med("f0_mod_4_12_c"), "amp_mod_4_12_med": med("amp_mod_4_12_db"),
            "failed_make": [r["kana"] for r in rows if r["cand"] == key and "error" in r],
            "failed_measure": [r["kana"] for r in rs if not r.get("ok")],
        }
        print(key, summary[key])
        joined, rate = array.array("h"), 24000
        for char, romaji in r4["letters"]:
            p = (ROOT / fc["n_kana_dir"] if key == "N" else out_dir / key) / f"kana_{romaji}.wav"
            if not p.exists():
                continue
            s, rate = read_wav(p)
            joined.extend(s)
            joined.extend(silence(rate, r4["letter_gap"]))
        write_wav(out_dir / f"preview-{key}.wav", joined, rate)
        summary[key]["preview_s"] = round(len(joined) / rate, 1)

    with (out_dir / "measurements.json").open("w", encoding="utf-8") as fp:
        json.dump({"candidates": r4["candidates"], "summary": summary, "files": rows}, fp, ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- 5차: 노래 합성(s0.vvm)으로 한 박

FRAME_RATE = 93.75  # 노래 합성의 프레임/초


def hz_to_midi(hz: float) -> float:
    return 69 + 12 * math.log2(hz / 440)


def speech_f0(paths: list[Path], f: dict) -> dict:
    """말소리 wav들의 F0 중앙값. 파일마다 주기 창 F0 중앙값을 내고 그 중앙값을 쓴다."""
    per_file = []
    for p in paths:
        s, rate = read_wav(p)
        vals = [fr for _, fr, c in f0_track(s, rate, f) if fr and c >= f["periodic_nacf"]]
        if len(vals) >= 3:
            per_file.append(st.median(vals))
    return {"files": len(per_file), "median_hz": round(st.median(per_file), 1),
            "p25_hz": round(st.quantiles(per_file, n=4)[0], 1), "p75_hz": round(st.quantiles(per_file, n=4)[2], 1)}


def song_score(lyric: str, note_frames: int, key: int, rest_pre: int, rest_post: int):
    from voicevox_core import Note, Score
    return Score([Note(rest_pre, ""), Note(note_frames, lyric, key=key), Note(rest_post, "")])


def song_note_span(query) -> tuple[int, int, int]:
    """노래 쿼리에서 (음표 첫 프레임=자음 시작, 모음 시작, 모음 끝) 프레임 번호. 쉼(pau) 사이의 음소가 음표다."""
    t, spans = 0, []
    for ph in query.phonemes:
        spans.append((ph.phoneme, t, t + ph.frame_length))
        t += ph.frame_length
    body = [x for x in spans if x[0] != "pau"]
    return body[0][1], body[-1][1], body[-1][2]


def song_letter(synth: Synthesizer, v: dict, char: str, target_hz: float, teacher: int,
                singer: int) -> tuple[array.array, int, dict]:
    """노래 모델로 가나 한 박(5차 방식, 앱 최종본은 flatM40). 쿼리·f0·음량은 가창 교사(teacher) 스타일로 만들고
    소리는 singer(frame_decode) 스타일로 합성한다. v: note_s, f0(model/flat/fall), volume(mono/hold),
    rest_pre, rest_post, lyric(글자→가사 대체), tail_fade_s. 음표 key는 target_hz에 가장 가까운 반음."""
    key = int(round(hz_to_midi(target_hz)))
    lyric = v.get("lyric", {}).get(char, hira_to_kata(char))
    n = int(round(v["note_s"] * FRAME_RATE))
    sc = song_score(lyric, n, key, v["rest_pre"], v["rest_post"])
    q = synth.create_sing_frame_audio_query(sc, teacher)
    c0, v0, v1 = song_note_span(q)
    model_f0 = list(q.f0)
    voiced = [x for x in model_f0[v0:v1] if x > 0]
    model_med = st.median(voiced) if voiced else target_hz
    if v["f0"] == "model":  # 모델 곡선을 그대로 두고 높이만 목표로 옮김
        q.f0 = [x * target_hz / model_med if x > 0 else 0.0 for x in model_f0]
    else:
        new = [target_hz if x > 0 else 0.0 for x in model_f0]
        if v["f0"] == "fall":
            k0 = v1 - int(round((v1 - v0) * v["fall_frac"]))
            for i in range(k0, len(new)):
                u = min(1.0, (i - k0) / max(1, v1 - k0))
                if new[i] > 0:
                    new[i] = target_hz * 2 ** (-v["fall_cents"] * u / 1200)
        q.f0 = new
    if v.get("volume") == "hold":  # 모음 가운데의 음량 출렁임을 평평하게(시작과 끝 감쇠는 모델 그대로)
        vol = list(q.volume)
        plateau = st.median(vol[v0:v1])
        above = [i for i in range(c0, v1) if vol[i] >= plateau]
        if above:
            for i in range(above[0], above[-1] + 1):
                vol[i] = plateau
        q.volume = vol
    elif v.get("volume") == "mono":  # 첫 봉우리 뒤로는 줄기만 하게(가운데 움푹 꺼짐을 뒤쪽 높이로 채움)
        vol = list(q.volume)
        p = max(range(c0, v1), key=lambda i: vol[i])
        for i in range(len(vol) - 2, p - 1, -1):
            vol[i] = max(vol[i], vol[i + 1])
        q.volume = vol
    s, rate = pcm_of(synth.frame_synthesis(q, singer))
    if v.get("tail_fade_s"):
        s = cosine_tail(s, rate, v["tail_fade_s"])
    info = {"lyric": lyric, "key": key, "note_frames": n,
            "phonemes": [(p.phoneme, p.frame_length) for p in q.phonemes],
            "model_f0_med": round(model_med, 1),
            "model_f0_sd_c": round(st.pstdev(1200 * math.log2(x / model_med) for x in voiced), 1) if voiced else None}
    return s, rate, info


def cmd_round5(cfg: dict, synth: Synthesizer) -> None:
    """노래 모델로 가나 한 박. 쿼리·f0·음량은 가창 교사(singing_teacher 또는 sing 종류) 스타일로 만들고,
    소리는 春日部つむぎ의 frame_decode 스타일로 합성한다. f0는 말소리 높이로 덮어쓴다."""
    from voicevox_core import FrameAudioQuery  # noqa: F401  (타입 확인용)
    r5 = cfg["round5"]
    fc = cfg["final"]
    m_cfg = cfg["measure"]
    f = cfg["round2"]["f0"]
    out_dir = ROOT / r5["output_dir"]
    out_dir.mkdir(parents=True, exist_ok=True)
    s0 = VoiceModelFile.open(ROOT / cfg["core_dir"] / r5["vvm"])
    synth.load_voice_model(s0)
    styles = {s["id"]: (c["name"], s["name"], s["type"]) for c in metas_of(s0) for s in c["styles"]}
    teacher, singer = r5["teacher_style_id"], r5["singer_style_id"]
    print("교사", teacher, styles.get(teacher), "/ 가수", singer, styles.get(singer))

    # 말소리 높이: 앱 단어 소리(final/word)의 F0 중앙값
    ref = speech_f0(sorted((ROOT / fc["output_dir"] / "word").glob("*.wav")), f)
    ref_n = speech_f0(sorted((ROOT / fc["n_kana_dir"]).glob("*.wav")), f)
    target_hz = ref["median_hz"]
    key = int(round(hz_to_midi(target_hz)))
    print(f"말소리 F0: 단어 {ref} / 글자 N {ref_n} -> 목표 {target_hz}Hz, key {key}")

    lyric_check = {}
    for lyr in r5["lyric_check"]:
        try:
            q = synth.create_sing_frame_audio_query(song_score(lyr, 38, key, 15, 15), teacher)
            lyric_check[lyr] = {"ok": True, "phonemes": [p.phoneme for p in q.phonemes]}
        except Exception as e:
            lyric_check[lyr] = {"ok": False, "error": f"{type(e).__name__}: {e}"}
        print("가사", lyr, lyric_check[lyr])

    def make(v: dict, char: str) -> tuple[array.array, int, dict]:
        return song_letter(synth, {**r5, **v}, char, target_hz, teacher, singer)

    rows = []
    for key_v, v in r5["variants"].items():
        (out_dir / key_v).mkdir(exist_ok=True)
        for char, romaji in r5["letters"]:
            try:
                s, rate, info = make(v, char)
            except Exception as e:
                rows.append({"cand": key_v, "kana": char, "error": f"{type(e).__name__}: {e}"})
                print(f"{key_v} {char}: 실패 {e}")
                continue
            s = trim_pad(s, rate, fc["lead_silence"], fc["tail_silence"], fc["trim_floor_dbfs"])
            s, gain = normalize(s, rate, m_cfg, fc["normalize"])
            write_wav(out_dir / key_v / f"kana_{romaji}.wav", s, rate)
            a = measure4(s, rate, cfg)
            rows.append({"cand": key_v, "kana": char, "romaji": romaji, "gain_db": gain, **info, **a})
            print(f"{key_v:<7} {char} 소리 {a['voiced']:.2f}s 감쇠 {a['decay_s']:.3f}s F0 {a.get('f0')} "
                  f"sd {a.get('f0_sd_c')}c resid {a.get('f0_resid_c')}c jit {a.get('jitter_pct')} "
                  f"4-12 {a.get('f0_mod_4_12_c')}c 진폭 {a.get('amp_mod_4_12_db')}dB")

    for char, romaji in r5["letters"]:  # 기준: 앱 N
        p = ROOT / fc["n_kana_dir"] / f"kana_{romaji}.wav"
        s, rate = read_wav(p)
        a = measure4(s, rate, cfg)
        rows.append({"cand": "N", "kana": char, "romaji": romaji, **a})

    summary = {}
    for key_v in ["N"] + list(r5["variants"]):
        rs = [r for r in rows if r["cand"] == key_v and "error" not in r]
        def med(k):
            vals = [r[k] for r in rs if r.get(k) is not None]
            return round(st.median(vals), 3) if vals else None
        summary[key_v] = {
            "made": len(rs), "voiced_min": min((r["voiced"] for r in rs), default=None),
            "voiced_max": max((r["voiced"] for r in rs), default=None), "voiced_med": med("voiced"),
            "in_range": sum(1 for r in rs if r5["target_voiced"][0] <= r["voiced"] <= r5["target_voiced"][1]),
            "decay_med": med("decay_s"), "f0_med": med("f0"), "f0_sd_med": med("f0_sd_c"),
            "f0_resid_med": med("f0_resid_c"), "jitter_med": med("jitter_pct"),
            "jitter_max": max((r["jitter_pct"] for r in rs if r.get("ok")), default=None),
            "f0_mod_4_12_med": med("f0_mod_4_12_c"), "amp_mod_4_12_med": med("amp_mod_4_12_db"),
            "model_f0_sd_med": med("model_f0_sd_c"),
            "failed_make": [r["kana"] for r in rows if r["cand"] == key_v and "error" in r],
            "failed_measure": [r["kana"] for r in rs if not r.get("ok")],
        }
        print(key_v, summary[key_v])
        joined, rate = array.array("h"), 24000
        for char, romaji in r5["letters"]:
            p = (ROOT / fc["n_kana_dir"] if key_v == "N" else out_dir / key_v) / f"kana_{romaji}.wav"
            if not p.exists():
                continue
            s, rate = read_wav(p)
            joined.extend(s)
            joined.extend(silence(rate, r5["letter_gap"]))
        write_wav(out_dir / f"preview-{key_v}.wav", joined, rate)
        summary[key_v]["preview_s"] = round(len(joined) / rate, 1)

    with (out_dir / "measurements.json").open("w", encoding="utf-8") as fp:
        json.dump({"teacher": {"id": teacher, "style": styles.get(teacher)},
                   "singer": {"id": singer, "style": styles.get(singer)},
                   "speech_f0_word": ref, "speech_f0_kana_N": ref_n, "target_hz": target_hz, "key": key,
                   "lyric_check": lyric_check, "variants": r5["variants"], "summary": summary, "files": rows},
                  fp, ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- main

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("command", nargs="?", default="round1",
                    choices=["metas", "round1", "shake", "giri", "round3", "final", "round4", "round5"])
    ap.add_argument("--config", default=str(ROOT / "tools" / "voice.json"))
    ap.add_argument("--kana-only", action="store_true",
                    help="final: 글자만 다시 만든다(단어 m4a는 그대로 둔다)")
    args = ap.parse_args()
    cfg = load_config(Path(args.config))
    synth, model, load_seconds = open_synthesizer(cfg)
    if args.command == "metas":
        print(json.dumps(metas_of(model), ensure_ascii=False, indent=2))
    elif args.command == "round1":
        cmd_round1(cfg, synth, model, load_seconds)
    elif args.command == "shake":
        cmd_shake(cfg, synth)
    elif args.command == "giri":
        cmd_giri(cfg, synth)
    elif args.command == "round3":
        cmd_round3(cfg, synth)
    elif args.command == "final":
        cmd_final(cfg, synth, kana_only=args.kana_only)
    elif args.command == "round4":
        cmd_round4(cfg, synth)
    elif args.command == "round5":
        cmd_round5(cfg, synth)


if __name__ == "__main__":
    main()
