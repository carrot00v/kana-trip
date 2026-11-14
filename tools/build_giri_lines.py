#!/usr/bin/env python3
"""기리 대사 문서(docs/content/giri-lines.md)의 표를 앱 데이터로 옮긴다 (giri-lines.md 9.1).

문서가 원본이다. 대사를 고치면 문서를 고치고 이 스크립트를 다시 돌린다.
  - 3번 단어 설명 (키 = 단어 text, "기리 설명" 열) → hiragana_scenes.json 단어의 `giri`
  - 4.1 장면 소개 (키 = 장면 id)                     → hiragana_scenes.json 장면의 `giriIntro`
  - 5.1 쓰기 포인트 (키 = 가나 한 글자)               → hiragana_tips.json 값
  - 6.2 헷갈리는 쌍 짚기 (키 = 두 글자)               → confusable_pairs.json `giri.{두 글자}`
단어 읽기 전 안내(4.2)와 오답 틀 문구(6.1)는 designer 고정 대사라 Strings.swift에 있다.
`note`는 화면에 쓰지 않지만 표기 정보 기록으로 데이터에 남긴다(9.3).
실행: python3 tools/build_giri_lines.py   (표준 라이브러리만 쓴다)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs/content/giri-lines.md"
RES = ROOT / "KanaTrip/Resources"
SCENES = RES / "hiragana_scenes.json"
TIPS = RES / "hiragana_tips.json"
PAIRS = RES / "confusable_pairs.json"

KANA = "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん"


def cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def tables(text: str):
    """(절 제목, 헤더, 행 목록) 표를 차례로 돌려준다."""
    lines = text.splitlines()
    heading = ""
    i = 0
    while i < len(lines):
        if lines[i].startswith("#"):
            heading = lines[i].lstrip("#").strip()
        if lines[i].startswith("|") and i + 1 < len(lines) and re.match(r"^\|[-| :]+\|$", lines[i + 1].strip()):
            header = cells(lines[i])
            rows = []
            i += 2
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(cells(lines[i]))
                i += 1
            yield heading, header, rows
        else:
            i += 1


def column(header: list[str], name: str) -> int | None:
    return header.index(name) if name in header else None


def parse(text: str):
    words, intros, tips, pairs = {}, {}, {}, {}
    for heading, header, rows in tables(text):
        k = column(header, "키")
        if k is None:
            continue
        if heading.startswith("3.") and (say := column(header, "기리 설명")) is not None:
            target = words
        elif heading.startswith("4.1") and (say := column(header, "대사")) is not None:
            target = intros
        elif heading.startswith("5.1") and (say := column(header, "대사")) is not None:
            target = tips
        elif heading.startswith("6.2") and (say := column(header, "대사")) is not None:
            target = pairs
        else:
            continue
        for row in rows:
            if len(row) <= max(k, say):
                continue
            key, value = row[k].strip("`"), row[say].strip()
            if key and value:
                if key in target:
                    raise SystemExit(f"{heading}: 키 {key}가 두 번 나온다")
                target[key] = value
    return words, intros, tips, pairs


def write(path: Path, data) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    words, intros, tips, pairs = parse(DOC.read_text(encoding="utf-8"))

    data = json.loads(SCENES.read_text(encoding="utf-8"))
    missing = []
    for i, scene in enumerate(data["scenes"]):
        # giriIntro는 장면 이름 바로 뒤에 둔다.
        rebuilt = {}
        for key, value in scene.items():
            if key == "giriIntro":
                continue
            rebuilt[key] = value
            if key == "name" and scene["id"] in intros:
                rebuilt["giriIntro"] = intros[scene["id"]]
        data["scenes"][i] = scene = rebuilt
        if scene["id"] not in intros:
            missing.append(f"giriIntro {scene['id']}")
        for step in scene["steps"]:
            for word in step["words"]:
                if word["text"] in words:
                    word["giri"] = words[word["text"]]
                else:
                    word.pop("giri", None)
                    missing.append(f"단어 {word['text']}")
    write(SCENES, data)

    old_tips = json.loads(TIPS.read_text(encoding="utf-8"))
    new_tips = {c: tips[c] for c in old_tips if c in tips}
    new_tips.update({c: tips[c] for c in KANA if c in tips and c not in new_tips})
    write(TIPS, new_tips)
    missing += [f"쓰기 포인트 {c}" for c in KANA if c not in tips]

    pair_file = json.loads(PAIRS.read_text(encoding="utf-8"))
    pair_file["giri"] = {}
    for a, b in pair_file["hiragana"]:
        line = pairs.get(a + b) or pairs.get(b + a)
        if line:
            pair_file["giri"][a + b] = line
        else:
            missing.append(f"쌍 {a}{b}")
    write(PAIRS, pair_file)

    print(f"단어 설명 {len(words)}, 장면 소개 {len(intros)}, 쓰기 포인트 {len(tips)}, 쌍 짚기 {len(pairs)}")
    if missing:
        print("문서에서 찾지 못함: " + ", ".join(missing))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
