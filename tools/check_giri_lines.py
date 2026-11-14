#!/usr/bin/env python3
"""앱 데이터에 옮긴 기리 대사를 검사한다 (giri-lines.md 9.4, 맨 위 "글자 수 상한" 표).

1. 빠짐없이: 단어 설명 60개(hiragana_scenes.json 단어의 `giri`), 장면 소개 8개(`giriIntro`),
   쓰기 포인트 46개(hiragana_tips.json), 헷갈리는 쌍 짚기 19개(confusable_pairs.json `giri`)
2. 남는 키가 없는지(쓰기 포인트, 쌍 짚기)
3. 글자 수: 공백과 문장부호를 포함해 센다. 문장은 마침표·물음표 뒤 공백으로 나눈다.
   - 한 문장 22자, 말풍선 하나 2문장
   - 단어 설명 40자, 장면 소개 26자, 쓰기 포인트 48자(첫 문장은 앞 28자 안), 쌍 짚기 28자
4. 쓰지 않는 기호(!, ~, 이모지)
5. 문서(giri-lines.md)와 데이터가 같은지: tools/build_giri_lines.py를 다시 돌릴 필요가 없는지
상한을 넘는 대사는 고치지 않고 목록으로 보고한다(종료 코드 1).
고정 대사(Strings.swift)는 KanaTripTests/GiriSpeechTests가 가장 긴 데이터로 채워 센다.
실행: python3 tools/check_giri_lines.py
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_giri_lines import DOC, PAIRS, SCENES, TIPS, parse  # noqa: E402

KANA = list("あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん")

SENTENCE = 22
SENTENCES = 2
LIMITS = {"단어 설명": 40, "장면 소개": 26, "쓰기 포인트": 48, "쌍 짚기": 28}
TIP_FIRST = 28

problems: list[str] = []
over: list[str] = []


def sentences(text: str) -> list[str]:
    return [s for s in re.split(r"(?<=[.?])\s+", text.strip()) if s]


def check_text(kind: str, key: str, text: str) -> None:
    where = f"{kind} {key}"
    if len(text) > LIMITS[kind]:
        over.append(f"{where}: {len(text)}자 > {LIMITS[kind]}자  \"{text}\"")
    parts = sentences(text)
    if len(parts) > SENTENCES:
        over.append(f"{where}: {len(parts)}문장 > {SENTENCES}문장  \"{text}\"")
    for s in parts:
        if len(s) > SENTENCE:
            over.append(f"{where}: 문장 {len(s)}자 > {SENTENCE}자  \"{s}\"")
    if kind == "쓰기 포인트" and parts and len(parts[0]) > TIP_FIRST:
        over.append(f"{where}: 첫 문장 {len(parts[0])}자가 앞 {TIP_FIRST}자를 넘음  \"{parts[0]}\"")
    if re.search(r"[!~！～]|[\U0001F300-\U0001FAFF☀-➿]", text):
        problems.append(f"{where}: 쓰지 않는 기호  \"{text}\"")


def same_keys(name: str, have, want) -> None:
    have, want = set(have), set(want)
    if want - have:
        problems.append(f"{name}: 빠짐 {sorted(want - have)}")
    if have - want:
        problems.append(f"{name}: 남음 {sorted(have - want)}")


def main() -> int:
    data = json.loads(SCENES.read_text(encoding="utf-8"))
    tips = json.loads(TIPS.read_text(encoding="utf-8"))
    pair_file = json.loads(PAIRS.read_text(encoding="utf-8"))
    doc_words, doc_intros, doc_tips, doc_pairs = parse(DOC.read_text(encoding="utf-8"))

    scenes = data["scenes"]
    words = {w["text"]: w for s in scenes for st in s["steps"] for w in st["words"]}

    # 1~2. 빠짐과 남음
    if len(words) != 60:
        problems.append(f"단어 수 {len(words)} (60이어야 함)")
    if len(scenes) != 8:
        problems.append(f"장면 수 {len(scenes)} (8이어야 함)")
    for text, w in words.items():
        if not w.get("giri"):
            problems.append(f"단어 설명 {text}: 없음")
        elif w["giri"] != doc_words.get(text):
            problems.append(f"단어 설명 {text}: 문서와 다름 (build_giri_lines.py를 다시 돌린다)")
    same_keys("단어 설명(문서)", doc_words, words)
    for s in scenes:
        if not s.get("giriIntro"):
            problems.append(f"장면 소개 {s['id']}: 없음")
        elif s["giriIntro"] != doc_intros.get(s["id"]):
            problems.append(f"장면 소개 {s['id']}: 문서와 다름")
    same_keys("장면 소개(문서)", doc_intros, [s["id"] for s in scenes])
    same_keys("쓰기 포인트", tips, KANA)
    for c, t in tips.items():
        if doc_tips.get(c) != t:
            problems.append(f"쓰기 포인트 {c}: 문서와 다름")
    pair_keys = ["".join(p) for p in pair_file["hiragana"]]
    if len(pair_keys) != 19:
        problems.append(f"헷갈리는 쌍 {len(pair_keys)}개 (19여야 함)")
    lines = pair_file.get("giri", {})
    same_keys("쌍 짚기", lines, pair_keys)
    for key, t in lines.items():
        if (doc_pairs.get(key) or doc_pairs.get(key[::-1])) != t:
            problems.append(f"쌍 짚기 {key}: 문서와 다름")

    # 3~4. 글자 수와 기호
    for text, w in words.items():
        if w.get("giri"):
            check_text("단어 설명", text, w["giri"])
    for s in scenes:
        if s.get("giriIntro"):
            check_text("장면 소개", s["id"], s["giriIntro"])
    for c, t in tips.items():
        check_text("쓰기 포인트", c, t)
    for key, t in lines.items():
        check_text("쌍 짚기", key, t)

    longest = {
        "단어 설명": max(len(w.get("giri", "")) for w in words.values()),
        "장면 소개": max(len(s.get("giriIntro", "")) for s in scenes),
        "쓰기 포인트": max(len(t) for t in tips.values()),
        "쌍 짚기": max(len(t) for t in lines.values()),
    }
    print(f"단어 설명 {sum(1 for w in words.values() if w.get('giri'))}/{len(words)}, "
          f"장면 소개 {sum(1 for s in scenes if s.get('giriIntro'))}/{len(scenes)}, "
          f"쓰기 포인트 {len(tips)}/46, 쌍 짚기 {len(lines)}/{len(pair_keys)}")
    print("가장 긴 대사: " + ", ".join(f"{k} {v}자" for k, v in longest.items()))
    if over:
        print(f"\n상한을 넘는 대사 {len(over)}개 (고치지 않음, planner 확인):")
        for line in over:
            print(f"  - {line}")
    if problems:
        print(f"\n문제 {len(problems)}건:")
        for line in problems:
            print(f"  - {line}")
    if not over and not problems:
        print("\n통과: 빠진 대사 없음, 상한을 넘는 대사 없음")
    return 1 if over or problems else 0


if __name__ == "__main__":
    sys.exit(main())
