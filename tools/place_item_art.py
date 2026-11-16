#!/usr/bin/env python3
"""고른 아이템 그림(docs/design/item-art/source/{id}.png)을 기리 위 자리에 맞춰 앱 에셋으로 만든다.

  .venv/bin/python tools/place_item_art.py            # source/에 그림이 있는 items.json 아이템 모두
  .venv/bin/python tools/place_item_art.py omen yu    # 골라서
  .venv/bin/python tools/place_item_art.py --check omen   # 에셋을 쓰지 않고 검사만

하는 일 (규격: docs/design/item-art/brief.md 2·4번, docs/design/reward-flow.md 8번)
1. 플랫폼에 묶이지 않는 레이어를 build/item-art/에 만든다. 모두 기리 360 좌표계(viewBox -30 0 360 360)를
   SCALE배 한 정사각형 PNG라 기리 레이어와 겹치기만 하면 맞는다.
   - 머리(top): 닿는 점 맞추기. 그림의 닿는 점(anchor)을 contact(기본 P (150, 110))에 맞추고 box 안으로 줄여
     rotate만큼 돌린다 (brief.md 2.1.6).
   - 속재료(filling): 안쪽 끝 맞추기. 그림의 안쪽 끝을 E (54, 189)에서 몸 안쪽으로 depth만큼 들어간 자리에 맞추고
     긴 축을 length로 줄여 direction만큼 왼쪽 위로 돌린다 (brief.md 2.3.5, 2.3.6).
   - 배경(background): 360×360에 채우고 items.json의 kanaBoxes 자리에 KanjiVG 획으로 가나를 합성한다.
   - 썸네일: {id}-thumb.png (종류별 viewBox로 잘라 냄, brief.md 2.6)
   밥(rice)은 그림을 생성하지 않는다. tools/make_onigiri_svg.py가 본체 변형과 썸네일을 만든다.
2. iOS: KanaTrip/Assets.xcassets에 Item-{id}, ItemThumb-{id} 이미지 세트로 복사한다.
   안드로이드를 만들면 1의 결과를 res/drawable로 옮기는 단계만 더하면 된다.
3. 검사해 출력한다. 머리: 2.1.3 범위 밖 픽셀, 기본 모자 대비 면적, 채움 색 수(근사), 떨어진 조각 수, 금지 색.
   속재료: 2.3.2 범위 밖 픽셀, 보이는 면적(모자 대비), 보이는 비율(뒤), 빨강 계열이면 보이는 부분 아래 끝 y, 채움 색 수,
   떨어진 조각 수, 금지 색. 기준을 넘으면 줄 끝에 "← 확인"을 붙이고 종료 코드 1을 돌려준다(에셋은 쓴다).

필요: Pillow (tools/requirements.txt). 기본 모자 면적과 몸 마스크는 make_onigiri_svg.py의 그림을
tools/svg_to_png.swift(macOS AppKit)로 그려 센다.
"""
import colorsys
import json
import math
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_onigiri_svg as giri  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "docs" / "design" / "item-art"
SOURCE = ART / "source"
NEUTRAL = ROOT / "build" / "item-art"
ASSETS = ROOT / "KanaTrip" / "Assets.xcassets"
STROKES = ROOT / "KanaTrip" / "Resources" / "hiragana_strokes.json"

SCALE = 3                 # 360 좌표계 1 = 3px → 레이어 1080px (K 미리보기 260pt @3x 보다 크다)
SIDE = 360 * SCALE
THUMB_PX = 240            # K 칸 60pt @3x = 180px보다 조금 크게

# 썸네일 viewBox (brief.md 2.6, reward-flow.md 8.4)
THUMB_VIEW = {
    "top": (57, -16, 190, 190),
    "filling": (-33, 127, 124, 124),
    "background": (-30, 0, 360, 360),
}

