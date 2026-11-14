#!/usr/bin/env python3
"""단어 그림 후보를 한 장에 모은 비교 시트를 만든다 (docs/design/word-art/brief.md 5번 검토용).

  .venv/bin/python tools/word_art_sheet.py --priority 1          # 우선순위 1 → source/contact-sheet.png
  .venv/bin/python tools/word_art_sheet.py --priority 2 --out docs/design/word-art/source/contact-sheet-p2.png

- 바탕을 지운 투명본(candidates/cut/)을 푸른 바둑판 위에 놓는다. 바탕 지우기에서 남은 회색 테나
  지워진 흰 면이 바둑판과 구분되어 보인다.
- 칸마다 이름, 가나, 시드를 적는다. 순서는 tools/word_art.json(word-images.md 3번) 순서.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "tools" / "word_art.json"
CUT = ROOT / "docs" / "design" / "word-art" / "source" / "candidates" / "cut"
DEFAULT_OUT = ROOT / "docs" / "design" / "word-art" / "source" / "contact-sheet.png"
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"

TILE = 300
LABEL = 58
COLS = 6
CHECK = 20
CHECK_COLORS = ((200, 212, 224), (150, 168, 186))


def checker(w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), CHECK_COLORS[0] + (255,))
    d = ImageDraw.Draw(img)
    for y in range(0, h, CHECK):
        for x in range(0, w, CHECK):
            if (x // CHECK + y // CHECK) % 2:
                d.rectangle((x, y, x + CHECK - 1, y + CHECK - 1), fill=CHECK_COLORS[1])
    return img


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--priority", type=int, help="이 우선순위만 (없으면 후보가 있는 단어 모두)")
    p.add_argument("--out", type=Path, default=DEFAULT_OUT)
    a = p.parse_args()

    words = json.loads(DATA.read_text())["words"]
    if a.priority:
        words = [w for w in words if w["priority"] == a.priority]
    tiles = []
    for w in words:
        for path in sorted(CUT.glob(f"word-{w['name']}_*.png")):
            tiles.append((w, path))
    if not tiles:
        print("후보가 없다")
        return 2

    rows = (len(tiles) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * TILE, rows * (TILE + LABEL)), (255, 253, 247, 255))
    font = ImageFont.truetype(FONT, 22)
    small = ImageFont.truetype(FONT, 15)
    d = ImageDraw.Draw(sheet)
    for n, (w, path) in enumerate(tiles):
        x, y = (n % COLS) * TILE, (n // COLS) * (TILE + LABEL)
        cell = checker(TILE - 8, TILE - 8)
        art = Image.open(path).convert("RGBA").resize((TILE - 8, TILE - 8), Image.LANCZOS)
        cell.alpha_composite(art)
        sheet.alpha_composite(cell, (x + 4, y + 4))
        seed = path.stem.rsplit("_", 1)[-1]
        d.text((x + 8, y + TILE), f"{w['name']}  {w['kana']}", font=font, fill=(74, 34, 25))
        d.text((x + 8, y + TILE + 30), f"seed {seed}", font=small, fill=(120, 100, 90))
    a.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(a.out, optimize=True)
    print(f"{len(tiles)}장 → {a.out.relative_to(ROOT) if a.out.is_relative_to(ROOT) else a.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
