#!/usr/bin/env python3
"""홈 바탕 풍경을 검사하고 앱 에셋으로 넣는다 (docs/design/home-backdrop.md 6.4, 7.4, 7.5).

하위 명령:
  check 후보.png…        바탕을 지우고 수치 검사 N1~N8을 출력한다(N7·N8은 build와 같은 처리를 메모리에서 해 낸다).
                          --sheet 출력.png --scene id 를 주면 후보 묶음 시트를 만든다(--verdict 파일.json으로 눈 검사 판정을 적는다).
  build                  docs/design/backdrop-art/source/backdrop-{id}.png 마다 지우기 → 어두운 끝 들어올리기 → 1320×660 →
                          아래 30% 알파 줄임 → 썸네일 → 5색 × 2모드 불투명도 계산 → build/backdrop/, 에셋 카탈로그, backdrops.json.
                          고른 그림이 없는 항목은 opacity 0으로 둔다(앱이 칸을 만들지 않는다). 끝에 비교 시트를 만든다.
  verify                 V1~V6. 하나라도 못 넘으면 1로 끝난다.
  --markdown             (verify와 함께) 결과를 마크다운 표로.

합성 식 (sRGB 부호화 값 0~1, 채널마다. B 바탕, A 그림, a 그림 알파, o 불투명도):
  라이트 곱하기: C = B × (1 − o·a·(1 − A))      다크 스크린: C = B + o·a·A·(1 − B)
앱의 SwiftUI 합성과 맞는지는 시뮬레이터 화면 픽셀로 확인했다(home-backdrop.md 구현 메모).

실행: .venv/bin/python tools/make_backdrop_art.py check docs/design/backdrop-art/source/candidates/backdrop-sushi_301.png
필요: Pillow (tools/requirements.txt). numpy 없이 고유 색 단위로 계산한다.
"""
from __future__ import annotations

import argparse
import colorsys
import json
import math
import shutil
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from remove_bg import remove_bg  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "design" / "backdrop-art" / "source"
OUT = ROOT / "build" / "backdrop"
ASSETS = ROOT / "KanaTrip" / "Assets.xcassets"
DATA = ROOT / "KanaTrip" / "Resources" / "backdrops.json"
SKINS = ROOT / "KanaTrip" / "Resources" / "skins.json"
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

GEN_SIZE = (1280, 640)
STRIP3 = (1320, 660)
STRIP2 = (880, 440)
THUMB3 = (300, 150)
THUMB2 = (200, 100)
LIFT_LUMINANCE = 0.18
FADE_FROM = 0.70


# MARK: - 색 계산

def lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def unlin(c: float) -> float:
    c = max(0.0, min(1.0, c))
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def lum(r: float, g: float, b: float) -> float:
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def hex_rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def skin_backgrounds() -> list[tuple[str, tuple, tuple]]:
    """(색 id, 라이트 AppBackground, 다크 AppBackground)."""
    data = json.loads(SKINS.read_text())
    out = []
    for s in data["skins"]:
        bg = s["colors"]["AppBackground"]
        out.append((s["id"], hex_rgb(bg["light"]), hex_rgb(bg["dark"])))
    return out


def colors_of(img: Image.Image) -> list[tuple[int, tuple[float, float, float, float]]]:
    """(개수, (r, g, b, a) 0~1). 알파 0인 픽셀도 센다."""
    raw = img.convert("RGBA").getcolors(img.width * img.height)
    return [(n, (r / 255, g / 255, b / 255, a / 255)) for n, (r, g, b, a) in raw]


def compose(mode: str, bg: tuple, px: tuple, o: float) -> tuple[float, float, float]:
    r, g, b, a = px
    k = o * a
    if mode == "light":
        return tuple(bc * (1 - k * (1 - ac)) for bc, ac in zip(bg, (r, g, b)))
    return tuple(bc + k * ac * (1 - bc) for bc, ac in zip(bg, (r, g, b)))


def percentile(pairs: list[tuple[float, int]], q: float) -> float:
    """(값, 개수)의 q 백분위(0~100). 가장 가까운 순위."""
    pairs = sorted(pairs)
    total = sum(n for _, n in pairs)
    rank = max(1, math.ceil(q / 100 * total))
    acc = 0
    for v, n in pairs:
        acc += n
        if acc >= rank:
            return v
    return pairs[-1][0]


