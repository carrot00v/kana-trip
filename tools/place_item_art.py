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
   아이템의 `waive` {"reason": 사유, "checks": [검사 줄 머리말, ...]}에 든 검사는 넘어도 "← 면제: 사유"로 적고
   종료 코드에 넣지 않는다(사용자가 정한 아이템만. 다른 아이템과 다른 검사는 그대로 돈다).

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

from PIL import Image, ImageChops, ImageColor, ImageDraw, ImageFilter

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
TOP_BOX = {"hat": (160, 120), "topping": (160, 80)}           # 크기 상한 (토핑은 2026-11-17 2차 수정에서 136×72 → 160×80)
TOP_AREA = {"hat": 1.10, "topping": 0.80}                     # 기본 모자 대비 면적 상한 (토핑 70% → 80%)
TOPPING_TOP_Y = 30                                            # 토핑 위 끝 y 이상 (brief.md 2.1.4)
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
    """닿는 점(픽셀). spec [fx, fy]는 그림 안의 비율이고, fy가 "bottom"이면 fx 열의 가장 낮은 불투명 픽셀이다
    (띠처럼 아랫변 가운데가 그림 아래 끝이 아닐 때)."""
    fx, fy = spec or default
    if fy == "bottom":
        col = min(item.width - 1, max(0, round(fx * item.width)))
        alpha = item.getchannel("A").crop((col, 0, col + 1, item.height))
        ys = [y for y, v in enumerate(alpha.get_flattened_data()) if v >= 128]
        return fx * item.width, (ys[-1] + 1) if ys else item.height
    return fx * item.width, fy * item.height


# ---- 머리 맞춤 (docs/design/item-art/head-fit.md 1·5번) ----
# 머리 아이템은 맞춤 방식(fit) 다섯 가지 중 하나로 놓는다. 순서: 놓기 → 깎기(carve, drape) → 외곽선 다시 그리기 → 자르기
# (band. 기본 요리사 모자 swallow는 make_onigiri_svg.py의 SVG clipPath가 자른다). 결과는 앞 레이어 한 장이다.

HEAD_CENTER = (150, 182)       # 꼭대기 원호 중심
HEAD_R = 72                    # 원호 반지름 (외곽선 가운데)
HEAD_APEX_Y = 110              # 꼭짓점 y. 깊이는 모두 이 값에서 잰다
FACE_BAND = (96, 204, 144)     # x 96~204에서 y 144 아래 금지
LINE_RGB = (0x4A, 0x22, 0x19)
OUTLINE = 6                    # 다시 그리는 외곽선 굵기 = 본체 SW
FITS = ("swallow", "band", "carve", "drape", "overlay")

# 검사 기준 (head-fit.md 1.3, 5번)
GAP_MIN, GAP_MAX, GAP_RUN = 3, 11, 7          # 3~11 틈이 7열(행) 이상 이어지면 실패
DEPTH_RULES = {
    # D_c 범위, D_e 기준 설명은 check_head_fit에서
    "swallow": (26, 34),
    "band": (26, 34),
    "carve": (0, 6),
    "drape": (0, 6),
}
BAND_TOP = (8, 16)             # band 띠 윗변 깊이
CARVE_DE_SMALL, CARVE_DE_LARGE, CARVE_DE_SIDE = 10, 21, 4   # 폭 80 이하 / 초과 평균, 각 쪽 최소
DRAPE_DE = (20, 40)
CONTACT_MIN = {"carve": 0.60, "drape": 0.75, "carve_full": 0.75}
BAND_OVERSHOOT = 4
CARVED_MAX = 0.30
OUTLINE_RANGE = (3, 9)
INNER_THIN_MAX = 0.50
TILT_TOL, TILT_RANGE = 3, (-15, 0)
BAND_TILT = (-8, -4)
OVERLAY_TILT = (-25, -15)          # items.json `tiltRange`가 없을 때
OVERLAY_OVERLAP = (0.40, 0.60)     # items.json `overlapRange`(%)가 없을 때
PRESS_MAX = 30

# 검사 11: 접은 수건 (head-fit.md 3.5.1, (나)는 3.5.2 3차 수정). items.json에 `indigoRange`가 있는 아이템만 잰다.
TOWEL_CORNER_IN = 8                # 아래 두 모서리가 몸 외곽선 안쪽 가장자리에서 안쪽으로
TOWEL_STRIPES = (2, 3)             # 가로 남색 줄 개수
TOWEL_STRIPE_LEN = 0.70            # 줄 하나의 가로 길이 ÷ 안쪽 채움 폭
TOWEL_STRIPE_THICK = (4, 7)        # 줄 두께 (열마다 잰 세로 두께의 중앙값)
TOWEL_GAP_EDGE, TOWEL_GAP_BETWEEN = 3, 4   # 가운데 열의 위·아래 흰 틈, 줄 사이 흰 틈
INDIGO_HUE, INDIGO_VALUE = (200, 235), 0.55

# 가로 늘림 `squash` (head-fit.md 3.5.2): 가로 배율 ÷ 세로 배율. items.json `squashMax`로 차선(1.7)까지 넓힌다.
SQUASH_RANGE = (1.0, 1.5)

# 검사 12: 크기 하한 (head-fit.md 1.9.3). 맞춤 방식별 기본 종류, items.json `sizeClass`로 바꾼다.
BODY_WIDTH = 248                   # 몸 폭 (외곽선 가운데)
PT80 = 80 / 360                    # 가장 작은 기리(80pt)에서 360 좌표 1
SIZE_CLASS = {"swallow": "chef", "band": "band", "carve": "long", "drape": "long", "overlay": "mask"}
SIZE_MIN = {
    # w: 보이는 폭, h: 보이는 높이, thick: 가운데 열의 위아래 거리(띠 굵기·수건 두께), knot: 매듭 폭, area: 면적 비율
    "chef": {"area": 0.80},
    "band": {"w": 120, "thick": 20, "knot": 30, "knotMax": 38, "area": 0.28},   # 매듭 30~38 (3.2.2)
    "mask": {"w": 72, "h": 72, "area": 0.30},
    "towel": {"w": 88, "thick": 36, "area": 0.26},
    "long": {"w": 104, "h": 52, "area": 0.35},
    "round": {"w": 72, "h": 52, "area": 0.28},
}


def head_point(dx: float) -> tuple[float, float]:
    """꼭짓점에서 원호를 따라 dx만큼 비킨 닿는 점 P(dx) (head-fit.md 1.5)."""
    return HEAD_CENTER[0] + dx, HEAD_CENTER[1] - math.sqrt(HEAD_R ** 2 - dx ** 2)


def tangent_deg(dx: float) -> float:
    return math.degrees(math.asin(dx / HEAD_R))


def binarize(mask: Image.Image) -> Image.Image:
    return mask.point(lambda v: 255 if v >= 128 else 0)


def erode(mask: Image.Image, units: float) -> Image.Image:
    """원판(반지름 units, 360 좌표)으로 깎은 마스크. 가우스 흐림 뒤 문턱으로 근사한다: 곧은 가장자리에서 거리 d의 값이
    Φ(d/σ)이므로 σ = r/1.5, 문턱 Φ(1.5) ≈ 0.933이면 정확히 r만큼 깎인다. 네모 MinFilter와 달리 대각선에서도 굵기가 같다."""
    if units <= 0:
        return mask
    r = units * SCALE
    blur = mask.filter(ImageFilter.GaussianBlur(r / 1.5))
    return blur.point(lambda v: 255 if v >= 238 else 0)


def dilate(mask: Image.Image, units: float) -> Image.Image:
    if units <= 0:
        return mask
    r = units * SCALE
    blur = mask.filter(ImageFilter.GaussianBlur(r / 1.5))
    return blur.point(lambda v: 255 if v > 17 else 0)


