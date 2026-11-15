#!/usr/bin/env python3
"""고른 단어 그림 후보를 다듬어 source/word-{이름}.png로 확정한다 (docs/design/word-art/brief.md 5.2).

  .venv/bin/python tools/clean_word_art.py soba            # 미리 보기만: build/word-art-clean/soba.png (전후 비교)
  .venv/bin/python tools/clean_word_art.py soba --apply    # source/word-soba.png와 .json으로 확정
  .venv/bin/python tools/clean_word_art.py --all --apply   # tools/word_art_clean.json의 단어 모두

단어마다 무엇을 할지는 tools/word_art_clean.json에 적는다. 같은 설정이면 결과가 같아서 다시 돌려도 된다.

  "soba": {"candidate": "word-soba_2070755637", "dots": true, "rim": true,
           "fill": [[x, y, r], ...], "keep": [[x, y, r], ...], "note": "..."}

- candidate: candidates/cut/의 투명본 이름(확장자 없이). 바탕을 지운 그림에서 시작한다.
- dots: 작은 고채도 점 자동 지우기. 생성 모델이 대상 위에 찍는 무지개색 점(빨강·초록·파랑·보라·분홍·노랑)을 찾는다.
  점 = 채도 0.55 이상, 밝기 0.45 이상이고 색상이 비슷한(30° 안) 픽셀 덩어리 가운데 지름이 그림 변의 DOT_MAX(4.5%)
  이하이고 둥글게 찬 것(경계 상자의 45% 이상). 주황(8~45°)은 음식 색(튀김, 소스, 새우, 연어알)이라 찾지 않는다.
  찾은 점은 둘레 고리 색과 비슷하면(넓은 면의 조각) 건너뛰고, 아니면 3px 넓혀 구멍으로 만든 뒤 구멍마다 가장 가까운
  구멍 밖 픽셀의 색으로 메운다(면 경계에 걸친 점도 양쪽 면이 이어진다).
- keep: 이 원 안에 가운데가 있는 점은 지우지 않는다(파 고리, 김, 와사비 등 대상의 정상적인 부분).
- fill: 자동으로 못 잡는 큰 얼룩(지름 4.5% 초과)이나 반달 같은 모양은 좌표(1024px 그림 기준 가운데와 반지름)로 메운다.
- paint / clear / line: 얼룩이 외곽선을 덮은 경우의 손질. paint {"disc": [x, y, r], "sample": [x, y] 또는 "color"}로
  한 색을 칠하고, clear [[x, y], ...] 다각형을 투명하게 지우고, line {"points": [[x, y], ...], "width": px}로
  외곽선(진갈색)을 다시 긋는다. 이 순서로 적용한다.
- stripes / tint: 색 범위({"hue": [도, 도], "sat": [0~1, 0~1], "val": [0~1, 0~1]})로 고른 픽셀을 메우거나(stripes,
  참치 살의 흰 줄) 색상을 바꾼다(tint, "toHue", "satScale", "valScale"). 모양은 그대로 두고 색만 실물에 맞출 때 쓴다.
- rim: 스티커 흰 테 지우기. 투명 바탕에서 시작해 밝고 채도 낮은 픽셀(흰 테와 그 밑 회색 그림자)만 따라가며 지운다.
  진갈색 외곽선에서 멈추므로 외곽선 안의 흰 면은 남는다.

미리 보기 build/word-art-clean/{이름}.png: 왼쪽은 원래 투명본(지운 점은 빨간 원, 지킨 점은 초록 원), 오른쪽은 결과.
둘 다 푸른 바둑판 위라 남은 테와 지운 자리가 보인다.

필요: Pillow (tools/requirements.txt)
"""
import argparse
import colorsys
import json
import sys
from collections import Counter, deque
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "tools" / "word_art_clean.json"
SOURCE = ROOT / "docs" / "design" / "word-art" / "source"
CAND = SOURCE / "candidates"
PREVIEW = ROOT / "build" / "word-art-clean"

DOT_MAX = 0.045        # 점 지름 상한(그림 변에 대한 비율)
DOT_MIN_PX = 4         # 이보다 작은 덩어리는 가장자리 섞임으로 본다
DOT_FILL = 0.45        # 덩어리 넓이 / 경계 상자 넓이 하한(둥글게 찬 것)
SAT_MIN, VAL_MIN = 0.55, 0.45
ORANGE = (8, 45)       # 이 색상 범위(도)는 점으로 보지 않는다(튀김, 소스, 새우, 연어알의 주황)
HUE_JOIN = 30          # 색상이 이만큼(도) 넘게 다른 이웃 픽셀은 다른 덩어리로 본다(파 고리에 붙은 보라 점을 떼어 낸다)
GROW = 3               # 점 가장자리 섞인 픽셀까지 메우려고 넓히는 폭(px)
RING = 6               # 메울 색을 고르는 둘레 고리 폭(px)
DARK = 60              # 이보다 어두운 픽셀은 외곽선으로 보고 메우지 않는다
ISOLATION = 70         # 점 평균색과 둘레 색의 거리(RGB)가 이보다 가까우면 점으로 보지 않는다
RIM_MIN, RIM_SPREAD = 140, 45   # 흰 테: 가장 어두운 채널 >= 140, 채널 차이 <= 45