def composed_lums(colors, mode: str, bg: tuple, o: float, only_art: bool = True):
    return [(lum(*compose(mode, bg, px, o)), n) for n, px in colors if (px[3] > 0 or not only_art)]


def best_opacity(colors, limits: dict, skins) -> dict:
    """5색 모두에서 2.3 조건을 만족하는 가장 큰 o(0.01 단위 내림, 상한으로 자름). 하한 밑이면 그 값 그대로 돌려 N7이 떨어뜨린다."""
    result = {}
    for mode in ("light", "dark"):
        lim = limits["lightOpacity" if mode == "light" else "darkOpacity"]
        best = 0.0
        # 위에서부터 0.01씩 내려간다(합성 휘도는 o에 대해 단조).
        steps = int(round(lim["max"] * 100))
        for i in range(steps, 0, -1):
            o = i / 100
            ok = True
            for _, light, dark in skins:
                bg = light if mode == "light" else dark
                ls = composed_lums(colors, mode, bg, o)
                if mode == "light":
                    ok = percentile(ls, limits["lightPercentile"]) >= limits["lightMinLuminance"]
                else:
                    ok = percentile(ls, limits["darkPercentile"]) <= limits["darkMaxLuminance"]
                if not ok:
                    break
            if ok:
                best = o
                break
        result[mode] = best
    return result


# MARK: - 그림 처리

def lift_dark(img: Image.Image) -> Image.Image:
    """상대 휘도 0.18 미만인 픽셀을 선형 RGB에서 흰색 쪽으로 섞어 0.18로 (색상 유지, 7.5 ②)."""
    img = img.convert("RGBA")
    cache: dict = {}

    def f(p):
        if p in cache:
            return cache[p]
        r, g, b, a = p
        if a == 0:
            cache[p] = p
            return p
        lr, lg, lb = lin(r / 255), lin(g / 255), lin(b / 255)
        L = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
        if L >= LIFT_LUMINANCE:
            cache[p] = p
            return p
        t = (LIFT_LUMINANCE - L) / (1 - L)
        q = tuple(round(unlin(c + t * (1 - c)) * 255) for c in (lr, lg, lb)) + (a,)
        cache[p] = q
        return q

    out = Image.new("RGBA", img.size)
    out.putdata([f(p) for p in img.get_flattened_data()])
    return out


def resize(img: Image.Image, size) -> Image.Image:
    return img.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")


def fade_bottom(img: Image.Image) -> Image.Image:
    """행 y가 0.70H → H로 갈 때 알파 × (1 − smoothstep(t)). 맨 아래 줄은 알파 0 (7.5 ④)."""
    w, h = img.size
    r, g, b, a = img.split()
    start = FADE_FROM * h
    mask = Image.new("L", (w, h))
    rows = []
    for y in range(h):
        if y < start:
            f = 1.0
        else:
            t = min(1.0, (y - start) / (h - 1 - start))
            f = 1 - t * t * (3 - 2 * t)
        rows.append(round(255 * f))
    mask.putdata([v for v in rows for _ in range(w)])
    from PIL import ImageChops
    a = ImageChops.multiply(a, mask)
    return Image.merge("RGBA", (r, g, b, a))


