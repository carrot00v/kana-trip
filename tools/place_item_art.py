#!/usr/bin/env python3
"""고른 아이템 그림(docs/design/item-art/source/{id}.png)을 기리 위 자리에 맞춰 앱 에셋으로 만든다.

  .venv/bin/python tools/place_item_art.py            # source/에 있는 아이템 모두
  .venv/bin/python tools/place_item_art.py kippu yu   # 골라서

하는 일 (규격: docs/design/reward-flow.md 8번, docs/design/item-art/brief.md)
1. 플랫폼에 묶이지 않는 레이어를 build/item-art/에 만든다. 모두 기리 360 좌표계(viewBox -30 0 360 360)를
   SCALE배 한 정사각형 PNG라 기리 레이어와 겹치기만 하면 맞는다.
   - 모자·두건·배경: {id}.png
   - 손: {id}-default.png, {id}-happy.png (쥐는 점을 표정별 손끝에 놓음)
   - 썸네일: {id}-thumb.png (슬롯별 viewBox로 잘라 냄)
   배경은 items.json의 kanaBoxes 자리에 KanjiVG 획으로 가나를 합성한다(그림 속 가나는 모델이 그리지 않음).
2. iOS: KanaTrip/Assets.xcassets에 Item-{id}, Item-{id}-{default|happy}, ItemThumb-{id} 이미지 세트로 복사한다.
   안드로이드를 만들면 1의 결과를 res/drawable로 옮기는 단계만 더하면 된다.
3. 금지 색(초록 125~160°, 분홍빨강 330~359°)이 넓게 있으면 경고한다(reward-flow.md 8.3).

필요: Pillow (tools/requirements.txt)
"""
import colorsys
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "docs" / "design" / "item-art"
SOURCE = ART / "source"
NEUTRAL = ROOT / "build" / "item-art"
ASSETS = ROOT / "KanaTrip" / "Assets.xcassets"
STROKES = ROOT / "KanaTrip" / "Resources" / "hiragana_strokes.json"

SCALE = 3                 # 360 좌표계 1 = 3px → 레이어 1080px (K 미리보기 260pt @3x 보다 크다)
SIDE = 360 * SCALE
THUMB_PX = 240            # K 칸 60pt @3x = 180px보다 조금 크게

# 손 아이템: 아이템 자체 좌표(쥐는 점 0,0)에서 그려도 되는 상자와 표정별 손끝 (reward-flow.md 8.2)
HAND_BOX = (-40, -80, 40, 20)
HAND_ANCHOR = {"default": (278, 284), "happy": (290, 164)}

# 썸네일 viewBox (reward-flow.md 8.4). 손은 기본 표정 레이어에서 자르므로 아이템 좌표 -50 -80 100 100을 옮겨 둔다.
THUMB_VIEW = {
    "hat": (57, -16, 190, 190),
    "scarf": (-30, 104, 310, 310),
    "hand": (278 - 50, 284 - 80, 100, 100),
    "background": (-30, 0, 360, 360),
}

KANA_COLOR = (255, 253, 247, 255)   # 밥 흰색 #FFFDF7, 남색 노렌 위
KANA_WIDTH = 9 / 109                # 획 굵기 (KanjiVG 109 좌표 기준). 굵은 간판 글씨


def px(v: float) -> int:
    return round(v * SCALE)


def gx(x: float) -> int:
    """360 좌표계 x → 레이어 픽셀 (viewBox가 -30에서 시작)."""
    return px(x + 30)


def trim(img: Image.Image) -> Image.Image:
    """투명한 가장자리를 잘라 낸다."""
    box = img.getchannel("A").getbbox()
    return img.crop(box) if box else img


def fit(img: Image.Image, w: float, h: float) -> Image.Image:
    """비율을 지키며 w×h(픽셀) 안에 들어가게 줄인다."""
    s = min(w / img.width, h / img.height)
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)


