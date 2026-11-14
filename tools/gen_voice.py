#!/usr/bin/env python3
"""VOICEVOX CORE로 발음 샘플을 만든다 (시험용).

준비와 실행 방법은 docs/design/voice/README.md 참고. 설정은 tools/voice.json.

    .voicevox/venv/bin/python -I tools/gen_voice.py metas    # 0.vvm에 든 목소리·스타일 id
    .voicevox/venv/bin/python -I tools/gen_voice.py round1   # 1차: 글자 A/B/C, 단어 2속도 (docs/design/voice/samples)
    .voicevox/venv/bin/python -I tools/gen_voice.py shake    # 2차: 글자 떨림 비교 (samples2/shake)
    .voicevox/venv/bin/python -I tools/gen_voice.py giri     # 2차: 기리 목소리 후보 (samples2)

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


# ---------------------------------------------------------------- main

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("command", nargs="?", default="round1", choices=["metas", "round1", "shake", "giri"])
    ap.add_argument("--config", default=str(ROOT / "tools" / "voice.json"))
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


if __name__ == "__main__":
    main()
