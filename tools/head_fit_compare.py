#!/usr/bin/env python3
"""머리 아이템 전/후 비교 시트 (docs/design/item-art/head-fit.md 5번 "비교 시트").

  .venv/bin/python tools/head_fit_compare.py --before 이전_에셋_폴더 [--out 시트.png] [id ...]
  .venv/bin/python tools/head_fit_compare.py --zoom --out /tmp/x.png chikuwa   # 머리 부분 크게 /tmp/zoom-chikuwa.png (확인용)

아이템마다 한 줄: 이전 배치(기본 표정 260) | 새 배치 기본 260 | 새 배치 웃음 260 | 새 배치 96·80 | 썸네일.
- 새 배치는 place_item_art.py의 build()로 지금 items.json·source/ 그림에서 만든다(에셋을 쓰지 않는다).
- 이전 배치는 --before 폴더의 `Item-{id}.imageset` (PNG 또는 기본 모자 SVG). 없으면 앱의 임시 표시(노랑 동그라미)를 그린다.
- 기리 본체·얼굴·반짝임은 docs/design/character/layers/의 SVG를 그린다.
결과 기본값: docs/design/item-art/head-fit-compare.png
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import place_item_art as pia  # noqa: E402

ROOT = pia.ROOT
LAYERS = ROOT / "docs" / "design" / "character" / "layers"
OUT = pia.ART / "head-fit-compare.png"
PAGE = (255, 249, 238)          # 꾸미기 화면 바탕에 가까운 크림
INK = (74, 34, 25)
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
HIGHLIGHT = (246, 185, 43)


def svg_layer(path: Path) -> Image.Image:
    """레이어 SVG 파일을 SIDE 크기 RGBA로 (자홍 바탕으로 알파를 만든다)."""
    text = path.read_text()
    head, rest = text.split(">", 1)
    return pia.magenta_layer(pia.render_svg(head + '><rect x="-30" y="0" width="360" height="360" fill="#FF00FF"/>' + rest))


def giri(item_layer: Image.Image | None, happy: bool) -> Image.Image:
    kind = "happy" if happy else "default"
    out = Image.new("RGBA", (pia.SIDE, pia.SIDE), PAGE + (255,))
    out.alpha_composite(svg_layer(LAYERS / f"giri-base-{kind}.svg"))
    if item_layer is not None:
        out.alpha_composite(item_layer)
    out.alpha_composite(svg_layer(LAYERS / f"giri-face-{kind}.svg"))
    if happy:
        out.alpha_composite(svg_layer(LAYERS / "giri-sparkles.svg"))
    return out


def placeholder(label: str) -> Image.Image:
    """앱의 임시 표시 (GiriView.placeholderMark): 머리 (150, 80)에 지름 0.22 × 기리 크기의 노랑 동그라미."""
    layer = Image.new("RGBA", (pia.SIDE, pia.SIDE))
    d = ImageDraw.Draw(layer)
    r = 0.22 * pia.SIDE / 2
    cx, cy = pia.gx(150), pia.px(80)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=HIGHLIGHT + (255,), outline=INK + (255,), width=round(r / 12))
    if label:
        glyph = pia.kana_glyph(label, round(r), "#4A2219", 11 / 109)
        layer.alpha_composite(glyph, (round(cx - r / 2), round(cy - r / 2)))
    return layer


def before_layer(folder: Path | None, iid: str, label: str) -> Image.Image:
    if folder:
        imageset = folder / f"Item-{iid}.imageset"
        pngs = sorted(imageset.glob("*.png"))
        svgs = sorted(imageset.glob("*.svg"))
        if pngs:
            return Image.open(pngs[0]).convert("RGBA").resize((pia.SIDE, pia.SIDE), Image.LANCZOS)
        if svgs:
            return svg_layer(svgs[0])
    return placeholder(label)


def head_crop(img: Image.Image) -> Image.Image:
    """머리 부분 (360 좌표 x 40~260, y 0~220)."""
    return img.crop((pia.gx(40), 0, pia.gx(260), pia.px(220)))


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("ids", nargs="*")
    p.add_argument("--before", type=Path)
    p.add_argument("--out", type=Path, default=OUT)
    p.add_argument("--zoom", action="store_true", help="머리 부분만 크게 (확인용)")
    a = p.parse_args()

    items = {i["id"]: i for i in json.loads((pia.ART / "items.json").read_text())["items"]}
    heads = [i for i in items.values() if i["slot"] == "top"]
    ids = a.ids or [i["id"] for i in heads]

    if a.zoom:
        for iid in ids:
            res = pia.build(items[iid])
            img = head_crop(giri(res[iid], False)).resize((660, 660), Image.LANCZOS)
            path = a.out.with_name(f"zoom-{iid}.png")
            img.convert("RGB").save(path)
            print(path)
        return 0

    font = ImageFont.truetype(FONT, 22)
    small = ImageFont.truetype(FONT, 16)
    big, mid, tiny, thumb = 260, 96, 80, 60
    cols = [("이전 (기본)", big), ("새 배치 (기본)", big), ("새 배치 (웃음)", big), ("96pt · 80pt", mid + tiny + 16),
            ("썸네일 60pt", thumb + 70)]
    pad, label_w, head_h = 16, 150, 40
    width = label_w + sum(w for _, w in cols) + pad * (len(cols) + 1)
    row_h = big + pad
    sheet = Image.new("RGB", (width, head_h + row_h * len(ids) + pad), PAGE)
    d = ImageDraw.Draw(sheet)
    x = label_w + pad
    for title, w in cols:
        d.text((x, 10), title, fill=INK, font=font)
        x += w + pad
    for row, iid in enumerate(ids):
        item = items[iid]
        y = head_h + row * row_h
        d.text((pad, y + 10), iid, fill=INK, font=font)
        d.text((pad, y + 40), item.get("fit", ""), fill=INK, font=small)
        d.text((pad, y + 60), item.get("nameKo", "")[:9], fill=INK, font=small)
        label = (item.get("kana") or "")[:1]
        if item.get("drawnBy") or (pia.SOURCE / f"{iid}.png").exists():
            res = pia.build(item)
            new, th = res[iid], res[f"{iid}-thumb"]
        else:
            # 아직 그림이 없다: 앱처럼 임시 표시를 그린다
            new = placeholder(label)
            th = pia.crop_view(new, pia.THUMB_VIEW["top"])
            d.text((pad, y + 80), "(그림 보류)", fill=INK, font=small)
        old = before_layer(a.before, iid, label)
        x = label_w + pad
        for img in (giri(old, False), giri(new, False), giri(new, True)):
            sheet.paste(img.convert("RGB").resize((big, big), Image.LANCZOS), (x, y))
            x += big + pad
        g = giri(new, False).convert("RGB")
        sheet.paste(g.resize((mid, mid), Image.LANCZOS), (x, y + big - mid))
        sheet.paste(g.resize((tiny, tiny), Image.LANCZOS), (x + mid + 16, y + big - tiny))
        x += mid + tiny + 16 + pad
        cell = Image.new("RGBA", (thumb, thumb), (255, 255, 255, 255))
        cell.alpha_composite(th.resize((thumb, thumb), Image.LANCZOS))
        sheet.paste(cell.convert("RGB"), (x, y + big - thumb))
        print(iid, flush=True)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(a.out, optimize=True)
    print(a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
