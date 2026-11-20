#!/usr/bin/env python3
"""Whisper로 발음 소리를 검증한다(검증 전용, 앱에 넣지 않음). docs/design/voice/README.md "검증(Whisper)".

모델: mlx-community/whisper-large-v3-turbo (1.6GB). 변환본 저장소에는 라이선스 표기가 없고, 원본
openai/whisper-large-v3-turbo는 MIT다. 로컬 검증에만 쓰고 재배포하지 않는다.

    .venv-tts/bin/pip install mlx-whisper
    .venv-tts/bin/python -I tools/verify_voice.py selftest   # 검증기 자체 검증(정답이 확실한 VOICEVOX 단어·글자)
    .venv-tts/bin/python -I tools/verify_voice.py kana       # 앱 글자 58자(Qwen) 검증, 틀린 글자 교체
    .venv-tts/bin/python -I tools/verify_voice.py words      # samples8 단어 60개 검증, 틀린 단어 다시 뽑기

인식 설정: language="ja", temperature 0(되풀이 없음), condition_on_previous_text 끔, no_speech·logprob·압축률
문턱은 끄고(빈 결과로 버리지 않게) 값을 기록한다. 소리는 24kHz → 16kHz로 바꿔 numpy로 넘긴다(ffmpeg 불필요).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import unicodedata
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import gen_voice_qwen as g  # noqa: E402

MODEL = "mlx-community/whisper-large-v3-turbo"
OUT = ROOT / "docs/design/voice/verify"
PROMPT = "ひらがな一文字"
GAP_S = 0.15
PAD_S = 0.5

# 단어의 한자 표기 → 읽기. 앱 단어 목록(표기·note에 적힌 다른 표기)과 흔한 표기에서 만들었다.
# 여기 없는 한자가 남으면 "판정 불가"로 둔다.
WORD_KANJI = {
    "寿司": "すし", "鮨": "すし", "烏賊": "いか", "蛸": "たこ", "鮪": "まぐろ", "海老": "えび", "稲荷": "いなり",
    "豚カツ": "とんかつ", "カツ丼": "かつどん", "丼": "どん", "ヒレカツ": "ひれかつ", "御飯": "ごはん", "ご飯": "ごはん",
    "お代わり": "おかわり", "饂飩": "うどん", "蕎麦": "そば", "狐": "きつね", "若布": "わかめ", "狸": "たぬき",
    "笊": "ざる", "駅": "えき", "お釣り": "おつり", "切符売り場": "きっぷうりば", "切符売場": "きっぷうりば", "売り場": "うりば",
    "乗り換え": "のりかえ", "乗換": "のりかえ", "此方": "こちら", "乗り場": "のりば", "出口": "でぐち",
    "入口": "いりぐち", "入り口": "いりぐち", "お守り": "おまもり", "お参り": "おまいり", "御神籤": "おみくじ",
    "お神籤": "おみくじ", "縁結び": "えんむすび", "たこ焼き": "たこやき", "お祭り": "おまつり", "当たり": "あたり",
    "焼きそば": "やきそば", "焼そば": "やきそば", "外れ": "はずれ", "りんご飴": "りんごあめ", "林檎飴": "りんごあめ",
    "焼き鳥": "やきとり", "焼鳥": "やきとり", "皮": "かわ", "胸": "むね", "軟骨": "なんこつ", "椎茸": "しいたけ",
    "お握り": "おにぎり", "鶉": "うずら", "湯": "ゆ", "温泉": "おんせん", "浴衣": "ゆかた", "檜": "ひのき",
    "靴を脱いでください": "くつをぬいでください", "靴": "くつ", "脱いで": "ぬいで", "御持て成し": "おもてなし",
    "お持て成し": "おもてなし", "茶": "ちゃ", "お風呂": "おふろ", "風呂": "ふろ", "お部屋": "おへや",
    "部屋": "へや", "布団": "ふとん", "蒲団": "ふとん",
}
# 한 글자 소리에서 Whisper가 한자로 적을 수 있는 것(한 모라 읽기). 읽기가 여럿이면 모두 적는다.
KANA_KANJI = {
    "胃": "い", "井": "い", "鵜": "う", "絵": "え", "柄": "え", "尾": "お", "御": "お", "蚊": "か", "木": "き",
    "気": "き", "九": "く", "区": "く", "毛": "け", "子": "こ", "粉": "こ", "碁": "ご", "五": "ご", "差": "さ",
    "詩": "し", "四": "し", "字": "じ", "痔": "じ", "酢": "す", "巣": "す", "背": "せ", "田": "た", "手": "て",
    "戸": "と", "十": "と", "度": "ど", "名": "な", "菜": "な", "二": "に", "荷": "に", "根": "ね", "値": "ね",
    "野": "の", "之": "の", "葉": "は", "歯": "は", "派": "は", "刃": "は", "場": "ば", "火": "ひ", "日": "ひ",
    "灯": "ひ", "屁": "へ", "帆": "ほ", "穂": "ほ", "間": "ま", "真": "ま", "実": "み", "身": "み", "三": "み",
    "目": "め", "芽": "め", "藻": "も", "喪": "も", "矢": "や", "湯": "ゆ", "世": "よ", "夜": "よ", "四つ": "よ",
    "輪": "わ", "和": "わ", "津": "つ", "血": "ち", "千": "ち", "地": "ち",
}
PUNCT = re.compile(r"[\s。、，,.!?！？「」『』…・~〜〜\-\"'()（）]")
CJK = re.compile(r"[一-鿿々]")


def kata_to_hira(s: str) -> str:
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in s)


def normalize(text: str, table: dict[str, str]) -> tuple[str, str]:
    """(정규화한 가나, 방식). 방식: kana(가나만), kanji(사전으로 바꿈), unknown(한자가 남음), latin(로마자 등)."""
    t = PUNCT.sub("", unicodedata.normalize("NFKC", text))
    how = "kana"
    if CJK.search(t):
        for k in sorted(table, key=len, reverse=True):
            if k in t:
                t = t.replace(k, table[k])
                how = "kanji"
        if CJK.search(t):
            how = "unknown"
    t = kata_to_hira(t).rstrip("ー")
    if re.search(r"[A-Za-z0-9]", t):
        how = "latin"
    return t, how


class Recognizer:
    def __init__(self) -> None:
        import mlx_whisper
        self.mw = mlx_whisper
        self.calls = 0
        self.seconds = 0.0

    def __call__(self, y24: np.ndarray, prompt: str | None = None) -> dict:
        y16 = resample_poly(y24, 2, 3).astype(np.float32)
        t0 = time.perf_counter()
        r = self.mw.transcribe(y16, path_or_hf_repo=MODEL, language="ja", temperature=0.0,
                               condition_on_previous_text=False, no_speech_threshold=None,
                               logprob_threshold=None, compression_ratio_threshold=None,
                               initial_prompt=prompt, verbose=None)
        self.seconds += time.perf_counter() - t0
        self.calls += 1
        segs = r.get("segments", [])
        return {"text": r["text"].strip(),
                "avg_logprob": round(min((s["avg_logprob"] for s in segs), default=0.0), 3),
                "no_speech": round(max((s["no_speech_prob"] for s in segs), default=1.0), 3)}


def pad(y: np.ndarray) -> np.ndarray:
    z = np.zeros(int(g.SR * PAD_S))
    return np.concatenate([z, y, z])


def repeat3(y: np.ndarray) -> np.ndarray:
    gap = np.zeros(int(g.SR * GAP_S))
    return np.concatenate([y, gap, y, gap, y])


ROWS = {"a": "あかさたなはまやらわがざだばぱ", "i": "いきしちにひみりぎじぢびぴ", "u": "うくすつぬふむゆるぐずづぶぷ",
        "e": "えけせてねへめれげぜでべぺ", "o": "おこそとのほもよろをごぞどぼぽ"}
VOWEL_OF = {c: v for v, cs in ROWS.items() for c in cs}
LENGTHEN = {"a": "あ", "i": "い", "u": "う", "e": "えい", "o": "おう"}
SMALL = str.maketrans("ぁぃぅぇぉ", "あいうえお")


def squash_long(s: str) -> str:
    """한 글자 소리를 Whisper가 늘여 적은 것(かあ, いい, はぁ, ゴー, ゆう)을 한 모라로 줄인다.
    앞 모라와 같은 모음을 이어 쓴 것과 ー, 촉음(あっ)을 지운다."""
    s = s.translate(SMALL).replace("っ", "")
    out = ""
    for c in s:
        if c == "ー" and out:
            continue
        if out and c in LENGTHEN.get(VOWEL_OF.get(out[-1], ""), ""):
            continue
        out += c
    return out


def kana_ok(norm: str, kana: str, repeated: bool) -> bool:
    norm = squash_long(norm)
    ok = {kana, "お"} if kana == "を" else {kana}
    ok |= {"を"} if kana == "を" else set()
    if not repeated:
        return norm in ok
    return any(norm == k * n for k in ok for n in (1, 2, 3, 4))


METHODS = {
    # 이름: (소리 만들기, initial_prompt, 되풀이 판정)
    "P": (lambda y: pad(y), None, False),
    "R3": (lambda y: pad(repeat3(y)), None, True),
    "PP": (lambda y: pad(y), PROMPT, False),
    "R3P": (lambda y: pad(repeat3(y)), PROMPT, True),
}


def check_kana(rec: Recognizer, y: np.ndarray, kana: str, methods: list[str]) -> dict:
    out = {}
    for m in methods:
        make, prompt, rep = METHODS[m]
        r = rec(make(y), prompt)
        norm, how = normalize(r["text"], KANA_KANJI)
        if prompt and PROMPT in r["text"]:
            how = "prompt_echo"
        out[m] = {**r, "norm": norm, "how": how, "ok": kana_ok(norm, kana, rep)}
    return out


def word_list() -> list[dict]:
    vcfg = json.loads((ROOT / "tools/voice.json").read_text(encoding="utf-8"))["final"]
    scenes = json.loads((ROOT / vcfg["scenes"]).read_text(encoding="utf-8"))
    index = json.loads((ROOT / "KanaTrip/Resources/Voice/voice_index.json").read_text(encoding="utf-8"))
    rows = []
    for scene in scenes["scenes"]:
        for step in scene["steps"]:
            for w in step["words"]:
                reading = "".join(vcfg["kanji_readings"][u["kana"]] if u.get("kanji") else u["kana"]
                                  for u in w["units"])
                rows.append({"text": w["text"], "reading": reading, "file": index["word"][w["text"]]})
    return rows


def word_table() -> dict[str, str]:
    t = dict(WORD_KANJI)
    for w in word_list():
        if CJK.search(w["text"]):
            t[w["text"]] = w["reading"]
    return t


def check_word(rec: Recognizer, y: np.ndarray, reading: str, table: dict) -> dict:
    r = rec(pad(y))
    norm, how = normalize(r["text"], table)
    norm = norm.removesuffix("っ")  # ゆ → 「ゆっ」처럼 끝에 촉음을 붙이는 경우
    # ぬる湯처럼 글자 수가 같은 다른 표기(ゆ/湯)는 위 사전으로, 장음(ようこそ/よーこそ)은 ー를 앞 모음으로 바꿔 본다
    alt = norm.replace("ー", "う")
    ok = norm == reading or alt == reading
    return {**r, "norm": norm, "how": how, "ok": ok}


# ---------------------------------------------------------------- 명령

def cmd_selftest() -> None:
    rec = Recognizer()
    index = json.loads((ROOT / "KanaTrip/Resources/Voice/voice_index.json").read_text(encoding="utf-8"))
    res: dict = {"model": MODEL, "words": [], "kanaS": [], "kanaN": []}
    table = word_table()
    for w in word_list():
        y, _ = sf.read(ROOT / "docs/design/voice/final/word" / f"{w['file']}.wav", dtype="float64")
        res["words"].append({**w, **check_word(rec, y, w["reading"], table)})
    for key, folder in (("kanaS", "final/kanaS"), ("kanaN", "final/kanaN")):
        for kana, name in index["kana"].items():
            path = ROOT / "docs/design/voice" / folder / f"{name}.wav"
            y, _ = sf.read(path, dtype="float64")
            res[key].append({"kana": kana, "file": name, **check_kana(rec, y, kana, list(METHODS))})
        print(key, {m: sum(r[m]["ok"] for r in res[key]) for m in METHODS}, flush=True)
    res["summary"] = summarize(res)
    res["whisper_calls"] = rec.calls
    res["whisper_s_per_call"] = round(rec.seconds / rec.calls, 3)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "selftest.json").write_text(json.dumps(res, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(json.dumps(res["summary"], ensure_ascii=False, indent=1))


def summarize(res: dict) -> dict:
    s = {"words": f"{sum(r['ok'] for r in res['words'])}/{len(res['words'])}",
         "words_how": dict(_count(r["how"] for r in res["words"]))}
    for key in ("kanaS", "kanaN"):
        rows = res[key]
        s[key] = {m: f"{sum(r[m]['ok'] for r in rows)}/{len(rows)}" for m in METHODS}
        # 둘 다 맞다고 할 때만 맞음으로 보는 조합(교체에 쓸 기준의 정밀도를 보기 위해)
        s[key]["P&R3"] = f"{sum(r['P']['ok'] and r['R3']['ok'] for r in rows)}/{len(rows)}"
        s[key]["P|R3"] = f"{sum(r['P']['ok'] or r['R3']['ok'] for r in rows)}/{len(rows)}"
        s[key + "_wrong_P"] = {r["kana"]: r["P"]["text"] for r in rows if not r["P"]["ok"]}
        s[key + "_wrong_R3"] = {r["kana"]: r["R3"]["text"] for r in rows if not r["R3"]["ok"]}
    return s


def _count(xs):
    d: dict = {}
    for x in xs:
        d[x] = d.get(x, 0) + 1
    return d


KANA_METHODS = ["P", "R3"]  # selftest 결과로 정했다(README 검증 절): 한 글자 정답률이 낮아 둘 중 하나라도 맞으면 맞음
SUSPECT = ["お", "ば"]
WATCH = ["お", "ば", "は", "へ", "を", "ふ", "ん", "た", "ぷ"]
NEW_TAKES = 12  # 맞는 후보가 없을 때 새로 뽑는 수(글자당)


def kana_pass(v: dict) -> bool:
    """교체에 쓰는 '맞음': P·R3 중 하나라도 기대 글자로 인식. selftest에서 정답 음성(お·を)도 あ로 듣는
    경향이 있어, 둘 다 맞기를 요구하면 맞는 소리도 거의 통과하지 못한다(P&R3 정답률 11/58, 21/58)."""
    return any(v[m]["ok"] for m in KANA_METHODS)


def cmd_kana(replace: str) -> None:
    import subprocess
    rec = Recognizer()
    app_dir = ROOT / g.FINAL["app_dir"]
    index = json.loads((app_dir / "voice_index.json").read_text(encoding="utf-8"))
    roms = {k: v.removeprefix("kana_") for k, v in index["kana"].items()}
    wav_dir = ROOT / g.FINAL["wav_dir"]
    tdir = ROOT / g.FINAL["takes_dir"]
    cache = tdir / "takes.json"
    rows_by_kana = json.loads(cache.read_text(encoding="utf-8"))
    before = {}
    for kana, name in index["kana"].items():
        y, _ = sf.read(wav_dir / f"{name}.wav", dtype="float64")
        before[kana] = check_kana(rec, y, kana, KANA_METHODS)
    wrong = [k for k in index["kana"] if not kana_pass(before[k])]
    print("before wrong:", {k: [before[k][m]["text"] for m in KANA_METHODS] for k in wrong}, flush=True)
    targets = [k for k in wrong if replace == "all" or k in SUSPECT]
    meas_path = ROOT / g.FINAL["measurements"]
    meas = json.loads(meas_path.read_text(encoding="utf-8"))
    center = meas["f0_center"]
    model = None
    changes = {}
    for kana in targets:
        rom = roms[kana]
        rows = rows_by_kana[kana]

        def eligible(r: dict) -> bool:
            if r["flags"]:
                return False
            off = abs(1200 * np.log2(r["f0"] / center)) if r.get("f0") else 9999
            if off > g.FINAL["pitch_off_c"]:
                return False
            if kana in ("は", "ひ", "ふ", "へ", "ほ") and (r.get("h_noise_s") or 0) < g.FINAL["h_noise_min_s"]:
                return False
            return True

        def scan(cands: list[dict]) -> list[dict]:
            found = []
            for r in cands:
                if not eligible(r):
                    continue
                y, _ = sf.read(tdir / f"kana_{rom}_{r['take']}.wav", dtype="float64")
                v = check_kana(rec, y, kana, KANA_METHODS)
                r["whisper"] = {m: v[m]["text"] for m in KANA_METHODS}
                if kana_pass(v):
                    found.append(r)
            return found

        found = scan(rows)
        if not found and not any(r["take"] > g.FINAL["max_takes"] + g.FINAL["kata_takes"] for r in rows):
            if model is None:
                model, _ = g.load()
                g.synth(model, "あ。", None, 0, 40, g.FINAL["speaker"])
            start = len(rows) + 1
            new = g.gen_letter_takes(model, kana, rom, start, start + NEW_TAKES - 1, tdir)
            for r in new:
                r["score"] = g.score(r)
                y, _ = sf.read(tdir / f"kana_{rom}_{r['take']}.wav", dtype="float64")
                fe = g.letter_features(y)
                r["h_noise_s"] = fe["h_noise_s"]
                r["onset_s"] = fe["onset_s"]
            rows.extend(new)
            found = scan(new)
        cache.write_text(json.dumps(rows_by_kana, ensure_ascii=False) + "\n", encoding="utf-8")
        if not found:
            changes[kana] = {"replaced": False, "before": before[kana], "takes": len(rows)}
            print(f"{kana}: no Whisper-correct candidate among {len(rows)}", flush=True)
            continue
        best = min(found, key=lambda r: (abs(np.log2(r["f0"] / center)), r["score"]))
        y, _ = sf.read(tdir / f"kana_{rom}_{best['take']}.wav", dtype="float64")
        y = g.normalize(y, g.CFG["post"]["rms_dbfs"], g.CFG["post"]["peak_dbfs"])
        name = index["kana"][kana]
        g.write(wav_dir / f"{name}.wav", y)
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", str(g.FINAL["aac_bitrate"]), "-c", "1",
                        str(wav_dir / f"{name}.wav"), str(app_dir / f"{name}.m4a")], check=True)
        m = g.measure(y)
        after = check_kana(rec, y, kana, KANA_METHODS)
        changes[kana] = {"replaced": True, "take": best["take"], "text": best.get("text", f"{kana}。"),
                         "before": before[kana], "after": after, "voiced": m["voiced"], "f0": m["f0"],
                         "rms_dbfs": m["rms_dbfs"], "takes": len(rows)}
        for row in meas["kana"]:
            if row["kana"] == kana:
                row.update({"take": best["take"], "text": best.get("text", f"{kana}。"), "voiced": m["voiced"],
                            "duration": m["duration"], "f0": m["f0"], "rms_dbfs": m["rms_dbfs"],
                            "peak_dbfs": m["peak_dbfs"], "decay_s": m["decay_s"], "f0_sd_c": m["f0_sd_c"],
                            "f0_jump_c": m["f0_jump_c"], "segs": m["segs"], "flags": m["flags"],
                            "checks": ["whisper_replaced"], "m4a_bytes": (app_dir / f"{name}.m4a").stat().st_size})
        print(f"{kana}: replaced with take {best['take']} {after[KANA_METHODS[0]]['text']!r}", flush=True)
    if any(c["replaced"] for c in changes.values()):
        meas_path.write_text(json.dumps(meas, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        g.write(ROOT / "docs/design/voice/final/preview-kana.wav",
                g.concat([wav_dir / f"{index['kana'][k]}.wav" for k in g.FINAL["preview"]], g.FINAL["preview_gap_s"]))
    # 최종 상태 다시 검증
    final = {}
    for kana, name in index["kana"].items():
        y, _ = sf.read(wav_dir / f"{name}.wav", dtype="float64")
        final[kana] = check_kana(rec, y, kana, list(METHODS))
    res = {"model": MODEL, "methods": KANA_METHODS, "replace": replace, "before_wrong": wrong,
           "before": before, "changes": changes, "final": final,
           "final_wrong": {k: {m: final[k][m]["text"] for m in METHODS} for k in final if not kana_pass(final[k])},
           "final_summary": {m: f"{sum(final[k][m]['ok'] for k in final)}/{len(final)}" for m in METHODS}}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "kana.json").write_text(json.dumps(res, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(json.dumps({k: res[k] for k in ("before_wrong", "final_wrong", "final_summary")}, ensure_ascii=False))


WORD_MAX = 20


def cmd_words() -> None:
    rec = Recognizer()
    table = word_table()
    out = ROOT / "docs/design/voice/samples8"
    tdir = ROOT / "build/voice8/takes"
    prev = json.loads((out / "measurements.json").read_text(encoding="utf-8"))
    by_file = {w["file"]: w for w in prev["words"]}
    model = None
    p = g.CFG["post"]
    ins = g.TONE["instructs"]["en1"]
    rows = []
    for w in word_list():
        name, reading = w["file"], w["reading"]
        rec_prev = by_file[name]
        long_s, short_s = rec_prev["long_s"], 0.08 * rec_prev["moras"]
        y, _ = sf.read(out / "words" / f"{name}.wav", dtype="float64")
        before = check_word(rec, y, reading, table)
        status = {"word": w["text"], "reading": reading, "file": name, "before": before,
                  "before_flags": rec_prev["best_flags"]}
        if before["ok"] and not rec_prev["best_flags"]:
            status.update(final=before, take=rec_prev["best"], changed=False)
            rows.append(status)
            continue
        # 이미 만든 후보 4개부터, 그다음 새로 뽑아 20번까지
        cands = []
        for t in range(1, WORD_MAX + 1):
            path = tdir / f"{name}_{t}.wav"
            if not path.exists():
                if model is None:
                    model, _ = g.load()
                    g.synth(model, "あ。", None, 0, 40, g.FINAL["speaker"])
                raw, _ = g.synth(model, f"{reading}。", ins, 3000 * t + len(reading), g.CFG["word_max_tokens"],
                                 g.FINAL["speaker"])
                g.write(path, g.normalize(g.trim_pad(raw), p["rms_dbfs"], p["peak_dbfs"]))
            yt, _ = sf.read(path, dtype="float64")
            m = g.measure(yt)
            pauses = len(g.segments(yt, g.CFG["split"]["seg_dbfs"], 0.15, 0.03)) - 1
            flags = (["long"] if m["voiced"] > long_s else []) + (["short"] if m["voiced"] < short_s else [])
            flags += ["pause"] if pauses > 0 and "っ" not in reading else []
            v = check_word(rec, yt, reading, table)
            cands.append({"take": t, "voiced": m["voiced"], "flags": flags, **v})
            if v["ok"] and not flags:
                break
        good = [c for c in cands if c["ok"] and not c["flags"]]
        best = good[0] if good else None
        if best:
            yb, _ = sf.read(tdir / f"{name}_{best['take']}.wav", dtype="float64")
            g.write(out / "words" / f"{name}.wav", yb)
        status.update(final=best or before, take=best["take"] if best else rec_prev["best"], changed=bool(best),
                      tries=len(cands), candidates=[{k: c[k] for k in ("take", "voiced", "flags", "text", "ok")}
                                                    for c in cands])
        rows.append(status)
        print(f"{w['text']}: {'ok take ' + str(best['take']) if best else 'FAILED'} after {len(cands)} "
              f"(before {before['text']!r} {rec_prev['best_flags']})", flush=True)
    g.write(out / "preview-words-all.wav", g.concat([out / "words" / f"{w['file']}.wav" for w in word_list()],
                                                    g.CFG["preview_gap_s"]))
    res = {"model": MODEL, "words": rows,
           "before_ok": sum(1 for r in rows if r["before"]["ok"] and not r["before_flags"]),
           "final_ok": sum(1 for r in rows if r["final"]["ok"]),
           "changed": [r["word"] for r in rows if r["changed"]],
           "failed": {r["word"]: r["final"]["text"] for r in rows if not r["final"]["ok"]}}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "words.json").write_text(json.dumps(res, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(json.dumps({k: res[k] for k in ("before_ok", "final_ok", "changed", "failed")}, ensure_ascii=False))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("selftest")
    k = sub.add_parser("kana")
    k.add_argument("--replace", choices=["suspect", "all"], default="suspect",
                   help="suspect: お·ば만 교체(검증기가 한 글자에서 믿을 만하지 않을 때), all: 틀린 글자 모두")
    sub.add_parser("words")
    a = ap.parse_args()
    if a.cmd == "selftest":
        cmd_selftest()
    elif a.cmd == "kana":
        cmd_kana(a.replace)
    else:
        cmd_words()


if __name__ == "__main__":
    main()
