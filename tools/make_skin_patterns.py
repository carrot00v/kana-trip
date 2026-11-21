#!/usr/bin/env python3
"""앱 스킨 무늬 타일 4장 (docs/design/app-skin.md 6.3, 6.4).

반복 기하 무늬라 이미지 모델 대신 스크립트로 그린다(이슈 #7의 4, CLAUDE.md "그림 생성"의 예외).
타일 하나의 3×3 이웃 영역을 목표 해상도의 8배로 그린 뒤 박스 필터로 1/8 축소하고 가운데 타일을 잘라 내
이음매가 생기지 않게 한다. 출력은 색 없는 알파 마스크(흰 선, 투명 바탕)이고 앱이 PatternInk로 칠한다.

    .venv/bin/python tools/make_skin_patterns.py              # 에셋과 미리보기를 쓴다
    .venv/bin/python tools/make_skin_patterns.py --check      # 저장소의 PNG가 스크립트 출력과 같은지
    .venv/bin/python tools/make_skin_patterns.py --android DIR  # DIR/drawable-xhdpi, drawable-xxhdpi에도
"""

import argparse
import io
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "KanaTrip" / "Assets.xcassets"
SKINS = ROOT / "KanaTrip" / "Resources" / "skins.json"
PREVIEW = ROOT / "docs" / "design" / "skins" / "patterns-preview.png"

SUPERSAMPLE = 8
SCALES = (2, 3)
ANDROID = {2: "drawable-xhdpi", 3: "drawable-xxhdpi"}


class Pen:
    """pt 좌표로 그리는 펜. 원점은 가운데 타일의 왼쪽 위, 3×3 이웃이 다 들어가게 타일 하나만큼 민다."""

    def __init__(self, draw, tile_w, tile_h, px_per_pt):
        self.draw = draw
        self.ox, self.oy = tile_w, tile_h
        self.k = px_per_pt

    def p(self, x, y):
        return ((x + self.ox) * self.k, (y + self.oy) * self.k)

    def dot(self, x, y, r, fill=255):
        cx, cy = self.p(x, y)
        rr = r * self.k
        self.draw.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=fill)

    def polyline(self, points, width):
        """끝과 이음이 둥근 선."""
        w = width * self.k
        pts = [self.p(x, y) for x, y in points]
        self.draw.line(pts, fill=255, width=max(1, round(w)), joint="curve")
        for x, y in points:
            cx, cy = self.p(x, y)
            self.draw.ellipse((cx - w / 2, cy - w / 2, cx + w / 2, cy + w / 2), fill=255)

    def ring(self, x, y, r, width):
        cx, cy = self.p(x, y)
        ro, ri = (r + width / 2) * self.k, (r - width / 2) * self.k
        self.draw.ellipse((cx - ro, cy - ro, cx + ro, cy + ro), fill=255)
        self.draw.ellipse((cx - ri, cy - ri, cx + ri, cy + ri), fill=0)


def seigaiha(pen):
    """청해파 40×20. 위 줄부터 원판을 지우고 동심원 4겹을 그려 아래 줄이 위 줄의 아래 반을 가린다."""
    centers = []
    for j in range(-3, 5):
        for i in range(-3, 5):
            centers.append((40 * i, 20 * j))
            centers.append((40 * i + 20, 20 * j + 10))
    for x, y in sorted(centers, key=lambda c: (c[1], c[0])):
        pen.dot(x, y, 20, fill=0)
        for r in (19, 14, 9, 4):
            # 동심원은 이웃 원판에 가려지기 전에 한 겹씩 그린다(원판 안쪽만 칠함).
            pen.ring(x, y, r, 1.5)


def tenji(pen):
    """점자 블록 16×16. 지름 4pt 점, 중심 (8, 8)."""
    for j in range(-1, 2):
        for i in range(-1, 2):
            pen.dot(16 * i + 8, 16 * j + 8, 2)


def asanoha(pen):
    """삼잎 30×52. 한 변 30의 정삼각형 격자(세로 한 주기 30√3을 52로 0.08% 늘림)와 꼭짓점→무게중심 선."""
    side, row = 30.0, 26.0
    width = 1.25

    def vertex(i, j):
        return (side * i + (side / 2) * (j % 2), row * j)

    for j in range(-3, 6):
        for i in range(-3, 6):
            a = vertex(i, j)
            # 가로 변
            pen.polyline([a, (a[0] + side, a[1])], width)
            # 아래 줄로 가는 두 변
            pen.polyline([a, (a[0] - side / 2, a[1] + row)], width)
            pen.polyline([a, (a[0] + side / 2, a[1] + row)], width)
            # 이 줄과 아래 줄 사이의 두 삼각형(밑변이 위 / 아래)
            tris = [
                (a, (a[0] + side, a[1]), (a[0] + side / 2, a[1] + row)),
                ((a[0] + side / 2, a[1] + row), (a[0] - side / 2, a[1] + row), a),
            ]
            for tri in tris:
                cx = sum(p[0] for p in tri) / 3
                cy = sum(p[1] for p in tri) / 3
                for p in tri:
                    pen.polyline([p, (cx, cy)], width)


