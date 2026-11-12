#!/usr/bin/env python3
"""KanjiVG SVG를 앱에서 쓰는 획 좌표 JSON으로 변환한다.

사용법:
    python3 -I tools/build_kana_strokes.py <KanjiVG SVG 폴더> <출력 JSON>

SVG 폴더에는 KanjiVG 저장소의 kanji/0XXXX.svg 파일이 있어야 한다.
    https://github.com/KanjiVG/kanjivg  (CC BY-SA 3.0)

각 획은 109x109 좌표계의 점 목록으로 저장한다. 점 순서가 곧 쓰는 방향이다.
"""
import json
import re
import sys
from pathlib import Path

HIRAGANA = [
    ("あ", "a"), ("い", "i"), ("う", "u"), ("え", "e"), ("お", "o"),
    ("か", "ka"), ("き", "ki"), ("く", "ku"), ("け", "ke"), ("こ", "ko"),
    ("さ", "sa"), ("し", "shi"), ("す", "su"), ("せ", "se"), ("そ", "so"),
    ("た", "ta"), ("ち", "chi"), ("つ", "tsu"), ("て", "te"), ("と", "to"),
    ("な", "na"), ("に", "ni"), ("ぬ", "nu"), ("ね", "ne"), ("の", "no"),
    ("は", "ha"), ("ひ", "hi"), ("ふ", "fu"), ("へ", "he"), ("ほ", "ho"),
    ("ま", "ma"), ("み", "mi"), ("む", "mu"), ("め", "me"), ("も", "mo"),
    ("や", "ya"), ("ゆ", "yu"), ("よ", "yo"),
    ("ら", "ra"), ("り", "ri"), ("る", "ru"), ("れ", "re"), ("ろ", "ro"),
    ("わ", "wa"), ("を", "wo"), ("ん", "n"),
]

SAMPLES_PER_CURVE = 12
TOKEN = re.compile(r"([MmCcSsLlHhVvZz])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)")
PATH_D = re.compile(r'<path[^>]*\sd="([^"]+)"')
ARGS = {"M": 2, "L": 2, "C": 6, "S": 4, "H": 1, "V": 1, "Z": 0}


def cubic(p0, p1, p2, p3):
    pts = []
    for i in range(1, SAMPLES_PER_CURVE + 1):
        t = i / SAMPLES_PER_CURVE
        u = 1 - t
        pts.append(tuple(
            u * u * u * p0[k] + 3 * u * u * t * p1[k] + 3 * u * t * t * p2[k] + t * t * t * p3[k]
            for k in (0, 1)
        ))
    return pts


def path_to_points(d):
    tokens = [(m.group(1), m.group(2)) for m in TOKEN.finditer(d)]
    pts = []
    cur = (0.0, 0.0)
    last_ctrl = None
    cmd = None
    i = 0
    while i < len(tokens):
        if tokens[i][0]:
            cmd = tokens[i][0]
            i += 1
            if cmd in "Zz":
                continue
        if cmd is None:
            raise ValueError("명령 없이 숫자가 나옴: " + d)
        n = ARGS[cmd.upper()]
        vals = [float(tokens[i + k][1]) for k in range(n)]
        i += n
        rel = cmd.islower()
        ox, oy = cur if rel else (0.0, 0.0)
        kind = cmd.upper()
        if kind == "M":
            cur = (ox + vals[0], oy + vals[1])
            pts.append(cur)
            last_ctrl = None
            cmd = "l" if rel else "L"  # M 뒤에 이어지는 좌표는 선으로 본다
        elif kind == "L":
            cur = (ox + vals[0], oy + vals[1])
            pts.append(cur)
            last_ctrl = None
        elif kind == "H":
            cur = (ox + vals[0], cur[1])
            pts.append(cur)
            last_ctrl = None
        elif kind == "V":
            cur = (cur[0], oy + vals[0])
            pts.append(cur)
            last_ctrl = None
        elif kind in "CS":
            if kind == "C":
                c1 = (ox + vals[0], oy + vals[1])
                rest = vals[2:]
            else:
                c1 = (2 * cur[0] - last_ctrl[0], 2 * cur[1] - last_ctrl[1]) if last_ctrl else cur
                rest = vals
            c2 = (ox + rest[0], oy + rest[1])
            end = (ox + rest[2], oy + rest[3])
            pts.extend(cubic(cur, c1, c2, end))
            cur = end
            last_ctrl = c2
    return [[round(x, 2), round(y, 2)] for x, y in pts]


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    svg_dir, out_path = Path(sys.argv[1]), Path(sys.argv[2])
    kana = []
    for char, romaji in HIRAGANA:
        svg = (svg_dir / ("%05x.svg" % ord(char))).read_text(encoding="utf-8")
        strokes = [path_to_points(d) for d in PATH_D.findall(svg)]
        if not strokes:
            sys.exit("획을 찾지 못함: " + char)
        kana.append({"char": char, "romaji": romaji, "strokes": strokes})
    out = {
        "source": "KanjiVG (https://kanjivg.tagaini.net), CC BY-SA 3.0",
        "viewBox": 109,
        "kana": kana,
    }
    out_path.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("%d자, 획 %d개 -> %s" % (len(kana), sum(len(k["strokes"]) for k in kana), out_path))


if __name__ == "__main__":
    main()