# 머리 (brief.md 2.1)
TOP_CONTACT = (150, 110)                       # 기준점 P
TOP_RANGE = (64, 10, 236, 144)                 # 그려도 되는 범위
TOP_SIDE_RANGES = [(64, 10, 96, 158), (204, 10, 236, 158)]   # 옆에 거는 부분
TOP_BOX = {"hat": (160, 120), "topping": (136, 72)}           # 크기 상한
TOP_AREA = {"hat": 1.10, "topping": 0.70}                     # 기본 모자 대비 면적 상한
TOP_COLORS = 3

# 속재료 (brief.md 2.3)
FILLING_E = (54, 189)                          # 기준점 E
FILLING_RANGE = (-26, 152, 90, 218)
FILLING_CORNER = (60, 164)                     # x 60 오른쪽은 y 164 아래만
FILLING_FRONT_MAX_X = 72
FILLING_BOX = (100, 64)
FILLING_AREA = 0.35
FILLING_VISIBLE = 0.60
FILLING_RED_BOTTOM = 206
FILLING_COLORS = 2

KANA_COLOR = "#FFFDF7"              # 밥 흰색, 남색 노렌 위. 밝은 간판은 kanaBoxes의 "color"로 바꾼다
KANA_WIDTH = 9 / 109                # 획 굵기 (KanjiVG 109 좌표 기준). 굵은 간판 글씨
# 탁점 두 획(109 좌표, 위에서 아래로). 앱 획 데이터(hiragana_strokes.json)는 기본 46자뿐이라 탁음은 바탕 글자에 더해 그린다.
DAKUTEN = [[[84.0, 9.0], [89.0, 21.0]], [[95.0, 5.0], [100.0, 17.0]]]
DAKUTEN_BASE_SCALE = 0.86


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


def place_at(item: Image.Image, anchor: tuple[float, float], target: tuple[float, float], rotate: float) -> Image.Image:
    """잘라 낸 그림 item의 점 anchor(픽셀)를 360 좌표계 점 target에 맞추고, 그 점을 축으로 rotate도(SVG 부호,
    음수면 반시계 = 오른쪽이 올라감) 돌린 레이어."""
    layer = Image.new("RGBA", (SIDE, SIDE))
    tx, ty = gx(target[0]), px(target[1])
    layer.alpha_composite(item, (round(tx - anchor[0]), round(ty - anchor[1])))
    if rotate:
        # PIL은 양수가 반시계, SVG rotate는 양수가 시계 방향이다.
        layer = layer.rotate(-rotate, resample=Image.BICUBIC, center=(tx, ty))
    return layer


def anchor_px(item: Image.Image, spec: list | None, default: tuple[float, float]) -> tuple[float, float]:
    fx, fy = spec or default
    return fx * item.width, fy * item.height


def place_top(src: Image.Image, item: dict) -> Image.Image:
    kind = item.get("kind", "hat")
    w, h = item.get("box", TOP_BOX[kind])
    img = fit(trim(src), px(w), px(h))
    anchor = anchor_px(img, item.get("anchor"), (0.5, 1.0))
    return place_at(img, anchor, tuple(item.get("contact", TOP_CONTACT)), item.get("rotate", 0))


def place_filling(src: Image.Image, item: dict) -> Image.Image:
    img = trim(src)
    s = px(item["length"]) / img.width
    img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
    anchor = anchor_px(img, item.get("anchor"), (1.0, 0.5))
    d = math.radians(item["direction"])
    inner = (FILLING_E[0] + item["depth"] * math.cos(d), FILLING_E[1] + item["depth"] * math.sin(d))
    # 그림의 긴 축은 안쪽 끝(오른쪽)에서 왼쪽으로 나간다. 왼쪽 위로 direction도 = 시계 방향(SVG 양수).
    return place_at(img, anchor, inner, item["direction"])