def place(img: Image.Image, box: tuple, align: str) -> Image.Image:
    """360 좌표계 상자 [x1, y1, x2, y2] 안에 아이템을 놓은 레이어. align: center | bottom."""
    x1, y1, x2, y2 = box
    item = fit(trim(img), px(x2 - x1), px(y2 - y1))
    left = gx(x1) + (px(x2 - x1) - item.width) // 2
    top = px(y1) + (px(y2 - y1) - item.height if align == "bottom" else (px(y2 - y1) - item.height) // 2)
    layer = Image.new("RGBA", (SIDE, SIDE))
    layer.alpha_composite(item, (left, top))
    return layer


def crop_view(layer: Image.Image, view: tuple) -> Image.Image:
    """360 좌표계 viewBox (x, y, w, h)로 잘라 THUMB_PX 정사각형으로. 레이어 밖은 투명."""
    x, y, w, h = view
    out = Image.new("RGBA", (px(w), px(h)))
    out.alpha_composite(layer, (-gx(x), -px(y)))
    return out.resize((THUMB_PX, THUMB_PX), Image.LANCZOS)


def draw_kana(layer: Image.Image, boxes: list[dict]) -> None:
    data = {k["char"]: k["strokes"] for k in json.loads(STROKES.read_text())["kana"]}
    view = 109
    for spec in boxes:
        x1, y1, x2, y2 = spec["box"]
        size = px(x2 - x1)
        # 크게 그린 뒤 줄여서 가장자리를 부드럽게
        big = 4
        glyph = Image.new("RGBA", (size * big, size * big))
        d = ImageDraw.Draw(glyph)
        width = max(1, round(KANA_WIDTH * size * big))
        k = size * big / view
        for ch in spec["text"]:
            for stroke in data[ch]:
                pts = [(x * k, y * k) for x, y in stroke]
                d.line(pts, fill=KANA_COLOR, width=width, joint="curve")
                r = width / 2
                for cx, cy in (pts[0], pts[-1]):
                    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=KANA_COLOR)
        glyph = glyph.resize((size, size), Image.LANCZOS)
        layer.alpha_composite(glyph, (gx(x1), px(y1)))


def forbidden_ratio(img: Image.Image) -> tuple[float, float]:
    """불투명 픽셀 중 판정 색과 헷갈리는 색의 비율 (초록, 분홍빨강)."""
    small = img.convert("RGBA").resize((128, 128))
    green = pinkred = total = 0
    for r, g, b, a in small.get_flattened_data():
        if a < 128:
            continue
        total += 1
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        deg = h * 360
        if s >= 0.25 and v > 0.15:
            if 125 <= deg <= 160:
                green += 1
            elif deg >= 330:
                pinkred += 1
    return (green / total, pinkred / total) if total else (0, 0)


def write_imageset(name: str, img: Image.Image) -> None:
    folder = ASSETS / f"{name}.imageset"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    img.save(folder / f"{name}.png", optimize=True)
    contents = {
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def build(item: dict) -> dict[str, Image.Image]:
    """플랫폼에 묶이지 않는 결과: 파일 이름 → 그림."""
    src = Image.open(SOURCE / f"{item['id']}.png").convert("RGBA")
    slot, iid = item["slot"], item["id"]
    out = {}
    if slot == "background":
        side = min(src.size)
        sq = src.crop(((src.width - side) // 2, (src.height - side) // 2,
                       (src.width + side) // 2, (src.height + side) // 2))
        layer = sq.resize((SIDE, SIDE), Image.LANCZOS)
        draw_kana(layer, item.get("kanaBoxes", []))
        out[iid] = layer
        thumb_from = layer
    elif slot == "hand":
        for face, (ax, ay) in HAND_ANCHOR.items():
            bx1, by1, bx2, by2 = HAND_BOX
            out[f"{iid}-{face}"] = place(src, (ax + bx1, ay + by1, ax + bx2, ay + by2), "bottom")
        thumb_from = out[f"{iid}-default"]
    else:
        # 모자는 머리에 얹히게 아래를 맞추고, 두건은 띠 자리 가운데에 둔다
        layer = place(src, tuple(item["targetBox"]), "bottom" if slot == "hat" else "center")
        out[iid] = layer
        thumb_from = layer
    out[f"{iid}-thumb"] = crop_view(thumb_from, THUMB_VIEW[slot])
    return out


def ios_name(file: str) -> str:
    return f"ItemThumb-{file[:-6]}" if file.endswith("-thumb") else f"Item-{file}"


def main() -> int:
    items = {i["id"]: i for i in json.loads((ART / "items.json").read_text())["items"]}
    ids = sys.argv[1:] or sorted(p.stem for p in SOURCE.glob("*.png") if p.stem in items)
    missing = [i for i in ids if i not in items or not (SOURCE / f"{i}.png").exists()]
    if missing:
        print(f"source/에 그림이 없거나 items.json에 없는 id: {missing}", file=sys.stderr)
        return 2
    NEUTRAL.mkdir(parents=True, exist_ok=True)
    for iid in ids:
        item = items[iid]
        results = build(item)
        for file, img in results.items():
            img.save(NEUTRAL / f"{file}.png")
            write_imageset(ios_name(file), img)
        g, pr = forbidden_ratio(Image.open(SOURCE / f"{iid}.png"))
        warn = "  ← 금지 색 10% 넘음, 확인 필요" if max(g, pr) > 0.10 else ""
        print(f"{iid:10} {item['slot']:10} → {', '.join(ios_name(f) for f in results)}"
              f"  (초록 {g:.0%}, 분홍빨강 {pr:.0%}){warn}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
