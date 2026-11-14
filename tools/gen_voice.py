#!/usr/bin/env python3
"""VOICEVOX CORE로 발음 샘플을 만든다 (시험용).

준비와 실행 방법은 docs/design/voice/README.md 참고. 설정은 tools/voice.json.

    .voicevox/venv/bin/python -I tools/gen_voice.py            # 샘플 전부
    .voicevox/venv/bin/python -I tools/gen_voice.py --metas    # 0.vvm에 든 목소리·스타일 id만 출력

결과:
- {output_dir}/{목소리}-{로마자}-{A|B|C}.wav        글자
- {output_dir}/{목소리}-{로마자}-{normal|slow}.wav  단어
- {output_dir}/preview.wav                          글자 C안 + 단어 느린 속도를 이어 붙인 미리듣기
- {output_dir}/measurements.json                    길이·음량·음소·합성 시간
"""

from __future__ import annotations

import argparse
import array
import dataclasses
import glob
import io
import json
import math
import time
import wave
from pathlib import Path

from voicevox_core import AudioQuery
from voicevox_core.blocking import Onnxruntime, OpenJtalk, Synthesizer, VoiceModelFile

ROOT = Path(__file__).resolve().parent.parent


def load_config(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def open_synthesizer(cfg: dict) -> tuple[Synthesizer, VoiceModelFile]:
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
    return synth, model


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


def stretch_moras(query: AudioQuery, mora_seconds: float, min_vowel: float) -> AudioQuery:
    """각 박의 자음+모음 길이가 mora_seconds가 되도록 모음을 늘린다(자음은 그대로)."""
    phrases = []
    for ap in query.accent_phrases:
        moras = []
        for m in ap.moras:
            cons = m.consonant_length or 0.0
            moras.append(dataclasses.replace(m, vowel_length=max(min_vowel, mora_seconds - cons)))
        phrases.append(dataclasses.replace(ap, moras=moras))
    return dataclasses.replace(query, accent_phrases=phrases)


def pcm_of(wav_bytes: bytes) -> tuple[array.array, int]:
    with wave.open(io.BytesIO(wav_bytes)) as w:
        assert w.getsampwidth() == 2, "16bit PCM만 처리한다"
        rate, ch = w.getframerate(), w.getnchannels()
        data = array.array("h", w.readframes(w.getnframes()))
    if ch == 2:
        data = array.array("h", data[0::2])
    return data, rate


def dbfs(value: float) -> float:
    return round(20 * math.log10(value / 32768), 1) if value > 0 else -120.0


def measure(samples: array.array, rate: int, frame_ms: int, silence_dbfs: float) -> dict:
    n = max(1, rate * frame_ms // 1000)
    threshold = 32768 * 10 ** (silence_dbfs / 20)
    active = []
    for i in range(0, len(samples), n):
        frame = samples[i:i + n]
        rms = math.sqrt(sum(s * s for s in frame) / len(frame))
        active.append(rms >= threshold)
    idx = [i for i, a in enumerate(active) if a]
    if idx:
        start, end = idx[0] * n, min(len(samples), (idx[-1] + 1) * n)
    else:
        start = end = 0
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


def write_wav(path: Path, samples: array.array, rate: int) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(samples.tobytes())


def kana_query(synth: Synthesizer, candidates: list[str], style_id: int) -> tuple[AudioQuery, str, list[str]]:
    errors = []
    for kana in candidates:
        try:
            return synth.create_audio_query_from_kana(kana, style_id), kana, errors
        except Exception as e:  # 받아들이지 않는 표기면 다음 후보
            errors.append(f"{kana}: {type(e).__name__}: {e}")
    raise RuntimeError("; ".join(errors))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default=str(ROOT / "tools" / "voice.json"))
    ap.add_argument("--metas", action="store_true", help="목소리·스타일 id만 출력")
    args = ap.parse_args()
    cfg = load_config(Path(args.config))

    t0 = time.perf_counter()
    synth, model = open_synthesizer(cfg)
    load_seconds = time.perf_counter() - t0

    metas = [
        {"name": c.name, "styles": [{"name": s.name, "id": int(s.id), "type": s.type} for s in c.styles]}
        for c in model.metas
    ]
    if args.metas:
        print(json.dumps(metas, ensure_ascii=False, indent=2))
        return

    out_dir = ROOT / cfg["output_dir"]
    out_dir.mkdir(parents=True, exist_ok=True)
    m_cfg = cfg["measure"]
    results = []
    preview_parts: dict[str, list[array.array]] = {}
    rate_seen = None

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
            "file": path.name,
            "voice": voice["slug"],
            "kind": kind,
            "synth_seconds": round(synth_seconds, 3),
            "phonemes": phonemes(query),
            "query_kana": query.kana,
            "speed_scale": query.speed_scale,
            "pre": query.pre_phoneme_length,
            "post": query.post_phoneme_length,
            "moras": mora_detail(query),
            "sampling_rate": rate,
            "bytes": path.stat().st_size,
            **extra,
            **measure(samples, rate, m_cfg["frame_ms"], m_cfg["silence_dbfs"]),
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
            base, used, rejected = kana_query(synth, letter["aquestalk"], sid)
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
    gap = array.array("h", [0] * int(rate_seen * pv["gap_seconds"]))
    joined = array.array("h")
    for voice in cfg["voices"]:
        for part in preview_parts.get(voice["slug"], []):
            joined.extend(part)
            joined.extend(gap)
    write_wav(out_dir / pv["file"], joined, rate_seen)
    print(f"{pv['file']}: {len(joined) / rate_seen:.1f}s")

    summary = {
        "voicevox_core": "0.17.1",
        "vvm": cfg["vvm"],
        "cpu_num_threads": cfg["cpu_num_threads"],
        "load_seconds": round(load_seconds, 2),
        "metas": metas,
        "files": results,
    }
    with (out_dir / "measurements.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