def crop_view(layer: Image.Image, view: tuple) -> Image.Image:
    """360 좌표계 viewBox (x, y, w, h)로 잘라 THUMB_PX 정사각형으로. 레이어 밖은 투명."""
    x, y, w, h = view
    out = Image.new("RGBA", (px(w), px(h)))
    out.alpha_composite(layer, (-gx(x), -px(y)))
    return out.resize((THUMB_PX, THUMB_PX), Image.LANCZOS)


def glyph_strokes(ch: str, data: dict) -> list[list[list[float]]]:
    """한 글자의 획(109 좌표). 탁음(で, ぐ, ず…)은 획 데이터에 없으므로 바탕 글자(て, く, す)에 DAKUTEN을 더한다.
    바탕 글자는 DAKUTEN_BASE_SCALE만큼 왼쪽 아래로 줄여 오른쪽 위에 점 자리를 낸다(인쇄 글꼴의 탁음과 같은 자리)."""
    if ch in data:
        return data[ch]
    base, *marks = unicodedata.normalize("NFD", ch)
    if marks != ["゙"] or base not in data:
        raise KeyError(f"획 데이터에 없는 글자: {ch}")
    s, ox, oy = DAKUTEN_BASE_SCALE, 4.0, 109 * (1 - DAKUTEN_BASE_SCALE) - 2.0
    shrunk = [[[x * s + ox, y * s + oy] for x, y in stroke] for stroke in data[base]]
    return shrunk + DAKUTEN


def kana_glyph(text: str, size: int, color: str = KANA_COLOR, width: float = KANA_WIDTH) -> Image.Image:
    """KanjiVG 획(109 좌표)으로 그린 가나 한 칸(size×size 투명 PNG). 단어 그림(place_word_art.py)도 쓴다.
    text가 여러 글자면 한 칸에 겹쳐 그린다(한 줄로 늘어놓는 일은 부르는 쪽이 한다)."""
    data = {k["char"]: k["strokes"] for k in json.loads(STROKES.read_text())["kana"]}
    data = {ch: glyph_strokes(ch, data) for ch in text}
    view = 109
    fill = ImageColor.getcolor(color, "RGBA")
    # 크게 그린 뒤 줄여서 가장자리를 부드럽게
    big = 4
    glyph = Image.new("RGBA", (size * big, size * big))
    d = ImageDraw.Draw(glyph)
    line = max(1, round(width * size * big))
    k = size * big / view
    for ch in text:
        for stroke in data[ch]:
            pts = [(x * k, y * k) for x, y in stroke]
            d.line(pts, fill=fill, width=line, joint="curve")
            r = line / 2
            # 끝점뿐 아니라 꺾이는 점마다 원을 찍어 선 이음매의 갈라짐(밝은 실금)을 막는다
            for cx, cy in pts:
                d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)
    return glyph.resize((size, size), Image.LANCZOS)