def tatewaku(pen):
    """다테와쿠 28×56. xL(y) = 14 − (6 + 4cos(2πy/56)), xR(y) = 14 + (6 + 4cos(2πy/56))."""
    steps = 224
    for i in range(-1, 2):
        for side in (-1, 1):
            pts = []
            for n in range(steps * 3 + 1):
                y = -56 + 168 * n / (steps * 3)
                x = 14 + side * (6 + 4 * math.cos(2 * math.pi * y / 56))
                pts.append((28 * i + x, y))
            pen.polyline(pts, 1.5)


# 이름, 스킨, 타일 크기(pt), 그리는 함수 (6.3)
PATTERNS = [
    ("seigaiha", "noren", (40, 20), seigaiha),
    ("tenji", "eki", (16, 16), tenji),
    ("asanoha", "torii", (30, 52), asanoha),
    ("tatewaku", "yu", (28, 56), tatewaku),
]


def render(draw_fn, tile, scale):
    """알파 마스크 타일 하나(흰 선, 투명 바탕)를 RGBA로."""
    tw, th = tile
    k = scale * SUPERSAMPLE
    big = Image.new("L", (3 * tw * k, 3 * th * k), 0)
    draw_fn(Pen(ImageDraw.Draw(big), tw, th, k))
    small = big.resize((3 * tw * scale, 3 * th * scale), Image.Resampling.BOX)
    alpha = small.crop((tw * scale, th * scale, 2 * tw * scale, 2 * th * scale))
    out = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def png_bytes(image):
    buf = io.BytesIO()
    image.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def contents_json(name):
    return {
        "images": [
            {"filename": f"skin-pattern-{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"skin-pattern-{name}@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "template"},
    }


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def preview(tiles):
    """무늬 4개 × (라이트, 다크) × (강 불투명도, 3배 진하게)를 375×200pt 칸(@2x)에 깐 한 장."""
    skins = {s["id"]: s for s in json.loads(SKINS.read_text(encoding="utf-8"))["skins"]}
    cell_w, cell_h, gap = 750, 400, 8
    cols = [("light", 1), ("light", 3), ("dark", 1), ("dark", 3)]
    sheet = Image.new("RGB", (len(cols) * (cell_w + gap) + gap, len(PATTERNS) * (cell_h + gap) + gap), (128, 128, 128))
    for r, (name, skin_id, _, _) in enumerate(PATTERNS):
        skin = skins[skin_id]
        tile = tiles[(name, 2)]
        for c, (mode, boost) in enumerate(cols):
            bg = hex_rgb(skin["colors"]["AppBackground"][mode])
            ink = hex_rgb(skin["colors"]["PatternInk"][mode])
            opacity = min(1.0, skin["patternOpacity"][mode] * boost)
            cell = Image.new("RGB", (cell_w, cell_h), bg)
            mask = Image.new("L", (cell_w, cell_h), 0)
            for y in range(0, cell_h, tile.height):
                for x in range(0, cell_w, tile.width):
                    mask.paste(tile.getchannel("A"), (x, y))
            mask = mask.point(lambda a: round(a * opacity))
            cell.paste(Image.new("RGB", (cell_w, cell_h), ink), (0, 0), mask)
            sheet.paste(cell, (gap + c * (cell_w + gap), gap + r * (cell_h + gap)))
    return sheet


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="저장소의 PNG가 스크립트 출력과 같은지 비교")
    parser.add_argument("--android", type=Path, help="drawable-xhdpi, drawable-xxhdpi를 쓸 폴더")
    args = parser.parse_args()

    tiles = {}
    for name, _, tile, fn in PATTERNS:
        for scale in SCALES:
            tiles[(name, scale)] = render(fn, tile, scale)

    if args.check:
        bad = []
        for (name, scale), image in tiles.items():
            path = ASSETS / f"skin-pattern-{name}.imageset" / f"skin-pattern-{name}@{scale}x.png"
            if not path.exists():
                bad.append(f"{path} 없음")
                continue
            saved = Image.open(path).convert("RGBA")
            if saved.size != image.size or saved.tobytes() != image.tobytes():
                bad.append(f"{path} 다름")
            contents = path.parent / "Contents.json"
            if not contents.exists() or json.loads(contents.read_text()) != contents_json(name):
                bad.append(f"{contents} 다름")
        for line in bad:
            print(line)
        print("무늬 타일 확인:", "실패" if bad else "같음")
        return 1 if bad else 0

    for (name, scale), image in tiles.items():
        folder = ASSETS / f"skin-pattern-{name}.imageset"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"skin-pattern-{name}@{scale}x.png").write_bytes(png_bytes(image))
        (folder / "Contents.json").write_text(json.dumps(contents_json(name), indent=2) + "\n")
        print(folder / f"skin-pattern-{name}@{scale}x.png", image.size)
        if args.android:
            out = args.android / ANDROID[scale]
            out.mkdir(parents=True, exist_ok=True)
            (out / f"skin_pattern_{name}.png").write_bytes(png_bytes(image))

    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview(tiles).save(PREVIEW, optimize=True)
    print(PREVIEW)
    return 0


if __name__ == "__main__":
    sys.exit(main())