def mask_and(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.multiply(a, b)


def mask_sub(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.subtract(a, b)


def unit_grid(mask: Image.Image) -> list[list[bool]]:
    """마스크를 360 좌표 1 단위 격자로 줄인다. grid[y][x + 30]."""
    small = mask.resize((360, 360), Image.BOX)
    data = list(small.get_flattened_data())
    return [[data[y * 360 + x] >= 128 for x in range(360)] for y in range(360)]


@lru_cache(maxsize=1)
def body_inner() -> Image.Image:
    """몸 외곽선 안쪽 가장자리 안 (본체 마스크를 OUTLINE만큼 깎음)."""
    return erode(body_mask(), OUTLINE)


@lru_cache(maxsize=1)
def body_ring() -> Image.Image:
    """본체 외곽선 고리 (바깥 가장자리 ~ 안쪽 가장자리)."""
    return mask_sub(body_mask(), body_inner())


@lru_cache(maxsize=1)
def body_grid() -> list[list[bool]]:
    return unit_grid(body_mask())


def body_top(x: int) -> int | None:
    """360 좌표 x 열에서 몸 마스크의 맨 위 y."""
    col = x + 30
    if not 0 <= col < 360:
        return None
    g = body_grid()
    return next((y for y in range(360) if g[y][col]), None)


def body_side(y: int, left: bool) -> int | None:
    row = body_grid()[y]
    xs = [x - 30 for x in range(360) if row[x]]
    return (xs[0] if left else xs[-1]) if xs else None


def polygon_mask(polys: list, size: tuple[int, int], to_px) -> Image.Image:
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    for poly in polys:
        d.polygon([to_px(p) for p in poly], fill=255)
    return m


def apply_erase(img: Image.Image, polys: list | None, retrim: bool = True) -> Image.Image:
    """그림 손질: 잘라 낸 그림 안의 비율 좌표 다각형을 지우고 다시 잘라 낸다 (head-fit.md 2.3 `erase`)."""
    if not polys:
        return img
    m = polygon_mask(polys, img.size, lambda p: (p[0] * img.width, p[1] * img.height))
    a = ImageChops.subtract(img.getchannel("A"), m)
    out = img.copy()
    out.putalpha(a)
    return trim(out) if retrim else out


def tail_trim_polygon(spec: dict, size: tuple[int, int]) -> list[tuple[float, float]]:
    """꼬리 반원 자르기 `tailTrim` 한 개 (head-fit.md 3.2.2 손질 1)를 지울 다각형(픽셀)으로.
    spec: {"center": [fx, fy] 남길 끝 반원의 가운데(그림 비율), "angle": 꼬리 끝이 향하는 방향(위 0°, 시계 방향 +),
    "radius": 반원 반지름(그림 폭 비율), "reach": 옆으로 지울 너비(반지름 배수, 기본 2)}.
    center를 지나 꼬리에 수직인 선 너머를 지우되 반지름 radius의 반원은 남긴다. 반원은 점 24개로 근사한다."""
    w, h = size
    cx, cy = spec["center"][0] * w, spec["center"][1] * h
    r = spec["radius"] * w
    a = math.radians(spec["angle"])
    out = (math.sin(a), -math.cos(a))             # 꼬리 끝 방향 (y 아래로 +)
    perp = (math.cos(a), math.sin(a))             # 오른쪽 옆
    reach, far = r * spec.get("reach", 2), max(w, h)

    def pt(u: float, v: float) -> tuple[float, float]:
        """u: 옆(perp) 거리, v: 끝 방향(out) 거리."""
        return cx + perp[0] * u + out[0] * v, cy + perp[1] * u + out[1] * v

    arc = [pt(r * math.cos(t), r * math.sin(t)) for t in (math.pi * (1 - i / 24) for i in range(25))]
    return [pt(-reach, 0), pt(-reach, far), pt(reach, far), pt(reach, 0)] + arc[::-1]


def tail_rotate(img: Image.Image, tail: Image.Image, pivot: tuple[float, float], deg: float
                ) -> tuple[Image.Image, Image.Image]:
    """꼬리 묶음 돌리기 `tailRotate` (head-fit.md 3.2.3.4): 두 꼬리를 함께 감싼 `tail` 다각형(마스크 tail) 안을 떼어
    축 pivot(픽셀)을 중심으로 deg도(SVG 부호, + 시계 방향) 돌린 뒤 나머지 그림 **밑에** 다시 붙인다(매듭이 이음매를 덮는다).
    한 가닥만 따로 돌리지 않는다(3차에서 두 꼬리가 엉켰다). 돌린 조각이 그림 밖으로 나가도 잘리지 않게 둘레를 넓혀
    돌리고, 부르는 쪽이 다시 잘라 낸다. (그림, 돌린 꼬리 마스크)를 돌려준다."""
    w, h = img.size
    pad = max(w, h) // 2
    big = Image.new("RGBA", (w + 2 * pad, h + 2 * pad))
    big.alpha_composite(img, (pad, pad))
    m = Image.new("L", big.size)
    m.paste(tail, (pad, pad))
    piece = big.copy()
    piece.putalpha(ImageChops.multiply(big.getchannel("A"), m))
    rest = big.copy()
    rest.putalpha(ImageChops.subtract(big.getchannel("A"), m))
    center = (pad + pivot[0], pad + pivot[1])
    piece = piece.rotate(-deg, resample=Image.BICUBIC, center=center)
    m = m.rotate(-deg, resample=Image.BICUBIC, center=center)
    big = Image.new("RGBA", big.size)
    big.alpha_composite(piece)
    big.alpha_composite(rest)
    return big, m


def band_extend(img: Image.Image, spec: dict) -> Image.Image:
    """띠 연장 `bandExtend` (head-fit.md 3.2.3.4): 곧은 띠 구간 segment [시작, 끝](그림 폭 비율)의 세로 띠를 repeat번
    그 자리에 이어 붙여 띠를 왼쪽으로 늘린다. 구간 길이를 꼰 무늬 한 주기의 정수배로 잡으면 이음매가 줄무늬 경계에 온다.
    같은 그림의 픽셀을 띠 축(가로) 방향으로 복사만 한다. 늘린 길이는 원래 띠 길이의 60% 이하(부르는 쪽 검사)."""
    x0, x1 = round(spec["segment"][0] * img.width), round(spec["segment"][1] * img.width)
    strip = img.crop((x0, 0, x1, img.height))
    n = spec.get("repeat", 1)
    out = Image.new("RGBA", (img.width + strip.width * n, img.height))
    out.paste(img.crop((0, 0, x1, img.height)), (0, 0))
    for i in range(n):
        out.paste(strip, (x1 + i * strip.width, 0))
    out.paste(img.crop((x1, 0, img.width, img.height)), (x1 + n * strip.width, 0))
    return out


def indigo_mean(img: Image.Image) -> tuple[float, float] | None:
    """남색 픽셀(검사 11 (나)의 정의: 색상 200°~235°, 명도 0.55 이하, 채도 0.2 이상)의 평균 (색상 도, 명도)."""
    hs, vs = [], []
    for r, g, b, a in img.resize((img.width // 4 or 1, img.height // 4 or 1)).get_flattened_data():
        if a < 200:
            continue
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if INDIGO_HUE[0] <= h * 360 <= INDIGO_HUE[1] and v <= INDIGO_VALUE and s >= 0.2:
            hs.append(h * 360)
            vs.append(v)
    return (sum(hs) / len(hs), sum(vs) / len(vs)) if hs else None


def compose(spec: dict) -> tuple[Image.Image, tuple[float, float]]:
    """두 그림 합성 `compose` (head-fit.md 3.2.3.4 합성 규칙, S3): 띠 그림(원래 매듭·꼬리를 `bandErase`로 지움) 위에
    매듭 그림(`knotErase`로 줄기를 매듭 가장자리 바깥 4까지만 남김)을 `knotScale`배(띠 그림 픽셀 기준)로 줄이고
    `knotRotate`도(SVG 부호) 돌려, 매듭 그림 가운데를 띠 그림의 `knotAt`(비율)에 놓는다. 픽셀을 옮기기만 한다.
    경로는 source/ 기준. (합친 그림, (남색 색상 차, 명도 차))를 돌려준다."""
    band = apply_erase(trim(Image.open(SOURCE / spec["band"]).convert("RGBA")), spec.get("bandErase"), retrim=False)
    knot = apply_erase(trim(Image.open(SOURCE / spec["knot"]).convert("RGBA")), spec.get("knotErase"))
    s = spec.get("knotScale", 1.0)
    knot = knot.resize((max(1, round(knot.width * s)), max(1, round(knot.height * s))), Image.LANCZOS)
    if spec.get("knotRotate"):
        knot = trim(knot.rotate(-spec["knotRotate"], resample=Image.BICUBIC, expand=True))
    cx, cy = spec["knotAt"][0] * band.width, spec["knotAt"][1] * band.height
    ox, oy = round(cx - knot.width / 2), round(cy - knot.height / 2)
    x0, y0 = min(0, ox), min(0, oy)
    out = Image.new("RGBA", (max(band.width, ox + knot.width) - x0, max(band.height, oy + knot.height) - y0))
    out.alpha_composite(band, (-x0, -y0))
    out.alpha_composite(knot, (ox - x0, oy - y0))
    ib, ik = indigo_mean(band), indigo_mean(knot)
    diff = (abs(ib[0] - ik[0]), abs(ib[1] - ik[1])) if ib and ik else (math.inf, math.inf)
    return trim(out), diff


def prepare_source(src: Image.Image, item: dict) -> Image.Image:
    """손질 앞 단계 (head-fit.md 3.2.3.4 순서): 뒤집기(`flip` "h"/"v") → 그림 돌리기(`sourceRotate`) → (S3) 합성 → 띠 연장.
    `compose`가 있으면 src 대신 합성한 그림을 쓴다(뒤집기·돌리기는 하지 않는다)."""
    if item.get("compose"):
        src = compose(item["compose"])[0]
        if item.get("bandExtend"):
            src = band_extend(src, item["bandExtend"])
        return trim(src)
    flip = item.get("flip")
    if flip == "h":
        src = src.transpose(Image.FLIP_LEFT_RIGHT)
    elif flip == "v":
        src = src.transpose(Image.FLIP_TOP_BOTTOM)
    src = trim(level(src, item))
    if item.get("bandExtend"):
        src = band_extend(src, item["bandExtend"])
    return trim(src)


def retouch(img: Image.Image, item: dict) -> tuple[Image.Image, Image.Image | None]:
    """그림 손질 순서 (head-fit.md 3.2.3.4): erase → 꼬리 반원 자르기 → 꼬리 묶음 돌리기 → 다시 잘라 내기.
    손질의 비율 좌표(`erase`, `tailTrim`, `tail`, `tailRotate.pivot`)는 모두 손질 전 그림(prepare_source 결과) 기준이다.
    (그림, 꼬리 마스크)를 돌려준다. 꼬리 마스크는 `tail` 다각형(없으면 None)이고 그림과 같은 크기로 따라간다."""
    img = apply_erase(img, item.get("erase"), retrim=False)
    if item.get("tailTrim"):
        polys = [tail_trim_polygon(s, img.size) for s in item["tailTrim"]]
        img = apply_erase(img, [[(x / img.width, y / img.height) for x, y in p] for p in polys], retrim=False)
    tail = None
    if item.get("tail"):
        tail = polygon_mask(item["tail"], img.size, lambda p: (p[0] * img.width, p[1] * img.height))
    rot = item.get("tailRotate")
    if rot and tail is not None:
        pivot = (rot["pivot"][0] * img.width, rot["pivot"][1] * img.height)
        img, tail = tail_rotate(img, tail, pivot, rot["angle"])
    box = img.getchannel("A").getbbox()
    if box:
        img = img.crop(box)
        tail = tail.crop(box) if tail is not None else None
    return img, tail


def shift_down(layer: Image.Image, units: float) -> Image.Image:
    if not units:
        return layer
    out = Image.new("RGBA", layer.size)
    out.alpha_composite(layer, (0, round(units * SCALE)))
    return out


def lowest_per_column(mask: Image.Image) -> dict[int, int]:
    """360 좌표 x → 그 열의 가장 낮은 불투명 y."""
    g = unit_grid(mask)
    out = {}
    for col in range(360):
        ys = [y for y in range(360) if g[y][col]]
        if ys:
            out[col - 30] = ys[-1]
    return out


def press_amount(layer: Image.Image, item: dict, need: float) -> int:
    """눌러 놓기 (head-fit.md 1.4.3의 2): 아이템 폭 가운데 contactSpan의 아랫변이 모두 몸 안쪽으로 need 이상
    들어갈 때까지 내리는 양 (0~PRESS_MAX)."""
    mask = alpha_mask(layer)
    bbox = mask.getbbox()
    x0, x1 = bbox[0] / SCALE - 30, bbox[2] / SCALE - 30
    span = item.get("contactSpan", 0.8)
    cx, half = (x0 + x1) / 2, (x1 - x0) * span / 2
    low = lowest_per_column(mask)
    p = 0
    for x in range(math.ceil(cx - half), math.floor(cx + half) + 1):
        yb = body_top(x)
        if yb is None or x not in low:
            continue
        p = max(p, math.ceil(need - (low[x] - yb)))
    return max(0, min(PRESS_MAX, p))


def redraw_outline(layer: Image.Image) -> Image.Image:
    """바깥 외곽선 다시 그리기 (head-fit.md 1.6): 실루엣 안쪽 OUTLINE 폭 고리를 #4A2219로 칠한다. 실루엣은 넓어지지 않는다."""
    a = alpha_mask(layer)
    ring = mask_sub(a, erode(a, OUTLINE)).filter(ImageFilter.GaussianBlur(1))
    line = Image.new("RGBA", layer.size, LINE_RGB + (0,))
    line.putalpha(layer.getchannel("A"))
    return Image.composite(line, layer, ring)


def grow_inner_lines(layer: Image.Image, units: float) -> Image.Image:
    """안쪽 진한 선을 양쪽으로 units씩 굵게 칠한다 (items.json `innerGrow`). 작은 아이템(가면 52 폭)은 모델이 그린 선이
    줄이면 1.5 안팎이 되어 검사 7(굵기 3)을 다시 그리기로는 넘을 수 없어서 넣는 단계에서 굵힌다. 외곽선 고리 안쪽에서만 칠한다."""
    a = alpha_mask(layer)
    inside = erode(a, OUTLINE)
    dark = Image.new("L", layer.size)
    dark.putdata([255 if a_ >= 128 and max(r, g, b) < 130 else 0 for r, g, b, a_ in layer.get_flattened_data()])
    grown = mask_and(dilate(mask_and(dark, inside), units), inside).filter(ImageFilter.GaussianBlur(1))
    line = Image.new("RGBA", layer.size, LINE_RGB + (0,))
    line.putalpha(layer.getchannel("A"))
    return Image.composite(line, layer, grown)


def outline_thickness(layer: Image.Image) -> float | None:
    """원래 외곽선 굵기 근사 (5번 검사 6): 가장자리 안쪽 10 안의 어두운 픽셀 면적 ÷ 가장자리 길이."""
    a = alpha_mask(layer)
    edge = mask_sub(a, a.filter(ImageFilter.MinFilter(3)))
    length = count(edge) / SCALE
    if not length:
        return None
    band = mask_sub(a, erode(a, 10))
    dark = Image.new("L", layer.size)
    dark.putdata([255 if a_ >= 128 and max(r, g, b) < 110 else 0 for r, g, b, a_ in layer.get_flattened_data()])
    return count(mask_and(band, dark)) / SCALE ** 2 / length


def inner_line_thin(layer: Image.Image) -> tuple[float, int] | None:
    """안쪽 무늬 선 굵기 (5번 검사 7): 외곽선 고리 안쪽의 진한 선 픽셀 중 굵기 3 미만이라 1.5 깎으면 사라지는 비율.
    깎은 뒤 다시 1.5 늘려(열기) 남지 않는 픽셀을 센다. 깎기만 하면 굵기 4.5 선도 픽셀의 67%가 줄어 실패로 나온다."""
    a = alpha_mask(layer)
    inside = erode(a, OUTLINE + 1)
    dark = Image.new("L", layer.size)
    dark.putdata([255 if a_ >= 128 and max(r, g, b) < 130 else 0 for r, g, b, a_ in layer.get_flattened_data()])
    lines = mask_and(inside, dark)
    n = count(lines)
    if n < 20 * SCALE ** 2:
        return None
    # 열기(1.5 깎고 1.5 늘림)로 남지 않는 선 = 굵기 3 미만인 선
    kept = count(mask_and(dilate(erode(lines, 1.5), 1.5), lines))
    return 1 - kept / n, round(n / SCALE ** 2)


def place_head(src: Image.Image, item: dict) -> tuple[Image.Image, dict]:
    """머리 아이템을 맞춤 방식대로 놓는다. (레이어, 검사용 정보)."""
    kind = item.get("kind", "hat")
    how = item.get("fit")
    w, h = item.get("box", TOP_BOX[kind])
    img, tail = retouch(prepare_source(src, item), item)
    info: dict = {"fit": how}
    if item.get("compose"):
        info["composeIndigo"] = compose(item["compose"])[1]
    if item.get("squash"):
        # 가로 늘림 (head-fit.md 3.5.2 정식 손질): 비율을 지키지 않고 상자에 맞춘다. 가로 배율 ÷ 세로 배율을 검사한다.
        info["squash"] = (px(w) / img.width) / (px(h) / img.height)
        img = img.resize((px(w), px(h)), Image.LANCZOS)
    else:
        img = fit(img, px(w), px(h))
    if tail is not None:
        tail = tail.resize(img.size, Image.BILINEAR)
    rotate = item.get("rotate", 0)
    if how == "overlay":
        anchor = anchor_px(img, item.get("anchor"), (0.5, 0.5))
        target = tuple(item["center"])
    elif how == "band":
        anchor = anchor_px(img, item.get("anchor"), (0.5, 1.0))
        target = tuple(item["bandTarget"])
    elif how in ("carve", "drape"):
        anchor = anchor_px(img, item.get("anchor"), (0.5, 1.0))
        target = head_point(item.get("dx", 0))
    else:
        raise ValueError(f"{item['id']}: 그림으로 놓을 수 없는 맞춤 방식 {how}")
    info["contact_x"] = target[0]
    layer = place_at(img, anchor, target, rotate)
    if tail is not None:
        # 꼬리 마스크도 같은 자리에 놓는다 (검사 12의 매듭 폭, 검사 13). 그림의 불투명 픽셀과 겹친 곳만 꼬리로 친다.
        t = Image.new("RGBA", img.size, (0, 0, 0, 0))
        t.putalpha(tail)
        info["tail"] = mask_and(alpha_mask(place_at(t, anchor, target, rotate)), alpha_mask(layer))
    info["outline_before"] = outline_thickness(layer)

    if how in ("carve", "drape"):
        inset = item.get("carveInset", 0)
        press = item.get("press", "auto")
        p = press_amount(layer, item, OUTLINE + inset) if press == "auto" else press
        layer = shift_down(layer, p)
        info["press"] = p
        before = alpha_mask(layer)
        info["height_before"] = (lambda b: (b[3] - b[1]) / SCALE)(before.getbbox())
        cut = erode(body_mask(), OUTLINE + inset)
        a = ImageChops.subtract(layer.getchannel("A"), cut)
        layer.putalpha(a)
        removed = mask_and(before, cut)
        low = unit_grid(removed)
        info["carved"] = max((sum(1 for y in range(360) if low[y][c]) for c in range(360)), default=0)

    layer = redraw_outline(layer)
    if item.get("innerGrow"):
        layer = grow_inner_lines(layer, item["innerGrow"])

    if how == "band":
        pre = alpha_mask(layer)
        exempt = polygon_mask(item.get("clipExempt", []), layer.size, lambda p: (gx(p[0]), px(p[1])))
        keep = ImageChops.lighter(body_inner(), exempt).filter(ImageFilter.GaussianBlur(1))
        layer.putalpha(ImageChops.multiply(layer.getchannel("A"), keep))
        info["overshoot"] = band_overshoot(pre, alpha_mask(layer), target[0])
    return layer, info


def band_overshoot(pre: Image.Image, post: Image.Image, contact_x: float) -> tuple[float, float]:
    """자르기 전 띠가 몸 외곽선 바깥 가장자리 밖으로 나간 길이 (왼쪽, 오른쪽) (5번 검사 4). 자르기로 지워진 픽셀이
    그쪽에 있고 자른 뒤 띠가 몸 안쪽 가장자리 가까이(25 이내) 남아 있는 행마다 (몸 옆 끝 x − 자르기 전 아이템의 바깥 끝 x)를 재고
    가장 작은 값을 쓴다. 띠 위·아래 가장자리 2행씩은 뺀다(둥근 모서리)."""
    removed = unit_grid(mask_sub(pre, post))
    kept = unit_grid(post)
    whole = unit_grid(pre)
    result = []
    for left in (True, False):
        vals = []
        for y in range(360):
            side = (lambda x: x - 30 < contact_x) if left else (lambda x: x - 30 > contact_x)
            if not any(removed[y][x] and side(x) for x in range(360)):
                continue
            bx = body_side(y, left)
            if bx is None:
                continue
            inner = range(bx + 6, bx + 31) if left else range(bx - 30, bx - 5)
            if not any(0 <= x + 30 < 360 and kept[y][x + 30] for x in inner):
                continue
            # 그 행에서 자르기 전 아이템의 바깥 끝 (자르지 않는 매듭도 포함)
            xs = [x - 30 for x in range(360) if whole[y][x] and side(x)]
            vals.append((bx - min(xs)) if left else (max(xs) - bx))
        vals = vals[2:-2] if len(vals) > 6 else vals
        result.append(min(vals, default=float("nan")))
    return result[0], result[1]


def runs(values: list, lo: float, hi: float) -> int:
    """lo~hi 값이 연속으로 이어진 가장 긴 길이."""
    best = cur = 0
    for v in values:
        cur = cur + 1 if v is not None and lo <= v <= hi else 0
        best = max(best, cur)
    return best


def gap_profiles(mask: Image.Image) -> tuple[list, list]:
    """(세로 틈 열 목록, 가로 틈 행 목록) (5번 검사 1·2). 겹치면 0, 아이템이 없으면 None."""
    g = unit_grid(mask)
    vertical = []
    for col in range(360):
        x = col - 30
        yb = body_top(x)
        ys = [y for y in range(360) if g[y][col]]
        if yb is None or not ys:
            vertical.append(None)
        elif any(y >= yb for y in ys):
            vertical.append(0)
        else:
            above = [y for y in ys if y < yb]
            vertical.append(yb - above[-1] - 1 if above else None)
    horizontal = []
    for y in range(10, 159):
        for left in (True, False):
            bx = body_side(y, left)
            if bx is None or (left and bx > 96) or (not left and bx < 204):
                continue
            row = g[y]
            if left:
                near = [x - 30 for x in range(max(0, 64 + 30), bx + 30 + 3) if row[x]]
                out = [x for x in near if x < bx]
                horizontal.append(0 if any(x >= bx for x in near) else (bx - out[-1] - 1 if out else None))
            else:
                near = [x - 30 for x in range(bx - 3 + 30, min(360, 236 + 30)) if row[x]]
                out = [x for x in near if x > bx]
                horizontal.append(0 if any(x <= bx for x in near) else (out[0] - bx - 1 if out else None))
    return vertical, horizontal


def check_head_fit(item: dict, layer: Image.Image, info: dict) -> list[tuple[str, bool]]:
    """head-fit.md 5번 검사 1~12 (11은 `indigoRange`가 있는 접은 수건만)."""
    how = info["fit"]
    mask = alpha_mask(layer)
    g = unit_grid(mask)
    body = body_grid()
    ring = unit_grid(body_ring())
    out: list[tuple[str, bool]] = []

    vertical, horizontal = gap_profiles(mask)
    rv, rh = runs(vertical, GAP_MIN, GAP_MAX), runs(horizontal, GAP_MIN, GAP_MAX)
    out.append((f"틈 세로 3~11 연속 {rv}열, 가로 {rh}행 (7 미만)", rv < GAP_RUN and rh < GAP_RUN))

    xc = round(info["contact_x"])
    col = xc + 30
    in_body = [y for y in range(360) if g[y][col] and body[y][col]]
    if how != "overlay":
        dc = (in_body[-1] - HEAD_APEX_Y) if in_body else None
        lo, hi = DEPTH_RULES[how]
        if how in ("carve", "drape"):
            hi += item.get("carveInset", 0)
        text = f"겹침 D_c {dc} ({lo}~{hi}, x {xc})"
        ok = dc is not None and lo <= dc <= hi
        if how == "band":
            top = [y for y in range(360) if g[y][col]]
            bt = (top[0] - HEAD_APEX_Y) if top else None
            text += f", 띠 윗변 {bt} ({BAND_TOP[0]}~{BAND_TOP[1]})"
            ok = ok and bt is not None and BAND_TOP[0] <= bt <= BAND_TOP[1]
        out.append((text, ok))

        # D_e: 몸 외곽선 중 아이템에 덮이거나 닿은(1 이내) 것의 가장 낮은 y
        near = unit_grid(dilate(mask, 1))
        de = []
        for left in (True, False):
            cols = range(0, col) if left else range(col + 1, 360)
            ys = [y for c in cols for y in range(360) if ring[y][c] and near[y][c]]
            de.append(max(ys) - HEAD_APEX_Y if ys else None)
        dl, dr = de
        bbox = mask.getbbox()
        width = (bbox[2] - bbox[0]) / SCALE
        if how in ("swallow", "band"):
            ok = dl is not None and dr is not None and (how == "band" or min(dl, dr) >= 15)
            out.append((f"D_e {dl}·{dr} (" + ("양쪽 15 이상" if how == "swallow" else "양 끝이 외곽선에 닿음") + ")", ok))
        elif how == "drape":
            ok = dl is not None and dr is not None and all(DRAPE_DE[0] <= v <= DRAPE_DE[1] for v in de)
            out.append((f"D_e {dl}·{dr} (각 {DRAPE_DE[0]}~{DRAPE_DE[1]})", ok))
        elif item.get("deRange"):
            # 접은 수건처럼 양쪽 범위를 따로 정한 아이템 (head-fit.md 1.3의 tenugui 12~24)
            lo_, hi_ = item["deRange"]
            ok = dl is not None and dr is not None and all(lo_ <= v <= hi_ for v in de)
            out.append((f"D_e {dl}·{dr} (각 {lo_}~{hi_})", ok))
        else:
            need = CARVE_DE_SMALL if width <= 80 else CARVE_DE_LARGE
            avg = (dl + dr) / 2 if dl is not None and dr is not None else None
            ok = avg is not None and avg >= need and min(dl, dr) >= CARVE_DE_SIDE
            out.append((f"D_e {dl}·{dr} 평균 {avg} (폭 {width:.0f} → {need} 이상, 각 {CARVE_DE_SIDE} 이상)", ok))

        # 닿는 폭
        if how in ("carve", "drape"):
            cov = [c for c in range(360) if any(ring[y][c] and g[y][c] for y in range(360))]
            ratio = ((cov[-1] - cov[0] + 1) / width) if cov else 0
            full = how == "drape" or item.get("contactSpan", 0.8) >= 1.0 or bool(item.get("deRange"))
            need = CONTACT_MIN["carve_full" if how == "carve" and full else how]
            out.append((f"닿는 폭 {ratio:.0%} ({need:.0%} 이상)", ratio >= need))
        else:
            ol, orr = info.get("overshoot", (None, None))
            if ol is None:
                out.append(("띠 끝 (SVG 자르기, 따로 잼)", True))
            else:
                ok = ol >= BAND_OVERSHOOT and orr >= BAND_OVERSHOOT
                out.append((f"띠 끝 +{ol:.0f}·+{orr:.0f} ({BAND_OVERSHOOT} 이상)", ok))

    if "carved" in info:
        ratio = info["carved"] / info["height_before"]
        out.append((f"깎인 높이 {info['carved']} / {info['height_before']:.0f} = {ratio:.0%} (30% 이하), 눌러 놓기 {info['press']}",
                    ratio <= CARVED_MAX))

    ob = info.get("outline_before")
    if ob is not None:
        # 3 미만은 다시 그린 선(6)이 덮으므로 "다시 그림 후보" 표시만 한다. 9 넘는 선은 다시 그려도 남으므로 확인 (1.6의 4).
        note = "" if ob >= OUTLINE_RANGE[0] else ", 가늘어 다시 그린 선으로 바뀜: 다시 그림 후보"
        out.append((f"원래 외곽선 굵기 {ob:.1f} ({OUTLINE_RANGE[0]}~{OUTLINE_RANGE[1]}{note})", ob <= OUTLINE_RANGE[1]))
    thin = inner_line_thin(layer)
    if thin is None:
        out.append(("안쪽 무늬 선 없음", True))
    else:
        out.append((f"안쪽 진한 선 {thin[1]}: 굵기 3 미만 {thin[0]:.0%} (50% 이하)", thin[0] <= INNER_THIN_MAX))

    rot = item.get("rotate", 0)
    if how == "band":
        out.append((f"기울기 {rot}° ({BAND_TILT[0]}~{BAND_TILT[1]})", BAND_TILT[0] <= rot <= BAND_TILT[1]))
    elif how == "overlay":
        vis = item.get("visibleTilt", rot)
        t_lo, t_hi = item.get("tiltRange", OVERLAY_TILT)
        out.append((f"보이는 기울기 {vis}° (rotate {rot}°, {t_lo}~{t_hi})", t_lo <= vis <= t_hi))
    else:
        t = tangent_deg(item.get("dx", 0))
        diff = abs(rot - t)
        ok = diff <= TILT_TOL and TILT_RANGE[0] <= rot <= TILT_RANGE[1]
        out.append((f"접선 차 {diff:.1f}° (rotate {rot}°, 접선 {t:.1f}°)", ok))

    if how == "overlay":
        inside = sum(1 for y in range(360) for c in range(360) if g[y][c] and body[y][c])
        total = sum(1 for y in range(360) for c in range(360) if g[y][c])
        ratio = inside / total if total else 0
        o_lo, o_hi = (v / 100 for v in item["overlapRange"]) if item.get("overlapRange") else OVERLAY_OVERLAP
        out.append((f"머리와 겹침 {ratio:.1%} ({o_lo:.0%}~{o_hi:.0%})", o_lo <= ratio <= o_hi))
        if item.get("indigoRange"):
            # 접은 수건: 아랫변 가운데 깊이 D_c (1.3의 overlay tenugui 24~30)
            cx = round(info["contact_x"]) + 30
            ys = [y for y in range(360) if g[y][cx]]
            dc = ys[-1] - HEAD_APEX_Y if ys else None
            lo, hi = item.get("depthRange", (24, 30))
            out.append((f"아랫변 가운데 D_c {dc} ({lo}~{hi}, x {cx - 30})", dc is not None and lo <= dc <= hi))

    if "squash" in info:
        s_lo, s_hi = SQUASH_RANGE[0], item.get("squashMax", SQUASH_RANGE[1])
        out.append((f"가로 늘림 {info['squash']:.2f}배 ({s_lo}~{s_hi})", s_lo - 0.005 <= info["squash"] <= s_hi + 0.005))

    face = [y for y in range(360) for c in range(FACE_BAND[0] + 30, FACE_BAND[1] + 31) if g[y][c]]
    low = max(face) + 1 if face else 0
    out.append((f"얼굴 띠 가장 낮은 y {low} (144 이하)", low <= FACE_BAND[2]))
    if item.get("indigoRange"):
        out += check_towel(item, layer)
    out += check_size(item, layer, info)
    if item.get("tailRange"):
        out += check_tail(item, layer, info)
    return out


def check_towel(item: dict, layer: Image.Image) -> list[tuple[str, bool]]:
    """검사 11 (head-fit.md 5번, 3.5.1·3.5.2): 접은 수건의 아래 두 모서리와 가로 남색 줄."""
    mask = alpha_mask(layer)
    g = unit_grid(mask)
    inner = unit_grid(body_inner())
    pts = [(c - 30, y) for y in range(360) for c in range(360) if g[y][c]]
    out: list[tuple[str, bool]] = []
    # (가) 아래 모서리: 왼쪽 아래는 y − x, 오른쪽 아래는 y + x가 가장 큰 점 (둥근 모서리의 45° 자리).
    # 그 행에서 몸 외곽선 안쪽 가장자리(본체 마스크를 6 깎은 것)까지의 가로 거리. 양수면 안쪽.
    ins = []
    for left in (True, False):
        x, y = max(pts, key=(lambda p: p[1] - p[0]) if left else (lambda p: p[1] + p[0]))
        row = [c - 30 for c in range(360) if inner[y][c]]
        if not row:
            ins.append((None, x, y))
            continue
        ins.append(((x - row[0]) if left else (row[-1] - x), x, y))
    text = " · ".join(f"{'왼쪽' if i == 0 else '오른쪽'} ({x}, {y}) {d if d is not None else '머리 밖'}"
                      for i, (d, x, y) in enumerate(ins))
    ok = all(d is not None and d >= TOWEL_CORNER_IN for d, _, _ in ins)
    out.append((f"아래 모서리 안쪽 거리 {text} ({TOWEL_CORNER_IN} 이상)", ok))

    # (나) 남색 (3.5.2): 외곽선 고리 안쪽 채움 중 INDIGO 계열 비율, 가로 줄(덩어리)의 수·길이·두께, 가운데 열의 흰 틈
    fill = erode(mask, OUTLINE)
    indigo = Image.new("L", layer.size)
    data = []
    for (r, g_, b, a), f in zip(layer.get_flattened_data(), fill.get_flattened_data()):
        hit = 0
        if a >= 128 and f:
            h, s, v = colorsys.rgb_to_hsv(r / 255, g_ / 255, b / 255)
            hit = 255 if INDIGO_HUE[0] <= h * 360 <= INDIGO_HUE[1] and v <= INDIGO_VALUE and s >= 0.2 else 0
        data.append(hit)
    indigo.putdata(data)
    n_fill, n_ind = count(fill), count(indigo)
    ratio = n_ind / n_fill if n_fill else 0
    lo, hi = item["indigoRange"]
    out.append((f"남색 면적 {ratio:.0%} ({lo}~{hi}%)", lo / 100 <= ratio <= hi / 100))
    fill_g, ind_g = unit_grid(fill), unit_grid(indigo)
    fill_cols = [c for c in range(360) if any(fill_g[y][c] for y in range(360))]
    inner_w = (fill_cols[-1] - fill_cols[0] + 1) if fill_cols else 0
    # 줄: 작은 얼룩(외곽선 가장자리 섞임)은 빼고 센다. 위에서 아래 순서.
    blobs = sorted(components(ind_g, min_size=20), key=lambda b: sum(y for _, y in b) / len(b))
    lens, thicks = [], []
    for blob in blobs:
        cols: dict[int, int] = {}
        for x, _ in blob:
            cols[x] = cols.get(x, 0) + 1
        lens.append(len(cols) / inner_w if inner_w else 0)
        t = sorted(cols.values())
        thicks.append(t[len(t) // 2])
    n_lo, n_hi = TOWEL_STRIPES
    t_lo, t_hi = TOWEL_STRIPE_THICK
    ok = (n_lo <= len(blobs) <= n_hi and all(v >= TOWEL_STRIPE_LEN for v in lens)
          and all(t_lo <= t <= t_hi for t in thicks))
    out.append((f"남색 줄 {len(blobs)}개, 길이 {'·'.join(f'{v:.0%}' for v in lens) or '-'}, "
                f"두께 {'·'.join(str(t) for t in thicks) or '-'} "
                f"({n_lo}~{n_hi}개, 각 길이 {TOWEL_STRIPE_LEN:.0%} 이상, 두께 {t_lo}~{t_hi})", ok))

    # 가운데 열: 채움 위 끝 → 줄 → … → 채움 아래 끝 사이의 흰 틈
    bbox = mask.getbbox()
    cc = round((bbox[0] + bbox[2]) / 2 / SCALE)
    ys = [y for y in range(360) if fill_g[y][cc]]
    gaps: list[int] = []
    if ys:
        top, bottom = ys[0], ys[-1]
        runs_: list[list[int]] = []
        for y in range(top, bottom + 1):
            if ind_g[y][cc]:
                if runs_ and runs_[-1][1] == y - 1:
                    runs_[-1][1] = y
                else:
                    runs_.append([y, y])
        edges = [top - 1] + [v for r_ in runs_ for v in r_] + [bottom + 1]
        gaps = [edges[i + 1] - edges[i] - 1 for i in range(0, len(edges), 2)]
    if len(gaps) >= 3:
        ok = (gaps[0] >= TOWEL_GAP_EDGE and gaps[-1] >= TOWEL_GAP_EDGE
              and all(v >= TOWEL_GAP_BETWEEN for v in gaps[1:-1]))
        text = f"위 {gaps[0]}, 사이 {'·'.join(str(v) for v in gaps[1:-1])}, 아래 {gaps[-1]}"
    else:
        ok, text = False, f"줄 {max(0, len(gaps) - 1)}개만 지남"
    out.append((f"가운데 열(x {cc - 30}) 흰 틈 {text} (위·아래 {TOWEL_GAP_EDGE} 이상, 사이 {TOWEL_GAP_BETWEEN} 이상)", ok))
    return out


def components(grid: list[list[bool]], min_size: int = 1) -> list[list[tuple[int, int]]]:
    """360 단위 격자의 이어진 덩어리 (4방향). 각 덩어리는 (x, y) 목록(x는 360 좌표)."""
    seen = set()
    blobs = []
    for y in range(360):
        for c in range(360):
            if not grid[y][c] or (c, y) in seen:
                continue
            stack, blob = [(c, y)], []
            seen.add((c, y))
            while stack:
                cc, yy = stack.pop()
                blob.append((cc - 30, yy))
                for nc, ny in ((cc - 1, yy), (cc + 1, yy), (cc, yy - 1), (cc, yy + 1)):
                    if 0 <= nc < 360 and 0 <= ny < 360 and grid[ny][nc] and (nc, ny) not in seen:
                        seen.add((nc, ny))
                        stack.append((nc, ny))
            if len(blob) >= min_size:
                blobs.append(blob)
    return blobs


def size_numbers(layer: Image.Image, info: dict | None = None, item: dict | None = None) -> dict:
    """보이는 크기 (head-fit.md 1.9): 보이는 상자, 폭 %, 80pt 환산, 면적 %. band·수건은 가운데 열 굵기, band는 매듭 폭도."""
    mask = alpha_mask(layer)
    bbox = mask.getbbox()
    w, h = (bbox[2] - bbox[0]) / SCALE, (bbox[3] - bbox[1]) / SCALE
    out = {"w": w, "h": h, "widthPct": w / BODY_WIDTH, "area": count(mask) / chef_hat_area(),
           "pt80": (w * PT80, h * PT80)}
    if info is None or item is None:
        return out
    g = unit_grid(mask)
    how = info.get("fit")
    cls = item.get("sizeClass", SIZE_CLASS.get(how))
    if cls in ("band", "towel"):
        cx = round(info["contact_x"]) if cls == "band" else round((bbox[0] + bbox[2]) / 2 / SCALE) - 30
        ys = [y for y in range(360) if g[y][cx + 30]]
        out["thick"] = (ys[-1] - ys[0] + 1) if ys else 0
    if cls == "band" and ys:
        # 매듭: 띠 가운데 줄(기울기를 따라)을 지나면서 띠보다 4 넘게 두꺼운 열이 처음 이어지는 구간의 폭.
        # 오른쪽 꼬리는 띠 가운데 줄 위로 떠 있어 빠진다. 4차 수정(3.2.3.5): 꼬리가 매듭 아래에 붙어 열 두께를 키우므로
        # `tail` 다각형 픽셀을 빼고 잰다.
        gk = unit_grid(mask_sub(mask, info["tail"])) if info.get("tail") is not None else g
        mid0, slope = (ys[0] + ys[-1]) / 2, math.tan(math.radians(item.get("rotate", 0)))
        run, started = 0, False
        for x in range(cx, 237):
            col = [y for y in range(360) if gk[y][x + 30]]
            yc = round(mid0 + (x - cx) * slope)
            thick = len(col) > out["thick"] + 4 and 0 <= yc < 360 and g[yc][x + 30]
            if thick:
                run, started = run + 1, True
            elif started:
                break
        out["knot"] = run
    return out


def check_size(item: dict, layer: Image.Image, info: dict) -> list[tuple[str, bool]]:
    """검사 12 (head-fit.md 1.9.3): 맞춤 방식별 보이는 크기 하한."""
    cls = item.get("sizeClass", SIZE_CLASS.get(info.get("fit")))
    need = SIZE_MIN.get(cls)
    if not need:
        return []
    s = size_numbers(layer, info, item)
    parts = [f"크기 {s['w']:.0f}×{s['h']:.0f} ({s['widthPct']:.0%}) 80pt {s['pt80'][0]:.1f}×{s['pt80'][1]:.1f}pt 면적 {s['area']:.0%}"]
    ok = s["area"] >= need["area"]
    lim = [f"면적 {need['area']:.0%}"]
    if "w" in need:
        ok = ok and s["w"] >= need["w"]
        lim.append(f"폭 {need['w']}")
    if "h" in need:
        ok = ok and s["h"] >= need["h"]
        lim.append(f"높이 {need['h']}")
    if "thick" in need:
        parts.append(f"{'띠 굵기' if cls == 'band' else '두께'} {s.get('thick', 0)}")
        ok = ok and s.get("thick", 0) >= need["thick"]
        lim.append(f"{'굵기' if cls == 'band' else '두께'} {need['thick']}")
    if "knot" in need:
        parts.append(f"매듭 폭 {s.get('knot', 0)}")
        ok = ok and need["knot"] <= s.get("knot", 0) <= need.get("knotMax", math.inf)
        lim.append(f"매듭 {need['knot']}" + (f"~{need['knotMax']}" if "knotMax" in need else ""))
    return [(f"{' / '.join(parts)} ({cls} 하한: {', '.join(lim)} 이상)", ok)]


TAIL_KNOT_TOL = 3                  # 검사 13: 매듭 가운데가 knotTarget에서 벗어나도 되는 거리 (각 축)


def check_tail(item: dict, layer: Image.Image, info: dict) -> list[tuple[str, bool]]:
    """검사 13 (head-fit.md 5번, 3.2.3.5): band 꼬리가 매듭 아래로 늘어지는지. items.json `tailRange`가 있는 아이템만.
    매듭 가운데 = `clipExempt` 안 불투명 픽셀에서 `tail` 픽셀을 뺀 것의 무게중심. 방향은 매듭 가운데 → 가장 먼 `tail` 픽셀,
    세로 아래 0°에서 오른쪽으로 +. 길이 = 그 거리 − 매듭 폭 ÷ 2 (매듭 폭은 검사 12와 같은 값)."""
    rng = item["tailRange"]
    mask = alpha_mask(layer)
    top = mask.getbbox()[1] / SCALE
    out = [(f"꼬리: 보이는 상자 위 끝 y {top:.0f} ({rng['topMin']} 이상)", top >= rng["topMin"])]
    tail = info.get("tail")
    if tail is None:
        return out + [("꼬리: items.json `tail` 다각형 없음", False)]
    tail = mask_and(tail, mask)
    exempt = polygon_mask(item.get("clipExempt", []), layer.size, lambda p: (gx(p[0]), px(p[1])))
    knot = mask_sub(mask_and(mask, exempt), tail)

    def points(m: Image.Image) -> list[tuple[float, float]]:
        grid = unit_grid(m)
        return [(c - 30 + 0.5, y + 0.5) for y in range(360) for c in range(360) if grid[y][c]]

    kp, tp = points(knot), points(tail)
    if not kp or not tp:
        return out + [(f"꼬리: 매듭 픽셀 {len(kp)}, 꼬리 픽셀 {len(tp)}", False)]
    kx, ky = sum(p[0] for p in kp) / len(kp), sum(p[1] for p in kp) / len(kp)
    t_top = min(p[1] for p in tp)
    fx, fy = max(tp, key=lambda p: (p[0] - kx) ** 2 + (p[1] - ky) ** 2)
    dist = math.hypot(fx - kx, fy - ky)
    angle = math.degrees(math.atan2(fx - kx, fy - ky))       # 세로 아래 0°, 오른쪽 +
    knot_w = size_numbers(layer, info, item).get("knot", 0)
    length = dist - knot_w / 2
    a_lo, a_hi = rng["angle"]
    l_lo, l_hi = rng["length"]
    tx, ty = item.get("knotTarget", (kx, ky))
    out += [
        (f"꼬리: 꼬리 위 끝 y {t_top:.0f} (매듭 가운데 y {ky:.1f} 이상)", t_top >= ky),
        (f"꼬리: 방향 세로 아래에서 {angle:+.0f}° ({a_lo}~{a_hi}), 끝 ({fx:.0f}, {fy:.0f})", a_lo <= angle <= a_hi),
        (f"꼬리: 길이 {dist:.1f} − 매듭 {knot_w}÷2 = {length:.1f} ({l_lo}~{l_hi})", l_lo <= length <= l_hi),
        (f"꼬리: 매듭 가운데 ({kx:.1f}, {ky:.1f}) (목표 ({tx}, {ty}) ±{TAIL_KNOT_TOL})",
         abs(kx - tx) <= TAIL_KNOT_TOL and abs(ky - ty) <= TAIL_KNOT_TOL),
    ]
    if "composeIndigo" in info:
        dh, dv = info["composeIndigo"]
        out.append((f"꼬리: 합성 남색 차 색상 {dh:.1f}° 명도 {dv:.3f} (8° · 0.08 이하)", dh <= 8 and dv <= 0.08))
    return out


def place_top(src: Image.Image, item: dict) -> Image.Image:
    """맞춤 방식(fit)이 없는 머리 아이템의 옛 놓기 (brief.md 2.1.6). 지금 목록에는 쓰는 아이템이 없다."""
    kind = item.get("kind", "hat")
    w, h = item.get("box", TOP_BOX[kind])
    img = fit(trim(src), px(w), px(h))
    anchor = anchor_px(img, item.get("anchor"), (0.5, 1.0))
    return place_at(img, anchor, tuple(item.get("contact", TOP_CONTACT)), item.get("rotate", 0))


def level(src: Image.Image, item: dict) -> Image.Image:
    """sourceRotate(도, SVG 부호): 그림 자체가 기울어 있을 때 먼저 바로 세운다. 그림의 긴 축이 오른쪽으로 내려가면 음수."""
    deg = item.get("sourceRotate", 0)
    return src.rotate(-deg, resample=Image.BICUBIC, expand=True) if deg else src


def place_filling(src: Image.Image, item: dict) -> Image.Image:
    img = apply_erase(trim(level(src, item)), item.get("erase"))
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


def magenta_layer(rgb: Image.Image) -> Image.Image:
    """자홍 바탕에 그린 그림을 RGBA로. 가장자리의 자홍 섞인 픽셀은 외곽선 색으로 바꾼다(그림 가장자리는 모두 외곽선이다)."""
    layer = rgb.convert("RGBA")
    layer.putalpha(magenta_mask(rgb))
    fringe = Image.new("L", rgb.size)
    fringe.putdata([255 if (r - g > 60 and b - g > 60) else 0 for r, g, b in rgb.get_flattened_data()])
    line = Image.new("RGBA", rgb.size, LINE_RGB + (255,))
    line.putalpha(layer.getchannel("A"))
    return Image.composite(line, layer, fringe)


def svg_item_layer(draw) -> Image.Image:
    """make_onigiri_svg.py가 그리는 머리 아이템(기본 요리사 모자)을 레이어로. 자홍 바탕에 그려 알파를 만든다."""
    return magenta_layer(render_svg(giri.wrap('<rect x="-30" y="0" width="360" height="360" fill="#FF00FF"/>' + draw())))


def build(item: dict, info: dict | None = None, src: Image.Image | None = None) -> dict[str, Image.Image]:
    """플랫폼에 묶이지 않는 결과: 파일 이름 → 그림. info를 주면 머리 맞춤 검사용 정보를 채운다.
    src를 주면 source/{id}.png 대신 그 그림을 쓴다(후보를 에셋에 넣기 전에 검사할 때)."""
    slot, iid = item["slot"], item["id"]
    info = {} if info is None else info
    if item.get("drawnBy"):
        # 기본 요리사 모자: SVG가 띠를 자른다. 검사만 같은 함수로 한다 (head-fit.md 5번).
        layer = svg_item_layer(getattr(giri, item["drawnBy"]))
        unclipped = svg_item_layer(lambda: giri.hat(clip=False))
        cx = head_point(item["dx"])[0]
        info.update(fit=item["fit"], contact_x=cx,
                    overshoot=band_overshoot(alpha_mask(unclipped), alpha_mask(layer), cx))
        return {iid: layer, f"{iid}-thumb": crop_view(layer, THUMB_VIEW[slot])}
    src = (src or Image.open(SOURCE / f"{item['id']}.png")).convert("RGBA")
    if slot == "background":
        side = min(src.size)
        sq = src.crop(((src.width - side) // 2, (src.height - side) // 2,
                       (src.width + side) // 2, (src.height + side) // 2))
        layer = sq.resize((SIDE, SIDE), Image.LANCZOS)
        draw_kana(layer, item.get("kanaBoxes", []))
    elif slot == "top" and item.get("fit"):
        layer, placed = place_head(src, item)
        info.update(placed)
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


# 기본 요리사 모자 실루엣의 불투명 픽셀 수 (brief.md 2.1.4의 면적 기준값, SCALE 3 레이어).
# 2026-11-17 모자를 바꾸기 전(head-fit.md 3.1)의 hat()에서 잰 값으로 얼린다. 새 모자는 띠가 잘리고 관이 좁아져
# 면적이 줄어드는데, 기준이 같이 줄면 다른 아이템의 상한이 몰래 좁아지기 때문이다.
CHEF_HAT_AREA = 112513


def chef_hat_area() -> int:
    return CHEF_HAT_AREA


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
    result = [
        (f"자리 {box_text}", True),
        (f"범위 밖 {out}px", out == 0),
        (f"상자 {w}×{h} (상한 {limit_w}×{limit_h})", w <= limit_w and h <= limit_h),
        (f"면적 모자의 {area:.0%} (상한 {TOP_AREA[kind]:.0%})", area <= TOP_AREA[kind]),
        (f"채움 색 {colors} [{desc}]", colors <= TOP_COLORS),
        (f"덩어리 {n}", n == 1),
    ]
    if kind == "topping":
        top = bbox[1] / SCALE
        result.append((f"위 끝 y {top:.0f} ({TOPPING_TOP_Y} 이상)", top >= TOPPING_TOP_Y))
    return result


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

    def available(i: str) -> bool:
        return i in items and (bool(items[i].get("drawnBy")) or (SOURCE / f"{i}.png").exists())

    ids = args or sorted(i for i in items if available(i))
    missing = [i for i in ids if not available(i)]
    if missing:
        print(f"source/에 그림이 없거나 items.json에 없는 id: {missing}", file=sys.stderr)
        return 2
    NEUTRAL.mkdir(parents=True, exist_ok=True)
    failed = False
    for iid in ids:
        item = items[iid]
        info: dict = {}
        results = build(item, info)
        svg_drawn = bool(item.get("drawnBy"))
        if not check_only:
            for file, img in results.items():
                img.save(NEUTRAL / f"{file}.png")
                if not svg_drawn:     # SVG 에셋은 make_onigiri_svg.py가 쓴다
                    write_imageset(ios_name(file), img)
        g, pr = forbidden_ratio(results[iid] if svg_drawn else Image.open(SOURCE / f"{iid}.png"))
        checks = [(f"초록 {g:.0%}, 분홍빨강 {pr:.0%}", max(g, pr) <= 0.10)]
        if item["slot"] == "top" and info.get("fit"):
            checks = check_top(item, results[iid]) + check_head_fit(item, results[iid], info) + checks
        elif item["slot"] == "top":
            checks = check_top(item, results[iid]) + checks
        elif item["slot"] == "filling":
            checks = check_filling(item, results[iid]) + checks
        waive = item.get("waive") or {}
        waived = lambda text: any(text.startswith(k) for k in waive.get("checks", []))  # noqa: E731
        bad = [text for text, ok in checks if not ok and not waived(text)]
        failed = failed or bool(bad)
        print(f"{iid:15} {item['slot']:10} " + ("검사만" if check_only else "→ " + ", ".join(ios_name(f) for f in results)))
        for text, ok in checks:
            if ok:
                print(f"    {text}" + ("  (면제 표시가 있지만 통과)" if waived(text) else ""))
            elif waived(text):
                print(f"    {text}  ← 면제: {waive.get('reason', '사유 없음')}")
            else:
                print(f"    {text}  ← 확인")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