def draw_kana(layer: Image.Image, boxes: list[dict]) -> None:
    for spec in boxes:
        x1, y1, x2, y2 = spec["box"]
        glyph = kana_glyph(spec["text"], px(x2 - x1), spec.get("color", KANA_COLOR))
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
        if s >= 0.25 and v > 0.35:  # 외곽선 근처의 어두운 갈색·자주는 넓은 면이 아니다
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
    if slot == "background":
        side = min(src.size)
        sq = src.crop(((src.width - side) // 2, (src.height - side) // 2,
                       (src.width + side) // 2, (src.height + side) // 2))
        layer = sq.resize((SIDE, SIDE), Image.LANCZOS)
        draw_kana(layer, item.get("kanaBoxes", []))
    elif slot == "top":
        layer = place_top(src, item)
    elif slot == "filling":
        layer = place_filling(src, item)
    else:
        raise ValueError(f"{iid}: 그림을 놓을 수 없는 종류 {slot} (밥은 make_onigiri_svg.py)")
    return {iid: layer, f"{iid}-thumb": crop_view(layer, THUMB_VIEW[slot])}


# ---- 검사 ----

def render_svg(content: str) -> Image.Image:
    """make_onigiri_svg.py의 SVG를 레이어 크기(SIDE)로 그린다. 투명을 못 내는 변환기라 자홍 바탕에 그려 마스크를 만든다."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        exe = converter()
        src, out = tmp / "in.svg", tmp / "out.png"
        src.write_text(content, encoding="utf-8")
        subprocess.run([str(exe), str(src), str(out), str(SIDE)], check=True)
        return Image.open(out).convert("RGB")


@lru_cache(maxsize=1)
def converter() -> Path:
    exe = Path(tempfile.gettempdir()) / "kanatrip_svg_to_png"
    if not exe.exists():
        subprocess.run(["swiftc", "-O", str(ROOT / "tools" / "svg_to_png.swift"), "-o", str(exe)], check=True)
    return exe


def magenta_mask(img: Image.Image) -> Image.Image:
    """자홍 바탕(#FF00FF)이 아닌 곳을 불투명(255)으로 본 마스크."""
    out = Image.new("L", img.size)
    out.putdata([0 if (r > 230 and g < 40 and b > 230) else 255 for r, g, b in img.get_flattened_data()])
    return out


@lru_cache(maxsize=1)
def chef_hat_area() -> int:
    """기본 요리사 모자 실루엣의 불투명 픽셀 수 (brief.md 2.1.4의 기준값)."""
    content = giri.wrap('<rect x="-30" y="0" width="360" height="360" fill="#FF00FF"/>' + giri.hat())
    return sum(1 for v in magenta_mask(render_svg(content)).get_flattened_data() if v)


@lru_cache(maxsize=1)
def body_mask() -> Image.Image:
    """몸(외곽선 포함) 마스크. 속재료 뒤 레이어의 보이는 부분을 잴 때 쓴다."""
    body = giri.body_path()
    content = giri.wrap(f'<rect x="-30" y="0" width="360" height="360" fill="#FF00FF"/>'
                        f'<path d="{body}" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="{giri.SW}"/>')
    return magenta_mask(render_svg(content))


def alpha_mask(layer: Image.Image) -> Image.Image:
    return layer.getchannel("A").point(lambda a: 255 if a >= 128 else 0)


def count(mask: Image.Image) -> int:
    return sum(1 for v in mask.get_flattened_data() if v)


def outside(mask: Image.Image, allowed: list[tuple]) -> int:
    """allowed 상자(360 좌표계) 어디에도 들지 않는 불투명 픽셀 수."""
    keep = Image.new("L", mask.size, 0)
    d = ImageDraw.Draw(keep)
    for x1, y1, x2, y2 in allowed:
        d.rectangle((gx(x1), px(y1), gx(x2) - 1, px(y2) - 1), fill=255)
    inv = Image.eval(keep, lambda v: 255 - v)
    return count(Image.composite(mask, Image.new("L", mask.size, 0), inv))


def pieces(mask: Image.Image, min_px: int = 30) -> int:
    """이어진 덩어리 수 (작은 점은 세지 않음). 1/4로 줄여 센다."""
    small = mask.resize((mask.width // 4, mask.height // 4), Image.NEAREST)
    w, h = small.size
    data = list(small.get_flattened_data())
    seen = bytearray(w * h)
    n = 0
    for start in range(w * h):
        if not data[start] or seen[start]:
            continue
        stack, size = [start], 0
        seen[start] = 1
        while stack:
            i = stack.pop()
            size += 1
            x, y = i % w, i // w
            for j in (i - 1 if x else -1, i + 1 if x < w - 1 else -1, i - w if y else -1, i + w if y < h - 1 else -1):
                if j >= 0 and data[j] and not seen[j]:
                    seen[j] = 1
                    stack.append(j)
        if size * 16 >= min_px:
            n += 1
    return n


def fill_colors(layer: Image.Image, mask: Image.Image | None = None) -> tuple[int, str]:
    """채움 색 수 근사: 외곽선(어두운 갈색)을 빼고, 비슷한 색(RGB 거리 64 이내)을 한 무리로 묶어
    불투명 픽셀의 4% 넘는 무리를 센다. 옅은 결 선·가장자리 섞임은 4%에 못 미쳐 빠진다."""
    small = layer.resize((360, 360), Image.LANCZOS)
    m = (mask or alpha_mask(layer)).resize((360, 360), Image.NEAREST)
    # 외곽선과 그 둘레(섞인 색)는 채움 색이 아니다. 외곽선 마스크를 넓혀서 뺀다.
    dark = Image.new("L", small.size)
    dark.putdata([255 if a >= 128 and max(r, g, b) < 110 else 0 for r, g, b, a in small.get_flattened_data()])
    near_line = dark.filter(ImageFilter.MaxFilter(5))
    groups: list[list] = []          # [대표 r, g, b, 개수]
    total = 0
    for (r, g, b, a), keep, line in zip(small.get_flattened_data(), m.get_flattened_data(),
                                        near_line.get_flattened_data()):
        if a < 200 or not keep:
            continue
        total += 1
        if line:
            continue
        for grp in groups:
            if (grp[0] - r) ** 2 + (grp[1] - g) ** 2 + (grp[2] - b) ** 2 <= 64 ** 2:
                grp[3] += 1
                break
        else:
            groups.append([r, g, b, 1])
    big = sorted((grp for grp in groups if total and grp[3] / total >= 0.04), key=lambda grp: -grp[3])
    desc = " ".join(f"#{r:02X}{g:02X}{b:02X}:{n / total:.0%}" for r, g, b, n in big)
    return len(big), desc


def main_hue(layer: Image.Image, mask: Image.Image) -> float | None:
    """보이는 부분에서 가장 넓은 채도 있는 색의 색상(도)."""
    small = layer.resize((180, 180), Image.LANCZOS)
    m = mask.resize((180, 180), Image.NEAREST)
    hues: dict[int, int] = {}
    for (r, g, b, a), keep in zip(small.get_flattened_data(), m.get_flattened_data()):
        if a < 200 or not keep:
            continue
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if s >= 0.35 and v > 0.4:
            hues[int(h * 36) * 10] = hues.get(int(h * 36) * 10, 0) + 1
    return max(hues, key=hues.get) if hues else None


def check_top(item: dict, layer: Image.Image) -> list[tuple[str, bool]]:
    kind = item.get("kind", "hat")
    mask = alpha_mask(layer)
    bbox = mask.getbbox()
    out = outside(mask, [TOP_RANGE] + TOP_SIDE_RANGES)
    area = count(mask) / chef_hat_area()
    colors, desc = fill_colors(layer)
    n = pieces(mask)
    w, h = item.get("box", TOP_BOX[kind])
    limit_w, limit_h = TOP_BOX[kind]
    box_text = (f"{(bbox[2] - bbox[0]) / SCALE:.0f}×{(bbox[3] - bbox[1]) / SCALE:.0f} "
                f"x {bbox[0] / SCALE - 30:.0f}~{bbox[2] / SCALE - 30:.0f} y {bbox[1] / SCALE:.0f}~{bbox[3] / SCALE:.0f}")
    return [
        (f"자리 {box_text}", True),
        (f"범위 밖 {out}px", out == 0),
        (f"상자 {w}×{h} (상한 {limit_w}×{limit_h})", w <= limit_w and h <= limit_h),
        (f"면적 모자의 {area:.0%} (상한 {TOP_AREA[kind]:.0%})", area <= TOP_AREA[kind]),
        (f"채움 색 {colors} [{desc}]", colors <= TOP_COLORS),
        (f"덩어리 {n}", n == 1),
    ]


def check_filling(item: dict, layer: Image.Image) -> list[tuple[str, bool]]:
    mask = alpha_mask(layer)
    back = item.get("layer", "back") == "back"
    visible = Image.composite(Image.new("L", mask.size, 0), mask, body_mask()) if back else mask
    allowed = [(FILLING_RANGE[0], FILLING_RANGE[1], FILLING_CORNER[0], FILLING_RANGE[3]),
               (FILLING_CORNER[0], FILLING_CORNER[1], FILLING_RANGE[2] if back else FILLING_FRONT_MAX_X,
                FILLING_RANGE[3])]
    out = outside(mask, allowed)
    total, shown = count(mask), count(visible)
    area = shown / chef_hat_area()
    ratio = shown / total if total else 0
    vb = visible.getbbox()
    bottom = vb[3] / SCALE if vb else 0
    hue = main_hue(layer, visible)
    reddish = hue is not None and hue <= 20
    colors, desc = fill_colors(layer, visible)
    n = pieces(visible)
    bbox = mask.getbbox()
    result = [
        (f"자리 x {bbox[0] / SCALE - 30:.0f}~{bbox[2] / SCALE - 30:.0f} y {bbox[1] / SCALE:.0f}~{bbox[3] / SCALE:.0f}", True),
        (f"범위 밖 {out}px", out == 0),
        (f"상자 {(bbox[2] - bbox[0]) / SCALE:.0f}×{(bbox[3] - bbox[1]) / SCALE:.0f} (상한 100×64)",
         (bbox[2] - bbox[0]) / SCALE <= FILLING_BOX[0] and (bbox[3] - bbox[1]) / SCALE <= FILLING_BOX[1]),
        (f"보이는 면적 모자의 {area:.0%} (상한 35%)", area <= FILLING_AREA),
        (f"채움 색 {colors} [{desc}]", colors <= FILLING_COLORS),
        (f"덩어리 {n}", n == 1),
    ]
    if back:
        result.append((f"보이는 비율 {ratio:.0%} (60% 이상)", ratio >= FILLING_VISIBLE))
    if reddish:
        result.append((f"빨강 계열 보이는 아래 끝 y {bottom:.0f} (206 이하)", bottom <= FILLING_RED_BOTTOM))
    return result


def ios_name(file: str) -> str:
    return f"ItemThumb-{file[:-6]}" if file.endswith("-thumb") else f"Item-{file}"


def main() -> int:
    args = sys.argv[1:]
    check_only = "--check" in args
    args = [a for a in args if a != "--check"]
    items = {i["id"]: i for i in json.loads((ART / "items.json").read_text())["items"]}
    ids = args or sorted(i for i in items if (SOURCE / f"{i}.png").exists())
    missing = [i for i in ids if i not in items or not (SOURCE / f"{i}.png").exists()]
    if missing:
        print(f"source/에 그림이 없거나 items.json에 없는 id: {missing}", file=sys.stderr)
        return 2
    NEUTRAL.mkdir(parents=True, exist_ok=True)
    failed = False
    for iid in ids:
        item = items[iid]
        results = build(item)
        if not check_only:
            for file, img in results.items():
                img.save(NEUTRAL / f"{file}.png")
                write_imageset(ios_name(file), img)
        g, pr = forbidden_ratio(Image.open(SOURCE / f"{iid}.png"))
        checks = [(f"초록 {g:.0%}, 분홍빨강 {pr:.0%}", max(g, pr) <= 0.10)]
        if item["slot"] == "top":
            checks = check_top(item, results[iid]) + checks
        elif item["slot"] == "filling":
            checks = check_filling(item, results[iid]) + checks
        bad = [text for text, ok in checks if not ok]
        failed = failed or bool(bad)
        print(f"{iid:15} {item['slot']:10} " + ("검사만" if check_only else "→ " + ", ".join(ios_name(f) for f in results)))
        for text, ok in checks:
            print(f"    {text}" + ("" if ok else "  ← 확인"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
