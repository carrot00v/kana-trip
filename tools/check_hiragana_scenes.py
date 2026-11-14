#!/usr/bin/env python3
"""hiragana_scenes.json을 배정 문서(docs/content/hiragana-allocation.md)와 대조한다.

확인하는 것:
  1. 기본 히라가나 46자가 16단계에 정확히 한 번씩 배정됐는지 (누락·중복·46자 밖 글자 0)
  2. 단계별 새 글자와 배우기 순서, 누적 글자 수가 문서 3.1과 같은지
  3. 장면별 글자 수가 문서 2.1과 같은지
  4. 단계별 단어(순서 포함), 읽기, 뜻이 문서 4번 표와 같은지
  5. 단어별 못 읽는 글자 수(못 읽는 글자로 / 탁음을 기본 글자로)를 누적 글자로 다시 세어 문서 4번·6번 표와 같은지
  6. 새 글자가 자기 단계 단어에 나오는지, 표기와 칸이 맞는지, 두 단계에 겹치는 단어가 없는지
  7. 단계 id가 {장면 id}-a / -b 인지
  8. hiragana_tips.json의 か, た 문구가 문서 10.3과 같은지

실행: python3 tools/check_hiragana_scenes.py   (표준 라이브러리만 쓴다)
통과하면 0, 하나라도 어긋나면 1로 끝난다.
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs/content/hiragana-allocation.md"
SCENES = ROOT / "KanaTrip/Resources/hiragana_scenes.json"
TIPS = ROOT / "KanaTrip/Resources/hiragana_tips.json"

BASIC = list("あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん")

errors: list[str] = []


def check(ok: bool, message: str) -> None:
    if not ok:
        errors.append(message)


def base_kana(ch: str) -> str:
    """탁음·반탁음을 기본 글자로 (ば → は). 작은 글자는 그대로 둔다."""
    return unicodedata.normalize("NFC", unicodedata.normalize("NFD", ch)[0])


def cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def section(text: str, heading: str) -> str:
    """heading부터 같은 수준 이상의 다음 제목 앞까지."""
    start = text.index(heading)
    rest = text[start + len(heading):]
    level = len(heading.split(" ")[0])
    nxt = re.search(r"^#{2,%d} " % level, rest, re.M)
    return rest[: nxt.start()] if nxt else rest


def parse_doc(text: str):
    # 3.1 단계별 새 글자와 누적 글자
    steps = []  # (key, new kana list, cumulative count)
    for line in section(text, "### 3.1").splitlines():
        m = re.match(r"^\| (\d[ab]) [^|]+\|([^|]+)\| (\d+) \|[^|]+\| (\d+) \|", line)
        if m:
            kana = m.group(2).split()
            check(len(kana) == int(m.group(3)), f"문서 3.1 {m.group(1)}: 글자와 글자 수가 다름")
            steps.append((m.group(1), kana, int(m.group(4))))

    # 2.1 장면별 글자 수 (a + b = n)
    scene_counts = {}
    for line in section(text, "### 2.1").splitlines():
        m = re.match(r"^\| (\d) \|.*\| (\d) \+ (\d) = (\d) \|$", line)
        if m:
            scene_counts[int(m.group(1))] = int(m.group(4))

    # 4번 단계별 단어 표: 표기, 읽기, 뜻, 못 읽는 글자 수, 탁음을 기본 글자로
    words4: dict[str, list[tuple]] = {}
    current = None
    for line in section(text, "## 4. 단계별 단어").splitlines():
        m = re.match(r"^\*\*(\d[ab]) ", line)
        if m:
            current = m.group(1)
            words4[current] = []
            continue
        if current and line.startswith("| ") and not line.startswith("| 표기") and not line.startswith("|---"):
            c = cells(line)
            words4[current].append((c[0], c[1], c[2], int(c[3]), int(c[4])))
        elif current and words4[current] and not line.startswith("|"):
            current = None

    # 6번 단어별 못 읽는 글자 수 표
    words6: dict[str, list[tuple]] = {}
    table6 = text[text.index("단어별 못 읽는 글자 수 (못 읽는 글자로 / 기본 글자로)"):]
    for line in table6.splitlines():
        m = re.match(r"^\| (\d[ab]) \| (.+) \|$", line)
        if m:
            entries = []
            for item in m.group(2).split(", "):
                w, counts = item.rsplit(" ", 1)
                a, b = counts.split("/")
                entries.append((w, int(a), int(b)))
            words6[m.group(1)] = entries
        elif words6 and not line.startswith("|"):
            break

    # 10.3 쓰기 포인트 문구
    tips = {}
    for line in section(text, "### 10.3").splitlines():
        c = cells(line) if line.startswith("| ") else []
        if len(c) >= 2 and len(c[0]) == 1 and c[0] in BASIC:
            tips[c[0]] = c[1]

    return steps, scene_counts, words4, words6, tips


def main() -> int:
    text = DOC.read_text(encoding="utf-8")
    data = json.loads(SCENES.read_text(encoding="utf-8"))
    tips_json = json.loads(TIPS.read_text(encoding="utf-8"))
    doc_steps, doc_scene_counts, words4, words6, doc_tips = parse_doc(text)

    check(len(doc_steps) == 16, f"문서 3.1에서 단계 {len(doc_steps)}개를 읽음 (16개여야 함)")
    check(len(words4) == 16, f"문서 4번에서 단계 {len(words4)}개를 읽음")
    check(len(words6) == 16, f"문서 6번에서 단계 {len(words6)}개를 읽음")

    scenes = sorted(data["scenes"], key=lambda s: s["order"])
    json_steps = []
    for s in scenes:
        check(len(s["steps"]) == 2, f"{s['id']}: 단계가 {len(s['steps'])}개")
        for i, st in enumerate(s["steps"]):
            key = f"{s['order']}{'ab'[i]}"
            check(st["id"] == f"{s['id']}-{'ab'[i]}", f"{key}: 단계 id {st['id']}")
            json_steps.append((key, s, st))

    # 1. 46자 배정
    assigned = [k for _, _, st in json_steps for k in st["kana"]]
    missing = [k for k in BASIC if k not in assigned]
    dup = sorted({k for k in assigned if assigned.count(k) > 1})
    outside = [k for k in assigned if k not in BASIC]
    check(not missing, f"배정되지 않은 글자: {missing}")
    check(not dup, f"두 번 배정된 글자: {dup}")
    check(not outside, f"46자 밖의 글자: {outside}")

    # 2·3. 단계별·장면별 글자 수
    cumulative: set[str] = set()
    cum_by_step = {}
    for (key, scene, st), (dkey, dkana, dcum) in zip(json_steps, doc_steps):
        check(key == dkey, f"단계 순서가 다름: json {key} / 문서 {dkey}")
        check(st["kana"] == dkana, f"{key}: 새 글자 {st['kana']} / 문서 {dkana}")
        cumulative |= set(st["kana"])
        cum_by_step[key] = set(cumulative)
        check(len(cumulative) == dcum, f"{key}: 누적 {len(cumulative)}자 / 문서 {dcum}자")
    for s in scenes:
        n = sum(len(st["kana"]) for st in s["steps"])
        check(n == doc_scene_counts.get(s["order"]), f"장면 {s['order']}: {n}자 / 문서 {doc_scene_counts.get(s['order'])}자")
        check(5 <= n <= 6, f"장면 {s['order']}: {n}자 (5~6자 밖)")

    # 4·5·6. 단어
    seen_words: dict[str, str] = {}
    totals = {"words": 0, "readable": 0, "readable_base": 0}
    report_rows = []
    for key, scene, st in json_steps:
        known = cum_by_step[key]
        words = st["words"]
        d4 = words4.get(key, [])
        d6 = words6.get(key, [])
        check([w["text"] for w in words] == [w[0] for w in d4], f"{key}: 단어 {[w['text'] for w in words]} / 문서 4번 {[w[0] for w in d4]}")
        check([w["text"] for w in words] == [w[0] for w in d6], f"{key}: 단어 / 문서 6번 {[w[0] for w in d6]}")
        used = set()
        row = []
        for i, w in enumerate(words):
            text = w["text"]
            check(text not in seen_words, f"{key}: {text}가 {seen_words.get(text)}에도 있음")
            seen_words[text] = key
            check("".join(u["kana"] for u in w["units"]) == text, f"{key} {text}: 칸을 이은 것이 표기와 다름")
            check(all(u.get("romaji") for u in w["units"]), f"{key} {text}: 발음이 빈 칸")
            kana_units = [u for u in w["units"] if not u.get("kanji")]
            for u in w["units"]:
                if u.get("kanji"):
                    check(u["kana"] not in BASIC, f"{key} {text}: 한자 칸에 가나 {u['kana']}")
                else:
                    check(len(u["kana"]) == 1 and "ぁ" <= u["kana"] <= "ゖ", f"{key} {text}: 히라가나가 아닌 칸 {u['kana']} (한자 표시 누락?)")
            used |= {u["kana"] for u in kana_units}
            unread = sum(1 for u in kana_units if u["kana"] not in known)
            unread_base = sum(1 for u in kana_units if base_kana(u["kana"]) not in known)
            row.append(f"{text} {unread}/{unread_base}")
            totals["words"] += 1
            totals["readable"] += unread == 0
            totals["readable_base"] += unread_base == 0
            if i < len(d4):
                _, reading, meaning, a4, b4 = d4[i]
                check(w["reading"] == reading, f"{key} {text}: 읽기 {w['reading']} / 문서 {reading}")
                check(w["meaning"] == meaning, f"{key} {text}: 뜻 {w['meaning']} / 문서 {meaning}")
                check((unread, unread_base) == (a4, b4), f"{key} {text}: 계산 {unread}/{unread_base} / 문서 4번 {a4}/{b4}")
            if i < len(d6):
                _, a6, b6 = d6[i]
                check((unread, unread_base) == (a6, b6), f"{key} {text}: 계산 {unread}/{unread_base} / 문서 6번 {a6}/{b6}")
        not_used = [k for k in st["kana"] if k not in used]
        check(not not_used, f"{key}: 자기 단계 단어에 안 나오는 새 글자 {not_used}")
        report_rows.append(f"  {key} {scene['name']} {st['name']}: 새 글자 {' '.join(st['kana'])} ({len(st['kana'])}자, 누적 {len(known)}자) | " + ", ".join(row))

    # 8. 쓰기 포인트 문구
    for ch in ("か", "た"):
        check(ch in doc_tips, f"문서 10.3에서 {ch} 문구를 읽지 못함")
        check(tips_json.get(ch) == doc_tips.get(ch), f"hiragana_tips.json {ch}: {tips_json.get(ch)!r} / 문서 {doc_tips.get(ch)!r}")

    print("단계별 결과 (단어 옆 숫자 = 못 읽는 글자 수 / 탁음을 기본 글자로 볼 때)")
    print("\n".join(report_rows))
    print(f"장면별 글자 수: {', '.join(str(sum(len(st['kana']) for st in s['steps'])) for s in scenes)} (합계 {len(assigned)})")
    print(f"단계별 글자 수: {', '.join(str(len(st['kana'])) for _, _, st in json_steps)}")
    print(f"단어 {totals['words']}개, 전부 읽히는 단어 {totals['readable']}개 (탁음을 기본 글자로 보면 {totals['readable_base']}개)")
    print(f"46자 배정: 누락 {len(missing)}, 중복 {len(dup)}, 46자 밖 {len(outside)}")

    if errors:
        print(f"\n어긋남 {len(errors)}건:")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("\n통과: 문서와 어긋나는 곳 없음")
    return 0


if __name__ == "__main__":
    sys.exit(main())