def vivid_mask(img: Image.Image) -> tuple[bytearray, list[float]]:
    w, h = img.size
    mask = bytearray(w * h)
    hues = [0.0] * (w * h)
    for i, (r, g, b, a) in enumerate(img.get_flattened_data()):
        if a < 200:
            continue
        hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        deg = hh * 360
        if s >= SAT_MIN and v >= VAL_MIN and not (ORANGE[0] <= deg < ORANGE[1]):
            mask[i] = 1
            hues[i] = deg
    return mask, hues


def hue_gap(a: float, b: float) -> float:
    d = abs(a - b) % 360
    return min(d, 360 - d)


def components(mask: bytearray, w: int, h: int, hues: list[float]) -> list[list[int]]:
    seen = bytearray(len(mask))
    out = []
    for start, m in enumerate(mask):
        if not m or seen[start]:
            continue
        seen[start] = 1
        queue, cells = deque([start]), []
        while queue:
            p = queue.popleft()
            cells.append(p)
            x, y = p % w, p // w
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        q = ny * w + nx
                        if mask[q] and not seen[q] and hue_gap(hues[p], hues[q]) <= HUE_JOIN:
                            seen[q] = 1
                            queue.append(q)
        out.append(cells)
    return out


def disc(cx: float, cy: float, r: float, w: int, h: int) -> list[int]:
    out = []
    for y in range(max(0, int(cy - r)), min(h, int(cy + r) + 1)):
        for x in range(max(0, int(cx - r)), min(w, int(cx + r) + 1)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                out.append(y * w + x)
    return out


def grow(cells: list[int], by: int, w: int, h: int) -> set[int]:
    region = set(cells)
    edge = set(cells)
    for _ in range(by):
        nxt = set()
        for p in edge:
            x, y = p % w, p // w
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    q = ny * w + nx
                    if q not in region:
                        nxt.add(q)
        region |= nxt
        edge = nxt
    return region


def ring_color(region: set[int], px: list, w: int, h: int) -> tuple | None:
    """region 둘레 RING px 고리에서 가장 흔한 색(불투명 픽셀만). 외곽선(어두운 색)은 다른 색이 있으면 뺀다."""
    outer = grow(list(region), RING, w, h) - region
    colors = [px[p] for p in outer if px[p][3] > 200]
    if not colors:
        return None
    light = [c for c in colors if (c[0] * 299 + c[1] * 587 + c[2] * 114) / 1000 > 70]
    pool = light if len(light) >= len(colors) * 0.25 else colors
    buckets = Counter((c[0] // 12, c[1] // 12, c[2] // 12) for c in pool)
    key = buckets.most_common(1)[0][0]
    members = [c for c in pool if (c[0] // 12, c[1] // 12, c[2] // 12) == key]
    n = len(members)
    return tuple(round(sum(c[k] for c in members) / n) for k in range(3)) + (255,)


def find_dots(img: Image.Image, keep: list) -> tuple[list, list]:
    w, h = img.size
    mask, hues = vivid_mask(img)
    limit = DOT_MAX * w
    dots, kept = [], []
    for cells in components(mask, w, h, hues):
        if len(cells) < DOT_MIN_PX:
            continue
        xs = [p % w for p in cells]
        ys = [p // w for p in cells]
        bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
        if max(bw, bh) > limit or len(cells) / (bw * bh) < DOT_FILL or max(bw, bh) > 2.2 * min(bw, bh):
            continue
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        spot = (round(cx), round(cy), round(max(bw, bh) / 2), round(sum(hues[p] for p in cells) / len(cells)))
        if any((cx - kx) ** 2 + (cy - ky) ** 2 <= kr * kr for kx, ky, kr in keep):
            kept.append((spot, cells))
        else:
            dots.append((spot, cells))
    return dots, kept


def strip_rim(img: Image.Image) -> tuple[Image.Image, int]:
    w, h = img.size
    px = list(img.get_flattened_data())

    def rimlike(c):
        r, g, b, a = c
        return a > 0 and min(r, g, b) >= RIM_MIN and max(r, g, b) - min(r, g, b) <= RIM_SPREAD

    seen = bytearray(w * h)
    queue = deque(p for p in range(w * h) if px[p][3] == 0)
    for p in queue:
        seen[p] = 1
    removed = 0
    out = px[:]
    while queue:
        p = queue.popleft()
        x, y = p % w, p // w
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                q = ny * w + nx
                if not seen[q]:
                    seen[q] = 1
                    if rimlike(px[q]):
                        out[q] = (0, 0, 0, 0)
                        removed += 1
                        queue.append(q)
    res = Image.new("RGBA", (w, h))
    res.putdata(out)
    return res, removed


def nearest_fill(px: list, holes: set[int], w: int, h: int) -> None:
    """구멍의 픽셀마다 가장 가까운 구멍 밖 픽셀의 색을 넣는다(가장자리에서 안으로 번지는 BFS).
    점이 면 경계(면과 국물, 김과 면)에 걸쳐 있어도 양쪽 면이 각자 이어져 메워진다. 투명도도 같이 옮긴다."""
    # 외곽선(어두운 픽셀)은 구멍에서 빼서 그대로 두고, 메울 색도 외곽선이 아닌 이웃에서 가져온다.
    # 그래야 점 옆을 지나는 외곽선·석쇠 자국이 구멍 안으로 번지지 않는다.
    holes = {p for p in holes if lum(px[p]) >= DARK or px[p][3] < 200}
    queue = deque()
    color = {}
    for p in holes:
        x, y = p % w, p // w
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                q = ny * w + nx
                if q not in holes and lum(px[q]) >= DARK:
                    color[p] = px[q]
                    queue.append(p)
                    break
    while queue:
        p = queue.popleft()
        x, y = p % w, p // w
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                q = ny * w + nx
                if q in holes and q not in color:
                    color[q] = color[p]
                    queue.append(q)
    for p, c in color.items():
        px[p] = c


def lum(c: tuple) -> float:
    return (c[0] * 299 + c[1] * 587 + c[2] * 114) / 1000


def hex_rgba(value: str) -> tuple:
    v = value.lstrip("#")
    return tuple(int(v[k:k + 2], 16) for k in (0, 2, 4)) + (255,)


def clean(name: str, spec: dict) -> tuple[Image.Image, Image.Image, list[str], list, list, list]:
    src = Image.open(CAND / "cut" / f"{spec['candidate']}.png").convert("RGBA")
    img = src.copy()
    w, h = img.size
    log = []
    if spec.get("rim"):
        img, n = strip_rim(img)
        log.append(f"스티커 흰 테 지움({n}px)")
    dots, kept = find_dots(img, spec.get("keep", [])) if spec.get("dots") else ([], [])
    px = list(img.get_flattened_data())
    found = []
    holes: set[int] = set()
    for spot, cells in dots:
        region = grow(cells, GROW, w, h)
        color = ring_color(region, px, w, h)
        if not color:
            continue
        # 둘레와 색이 비슷하면 점이 아니라 넓은 면의 조각(같은 색 면이 색상 경계로 끊긴 것)이다.
        mean = [sum(px[p][k] for p in cells) / len(cells) for k in range(3)]
        if sum((mean[k] - color[k]) ** 2 for k in range(3)) ** 0.5 < ISOLATION:
            continue
        holes |= region
        found.append((spot, cells))
    dots = found
    manual = []
    # 색 범위로 고르는 손질: stripes는 고른 픽셀을 구멍으로 메우고(참치의 흰 줄), tint는 색상을 바꾼다(연어색 → 붉은 참치).
    # {"hue": [최소, 최대], "sat": [최소, 최대], "val": [최소, 최대]} 안의 불투명 픽셀만.
    def pick(rule):
        out = []
        for p, (r, g, b, a) in enumerate(px):
            if a < 200:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            lo, hi = rule.get("hue", [0, 360])
            if lo <= hh * 360 <= hi and rule.get("sat", [0, 1])[0] <= ss <= rule.get("sat", [0, 1])[1] \
                    and rule.get("val", [0, 1])[0] <= vv <= rule.get("val", [0, 1])[1]:
                out.append(p)
        return out
    stripe_count = 0
    for rule in spec.get("stripes", []):
        cells = pick(rule)
        holes |= grow(cells, 1, w, h)
        stripe_count += len(cells)
    for x, y, r in spec.get("fill", []):
        holes |= set(disc(x, y, r, w, h))
        manual.append((x, y, r))
    nearest_fill(px, holes, w, h)
    tint_count = 0
    for rule in spec.get("tint", []):
        for p in pick(rule):
            r, g, b, a = px[p]
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            nr, ng, nb = colorsys.hsv_to_rgb(rule["toHue"] / 360, min(1, ss * rule.get("satScale", 1)),
                                              min(1, vv * rule.get("valScale", 1)))
            px[p] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
            tint_count += 1
    # 큰 얼룩이 외곽선에 걸친 경우: 한 색으로 칠하고(paint), 바깥을 지우고(clear), 외곽선을 다시 긋는다(line).
    for op in spec.get("paint", []):
        x, y, r = op["disc"]
        color = px[op["sample"][1] * w + op["sample"][0]] if "sample" in op else hex_rgba(op["color"])
        for p in disc(x, y, r, w, h):
            px[p] = color
        manual.append((x, y, r))
    img.putdata(px)
    draw = ImageDraw.Draw(img)
    for poly in spec.get("clear", []):
        draw.polygon([tuple(v) for v in poly], fill=(0, 0, 0, 0))
    for op in spec.get("line", []):
        pts = [tuple(v) for v in op["points"]]
        draw.line(pts, fill=hex_rgba(op.get("color", "#2A1012")), width=op["width"], joint="curve")
        r = op["width"] / 2
        for x, y in (pts[0], pts[-1]):
            draw.ellipse((x - r, y - r, x + r, y + r), fill=hex_rgba(op.get("color", "#2A1012")))
    if dots:
        log.append("색 점 %d개 메움(자동): %s" % (len(dots), ", ".join(f"({x},{y}) {hue}°" for (x, y, r, hue), _ in dots)))
    if manual:
        log.append("얼룩 %d곳 메움(좌표): %s" % (len(manual), ", ".join(f"({x},{y},r{r})" for x, y, r in manual)))
    if stripe_count:
        log.append(f"색 범위로 고른 줄무늬 {stripe_count}px 메움")
    if tint_count:
        log.append(f"색 바꿈 {tint_count}px")
    if spec.get("line"):
        log.append("외곽선 %d줄 다시 그음" % len(spec["line"]))
    if kept:
        log.append("지키고 남긴 점 %d개" % len(kept))
    return src, img, log, [d[0] for d in dots], [k[0] for k in kept], manual


def checker(w: int, h: int) -> Image.Image:
    im = Image.new("RGBA", (w, h), (200, 212, 224, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, h, 24):
        for x in range(0, w, 24):
            if (x // 24 + y // 24) % 2:
                d.rectangle((x, y, x + 23, y + 23), fill=(150, 168, 186, 255))
    return im


def preview(name: str, before: Image.Image, after: Image.Image, dots, kept, manual) -> Path:
    w, h = before.size
    sheet = Image.new("RGBA", (w * 2, h))
    left = checker(w, h)
    left.alpha_composite(before)
    d = ImageDraw.Draw(left)
    for x, y, r, _ in dots:
        d.ellipse((x - r - 8, y - r - 8, x + r + 8, y + r + 8), outline=(230, 0, 0, 255), width=3)
    for x, y, r in manual:
        d.ellipse((x - r - 4, y - r - 4, x + r + 4, y + r + 4), outline=(230, 0, 0, 255), width=3)
    for x, y, r, _ in kept:
        d.ellipse((x - r - 8, y - r - 8, x + r + 8, y + r + 8), outline=(0, 170, 0, 255), width=3)
    right = checker(w, h)
    right.alpha_composite(after)
    sheet.paste(left, (0, 0))
    sheet.paste(right, (w, 0))
    PREVIEW.mkdir(parents=True, exist_ok=True)
    out = PREVIEW / f"{name}.png"
    sheet.convert("RGB").save(out)
    return out


def apply(name: str, spec: dict, img: Image.Image, log: list[str]) -> None:
    dst = SOURCE / f"word-{name}.png"
    img.save(dst, optimize=True)
    meta = json.loads((CAND / f"{spec['candidate']}.json").read_text())
    meta["selected"] = {
        "candidate": f"candidates/{spec['candidate']}.png",
        "cut": "tools/remove_bg.py",
        "clean": "tools/clean_word_art.py (tools/word_art_clean.json)",
        "date": date.today().isoformat(),
    }
    if log:
        meta["selected"]["retouch"] = "; ".join(log)
    if spec.get("note"):
        meta["selected"]["note"] = spec["note"]
    dst.with_suffix(".json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("names", nargs="*", help="word_art_clean.json의 단어 이름")
    p.add_argument("--all", action="store_true")
    p.add_argument("--apply", action="store_true", help="source/word-{이름}.png로 확정")
    a = p.parse_args()
    config = {k: v for k, v in json.loads(CONFIG.read_text()).items() if not k.startswith("_")}
    names = list(config) if a.all else a.names
    if not names:
        p.print_help()
        return 2
    unknown = [n for n in names if n not in config]
    if unknown:
        print(f"word_art_clean.json에 없는 이름: {unknown}", file=sys.stderr)
        return 2
    for name in names:
        spec = config[name]
        before, after, log, dots, kept, manual = clean(name, spec)
        out = preview(name, before, after, dots, kept, manual)
        if a.apply:
            apply(name, spec, after, log)
        print(f"{name:12} {spec['candidate']:30} {'확정' if a.apply else '미리 보기'} {out.relative_to(ROOT)}")
        for line in log:
            print(f"  - {line}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