def process(src: Image.Image) -> tuple[Image.Image, Image.Image, float]:
    """원본 → (지운 1280×640, 에셋 띠 1320×660, 지운 비율)."""
    # 바탕은 위 변(그림 위 1/8은 비어 있다, 7.3)의 중앙값으로 정한다. 네 변 중앙값은 땅 띠가 아래 변을 다 차지하면
    # 땅 색이 되어 땅을 지우고 하늘을 남긴다(돈카츠집 302에서 봄).
    rgb = src.convert("RGB")
    top = [rgb.getpixel((x, y)) for x in range(0, rgb.width, 4) for y in (0, 1, 2)]
    bg = tuple(sorted(c[i] for c in top)[len(top) // 2] for i in range(3))
    cut, _, removed = remove_bg(src, 40, bg=bg)
    lifted = lift_dark(cut)
    strip = fade_bottom(resize(lifted, STRIP3))
    return cut, strip, removed


# MARK: - 수치 검사 (7.4)

def numeric_checks(cut: Image.Image, removed: float) -> dict:
    w, h = cut.size
    px = list(cut.get_flattened_data())
    opaque = [p[3] >= 128 for p in px]
    n_op = sum(opaque)
    top = sum(opaque[: (h // 8) * w]) / ((h // 8) * w)
    third = w // 3

    def col_ratio(x0, x1):
        cnt = sum(1 for y in range(h) for x in range(x0, x1) if opaque[y * w + x])
        return cnt / ((x1 - x0) * h)

    left, mid, right = col_ratio(0, third), col_ratio(third, 2 * third), col_ratio(2 * third, w)
    n3 = mid / ((left + right) / 2) if (left + right) > 0 else 9
    dark = green = pink = 0
    for p, op in zip(px, opaque):
        if not op:
            continue
        r, g, b = p[0] / 255, p[1] / 255, p[2] / 255
        if lum(r, g, b) < 0.05:
            # 진한 픽셀은 외곽선이다. N5(면의 색)에서는 세지 않는다(진갈색 선이 색상 350° 언저리로 나온다).
            dark += 1
            continue
        hh, s, _ = colorsys.rgb_to_hsv(r, g, b)
        hd = hh * 360
        if s >= 0.25 and 125 <= hd <= 160:
            green += 1
        if s >= 0.25 and 330 <= hd <= 359.999:
            pink += 1
    # N6: 알파 < 128 영역 가운데 가장자리와 이어지지 않은 덩어리(20픽셀 이상).
    clear = bytearray(1 if p[3] < 128 else 0 for p in px)
    seen = bytearray(w * h)
    holes = 0
    for start in range(w * h):
        if not clear[start] or seen[start]:
            continue
        seen[start] = 1
        q = deque([start])
        size = 0
        edge = False
        while q:
            p = q.pop()
            size += 1
            x, y = p % w, p // w
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                edge = True
            for nb in ((p - 1) if x > 0 else -1, (p + 1) if x < w - 1 else -1, p - w, p + w):
                if 0 <= nb < w * h and clear[nb] and not seen[nb]:
                    seen[nb] = 1
                    q.append(nb)
        if not edge and size >= 20:
            holes += 1
    return {
        # N4는 전체 픽셀에 대한 비율(N1과 같은 분모). 불투명 픽셀 대비 값은 N4op로 함께 낸다.
        "N1": removed, "N2": top, "N3": n3, "N4": dark / (w * h),
        "N4op": dark / n_op if n_op else 0, "N5g": green / n_op if n_op else 0, "N5p": pink / n_op if n_op else 0, "N6": holes,
    }


def n8(strip: Image.Image, op: dict, skins) -> tuple[float, float]:
    colors = colors_of(strip)
    _, light, dark = skins[0]
    ls = composed_lums(colors, "light", light, op["light"], only_art=False)
    total = sum(n for _, n in ls)
    mean = sum(v * n for v, n in ls) / total
    std = math.sqrt(sum(n * (v - mean) ** 2 for v, n in ls) / total)
    dmax = max(v for v, _ in composed_lums(colors, "dark", dark, op["dark"]))
    return std, dmax


def verdict_numeric(m: dict, limits: dict) -> list[str]:
    fails = []
    if not 0.30 <= m["N1"] <= 0.70: fails.append("N1")
    if m["N2"] > 0.02: fails.append("N2")
    if m["N3"] > 0.85: fails.append("N3")
    if m["N4"] > 0.06: fails.append("N4")
    if m["N5g"] > 0.03 or m["N5p"] > 0.01: fails.append("N5")
    if m["N6"] > 0: fails.append("N6")
    if m["light"] < limits["lightOpacity"]["min"] or m["dark"] < limits["darkOpacity"]["min"]: fails.append("N7")
    return fails


def check_one(path: Path, limits, skins) -> dict:
    src = Image.open(path)
    cut, strip, removed = process(src)
    m = numeric_checks(cut, removed)
    op = best_opacity(colors_of(strip), limits, skins)
    m.update(op)
    m["N8std"], m["N8dark"] = n8(strip, op, skins)
    m["fails"] = verdict_numeric(m, limits)
    m["_cut"], m["_strip"] = cut, strip
    return m


def fmt(m: dict) -> str:
    return (f"N1 {m['N1']*100:.0f}%  N2 {m['N2']*100:.1f}%  N3 {m['N3']:.2f}  N4 {m['N4']*100:.1f}% (불투명 대비 {m['N4op']*100:.1f}%)  "
            f"N5 {m['N5g']*100:.1f}%/{m['N5p']*100:.2f}%  N6 {m['N6']}  N7 {m['light']:.2f}/{m['dark']:.2f}  "
            f"N8 {m['N8std']:.3f}/{m['N8dark']:.3f}  → {'통과' if not m['fails'] else '탈락 ' + ','.join(m['fails'])}")


# MARK: - 시트

def font(size: int):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def checker(size, cell=16) -> Image.Image:
    img = Image.new("RGB", size, (235, 235, 235))
    d = ImageDraw.Draw(img)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=(205, 205, 205))
    return img


def composite_image(strip: Image.Image, mode: str, bg: tuple, o: float) -> Image.Image:
    """앱과 같은 식으로 바탕 위에 합성한 RGB."""
    cache: dict = {}
    out = []
    for p in strip.get_flattened_data():
        c = cache.get(p)
        if c is None:
            px = (p[0] / 255, p[1] / 255, p[2] / 255, p[3] / 255)
            c = tuple(round(v * 255) for v in compose(mode, bg, px, o))
            cache[p] = c
        out.append(c)
    img = Image.new("RGB", strip.size)
    img.putdata(out)
    return img


def candidate_sheet(results: list[tuple[Path, dict]], scene: str, verdicts: dict, out: Path, skins):
    """후보 2열 × 2행: 위에 지운 결과(체크무늬 위), 아래에 기본 라이트 합성 402pt 크기. 아래에 수치·눈 판정."""
    cw, ch = 640, 320
    pad, text_h = 16, 116
    cols = 2
    rows = math.ceil(len(results) / cols)
    W = pad + cols * (cw + pad)
    cell_h = ch + 8 + 201 + text_h
    H = 56 + rows * (cell_h + pad)
    sheet = Image.new("RGB", (W, H), (255, 253, 247))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 14), f"홈 바탕 후보: {scene}", font=font(26), fill=(74, 34, 25))
    _, light, _ = skins[0]
    for i, (path, m) in enumerate(results):
        x = pad + (i % cols) * (cw + pad)
        y = 56 + (i // cols) * (cell_h + pad)
        cut = m["_cut"].resize((cw, ch), Image.Resampling.LANCZOS)
        bgimg = checker((cw, ch))
        bgimg.paste(cut, (0, 0), cut)
        sheet.paste(bgimg, (x, y))
        comp = composite_image(m["_strip"].resize((402, 201), Image.Resampling.LANCZOS), "light", light, m["light"])
        sheet.paste(comp, (x, y + ch + 8))
        seed = path.stem.split("_")[-1]
        v = verdicts.get(seed, {})
        eye = v.get("eye", "눈 검사 전")
        picked = v.get("picked", False)
        fails = m["fails"] + v.get("fails", [])
        status = "고름" if picked else ("탈락" if fails else "통과")
        color = (46, 125, 74) if status != "탈락" else (184, 35, 63)
        ty = y + ch + 8 + 201 + 6
        d.text((x + 410, y + ch + 14), f"시드 {seed}", font=font(22), fill=(74, 34, 25))
        d.text((x + 410, y + ch + 44), status, font=font(28), fill=color)
        if fails:
            d.text((x + 410, y + ch + 82), ",".join(fails), font=font(18), fill=color)
        d.text((x + 410, y + ch + 110), f"라이트 o {m['light']:.2f}", font=font(16), fill=(122, 90, 76))
        d.text((x + 410, y + ch + 132), f"다크 o {m['dark']:.2f}", font=font(16), fill=(122, 90, 76))
        num = (f"N1 {m['N1']*100:.0f}%  N2 {m['N2']*100:.1f}%  N3 {m['N3']:.2f}  N4 {m['N4']*100:.1f}%  "
               f"N5 {m['N5g']*100:.1f}/{m['N5p']*100:.2f}%  N6 {m['N6']}  N8 {m['N8std']:.3f}/{m['N8dark']:.3f}")
        d.text((x, ty), num, font=font(15), fill=(122, 90, 76))
        for k, line in enumerate(wrap(eye, 44)[:4]):
            d.text((x, ty + 22 + k * 22), line, font=font(17), fill=(74, 34, 25))
    if W > 1400:
        sheet = sheet.resize((1400, round(H * 1400 / W)), Image.Resampling.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)


def wrap(text: str, n: int) -> list[str]:
    lines, cur = [], ""
    for word in text.split(" "):
        if len(cur) + len(word) + 1 > n and cur:
            lines.append(cur)
            cur = word
        else:
            cur = (cur + " " + word).strip()
    if cur:
        lines.append(cur)
    return lines


# MARK: - build / verify

def load_data() -> dict:
    return json.loads(DATA.read_text())


def write_imageset(name: str, img2: Image.Image, img3: Image.Image):
    folder = ASSETS / f"{name}.imageset"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    img2.save(folder / f"{name}@2x.png", optimize=True)
    img3.save(folder / f"{name}@3x.png", optimize=True)
    contents = {
        "images": [
            {"idiom": "universal", "scale": "1x"},
            {"filename": f"{name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"{name}@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def save_data(data: dict):
    # 풍경 항목은 한 줄씩 두어 문서(6.1)의 모양을 지킨다.
    rows = data["backdrops"]
    body = dict(data)
    body["backdrops"] = "__ROWS__"
    text = json.dumps(body, ensure_ascii=False, indent=2)
    lines = ",\n".join("    " + json.dumps(r, ensure_ascii=False) for r in rows)
    text = text.replace('"__ROWS__"', "[\n" + lines + "\n  ]")
    DATA.write_text(text + "\n")


def build() -> int:
    data = load_data()
    limits = data["limits"]
    skins = skin_backgrounds()
    OUT.mkdir(parents=True, exist_ok=True)
    built = []
    for entry in data["backdrops"]:
        bid = entry["id"]
        src = SOURCE / f"backdrop-{bid}.png"
        if not src.exists():
            entry["opacity"] = {"light": 0.0, "dark": 0.0}
            for name in (f"Backdrop-{bid}", f"BackdropThumb-{bid}"):
                if (ASSETS / f"{name}.imageset").exists():
                    shutil.rmtree(ASSETS / f"{name}.imageset")
            print(f"{bid}: 고른 그림 없음 → opacity 0 (칸을 만들지 않음)")
            continue
        _, strip, _ = process(Image.open(src))
        op = best_opacity(colors_of(strip), limits, skins)
        entry["opacity"] = {"light": op["light"], "dark": op["dark"]}
        strip2 = resize(strip, STRIP2)
        thumb3, thumb2 = resize(strip, THUMB3), resize(strip, THUMB2)
        strip.save(OUT / f"backdrop-{bid}@3x.png")
        write_imageset(f"Backdrop-{bid}", strip2, strip)
        write_imageset(f"BackdropThumb-{bid}", thumb2, thumb3)
        built.append((bid, strip, op))
        print(f"{bid}: 라이트 {op['light']:.2f}, 다크 {op['dark']:.2f}")
    save_data(data)
    if built:
        comparison_sheet(built, skins, OUT / "sheet.png")
        print(f"시트: {OUT / 'sheet.png'}")
    return 0


def comparison_sheet(built, skins, out: Path):
    """8장 × (기본 라이트, 기본 다크) 합성. 402×201 크기."""
    w, h, pad = 402, 201, 12
    W = pad + 2 * (w + pad)
    H = 40 + len(built) * (h + 26 + pad)
    sheet = Image.new("RGB", (W, H), (255, 253, 247))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 10), "홈 바탕 8장 (기본 색, 라이트 | 다크)", font=font(20), fill=(74, 34, 25))
    _, light, dark = skins[0]
    for i, (bid, strip, op) in enumerate(built):
        y = 40 + i * (h + 26 + pad)
        small = strip.resize((w, h), Image.Resampling.LANCZOS)
        d.text((pad, y), f"{bid}  라이트 {op['light']:.2f}  다크 {op['dark']:.2f}", font=font(16), fill=(74, 34, 25))
        sheet.paste(composite_image(small, "light", light, op["light"]), (pad, y + 22))
        sheet.paste(composite_image(small, "dark", dark, op["dark"]), (pad * 2 + w, y + 22))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)


def verify(markdown: bool) -> int:
    data = load_data()
    limits = data["limits"]
    skins = skin_backgrounds()
    rows = []
    failed = False
    for entry in data["backdrops"]:
        bid = entry["id"]
        op = entry["opacity"]
        if op["light"] == 0 and op["dark"] == 0:
            rows.append((bid, "그림 없음(칸 없음)", "", "", "", "", "", "–"))
            continue
        path = ASSETS / f"Backdrop-{bid}.imageset" / f"Backdrop-{bid}@3x.png"
        res = []
        ok = True
        if not path.exists():
            rows.append((bid, "에셋 없음", "", "", "", "", "", "실패"))
            failed = True
            continue
        strip = Image.open(path).convert("RGBA")
        colors = colors_of(strip)
        v1 = min(percentile(composed_lums(colors, "light", s[1], op["light"]), limits["lightPercentile"]) for s in skins)
        v2 = max(percentile(composed_lums(colors, "dark", s[2], op["dark"]), limits["darkPercentile"]) for s in skins)
        v3 = (limits["lightOpacity"]["min"] <= op["light"] <= limits["lightOpacity"]["max"]
              and limits["darkOpacity"]["min"] <= op["dark"] <= limits["darkOpacity"]["max"])
        worst_g = worst_p = 0.0
        for _, light, dark in skins:
            for mode, bg, o in (("light", light, op["light"]), ("dark", dark, op["dark"])):
                g = p = tot = 0
                for n, px in colors:
                    if px[3] == 0:
                        continue
                    c = compose(mode, bg, px, o)
                    hh, s, _ = colorsys.rgb_to_hsv(*c)
                    hd = hh * 360
                    tot += n
                    if s >= 0.25 and 125 <= hd <= 160: g += n
                    if s >= 0.25 and 330 <= hd < 360: p += n
                worst_g, worst_p = max(worst_g, g / tot), max(worst_p, p / tot)
        a = strip.split()[3]
        last_row_max = max(a.crop((0, strip.height - 1, strip.width, strip.height)).get_flattened_data())
        fade_row = max(a.crop((0, int(strip.height * 0.85), strip.width, int(strip.height * 0.85) + 1)).get_flattened_data())
        v5 = strip.size == STRIP3 and last_row_max == 0 and fade_row < 255
        v6 = (ASSETS / f"BackdropThumb-{bid}.imageset" / f"BackdropThumb-{bid}@3x.png").exists()
        checks = [v1 >= limits["lightMinLuminance"], v2 <= limits["darkMaxLuminance"], v3,
                  worst_g <= 0.01 and worst_p <= 0.01, v5, v6]
        ok = all(checks)
        failed |= not ok
        rows.append((bid, f"{op['light']:.2f} / {op['dark']:.2f}", f"{v1:.3f}", f"{v2:.4f}",
                     "통과" if v3 else "실패", f"{worst_g*100:.2f}% / {worst_p*100:.2f}%",
                     ("통과" if v5 else "실패") + ", " + ("통과" if v6 else "실패"), "통과" if ok else "실패"))
    head = ("풍경", "불투명도 라이트/다크", "V1 라이트 0.1%ile (최저)", "V2 다크 99.9%ile (최고)", "V3", "V4 초록/분홍 (최대)", "V5, V6", "결과")
    if markdown:
        print("| " + " | ".join(head) + " |")
        print("|" + "---|" * len(head))
        for r in rows:
            print("| " + " | ".join(r) + " |")
    else:
        for r in rows:
            print("  ".join(r))
    return 1 if failed else 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", choices=["check", "build", "verify"])
    p.add_argument("files", nargs="*", type=Path)
    p.add_argument("--markdown", action="store_true")
    p.add_argument("--sheet", type=Path)
    p.add_argument("--scene")
    p.add_argument("--verdict", type=Path, help="눈 검사 판정 JSON {시드: {eye, fails, picked}}")
    p.add_argument("--json", type=Path, help="check 수치를 JSON으로 저장")
    a = p.parse_args()
    if a.command == "build":
        return build()
    if a.command == "verify":
        return verify(a.markdown)
    data = load_data()
    skins = skin_backgrounds()
    results = []
    for f in a.files:
        m = check_one(f, data["limits"], skins)
        print(f"{f.name}: {fmt(m)}", flush=True)
        results.append((f, m))
    if a.json:
        a.json.write_text(json.dumps({f.stem: {k: v for k, v in m.items() if not k.startswith("_")}
                                      for f, m in results}, ensure_ascii=False, indent=1))
    if a.sheet:
        verdicts = json.loads(a.verdict.read_text()) if a.verdict and a.verdict.exists() else {}
        # docs/design/backdrop-art/verdicts.json은 {장면: {시드: 판정}} 꼴이다.
        verdicts = verdicts.get(a.scene, verdicts) if a.scene else verdicts
        candidate_sheet(results, a.scene or "", verdicts, a.sheet, skins)
        print(f"시트: {a.sheet}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
