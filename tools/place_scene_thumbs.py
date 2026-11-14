#!/usr/bin/env python3
"""홈 장면 그림을 정확한 칸 색으로 칠하고 앱 에셋 카탈로그에 넣는다 (docs/design/scene-art/brief.md 7번 2~3단계).

입력: docs/design/scene-art/source/thumb-{id}.png (1024×1024, 사람이 고른 그림)
출력: KanaTrip/Assets.xcassets/SceneThumb-{id}.imageset/ 의 @2x(104px), @3x(156px) PNG와 Contents.json
      (Render As = Original. 확인용 비교 시트는 --sheet 경로에)

처리:
  1. 네 변 픽셀의 중앙값을 생성 때의 바탕색으로 본다.
  2. 가장자리에서 시작해 바탕색과 가까운(허용차 안) 픽셀만 따라가며 바탕으로 표시한다(tools/remove_bg.py와 같은 방식).
  3. 칸색이 바뀐 그림(brief.md 7.1: tonkatsu, shrine)은 외곽선에 갇힌 바탕 조각도 칠한다:
     그림 전체에서 생성 때의 바탕색과 가까운 픽셀 덩어리를 찾아 바탕으로 표시한다.
     작은 점(MIN_TRAPPED 픽셀 미만)은 물건의 일부일 수 있어 건드리지 않는다.
  4. 바탕은 정확한 칸 색(SKY #CFE6F2, SAND #F3E4C8)으로 칠하고, 바탕 바로 옆의 섞인 픽셀은
     생성 때의 바탕색을 빼고 새 칸 색을 섞어 테가 남지 않게 한다. 결과는 불투명하다.
  5. 156px, 104px로 줄인다(LANCZOS).

실행: .venv/bin/python tools/place_scene_thumbs.py [--sheet 비교시트.png]
필요: Pillow (tools/requirements.txt)
"""
import argparse
import json
import sys
from collections import deque
from pathlib import Path
from statistics import median

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs/design/scene-art/source"
CATALOG = ROOT / "KanaTrip/Assets.xcassets"

SKY = (0xCF, 0xE6, 0xF2)
SAND = (0xF3, 0xE4, 0xC8)

# 장면 id → (칸 색, 칸색이 생성 때와 달라졌는지). brief.md 5번 표, 5.1 표.
SCENES = {
    "placeholder": (SAND, False),
    "sushi": (SKY, False),
    "tonkatsu": (SAND, True),
    "soba": (SKY, False),
    "station": (SAND, False),
    "shrine": (SKY, True),
    "izakaya": (SAND, False),
    "onsen": (SKY, False),
    "ryokan": (SAND, False),
}

HARD = 40  # 이 거리 안이면 바탕
SOFT = HARD * 1.8  # 바탕 바로 옆에서 이 거리 안이면 바탕이 섞인 가장자리
MIN_TRAPPED = 200  # 갇힌 조각으로 칠할 최소 크기(1024px 원본의 픽셀 수)
SIZES = {"2x": 104, "3x": 156}


def dist2(c, k):
    return (c[0] - k[0]) ** 2 + (c[1] - k[1]) ** 2 + (c[2] - k[2]) ** 2


def neighbors(p, w, h):
    x = p % w
    if x > 0:
        yield p - 1
    if x < w - 1:
        yield p + 1
    if p >= w:
        yield p - w
    if p < (h - 1) * w:
        yield p + w


def flood(seeds, is_bg, w, h, mask):
    """seeds에서 시작해 is_bg인 픽셀을 따라가며 mask에 1을 칠한다. 칠한 픽셀 목록을 돌려준다."""
    queue = deque(seeds)
    members = []
    while queue:
        p = queue.pop()
        if mask[p] or not is_bg[p]:
            continue
        mask[p] = 1
        members.append(p)
        queue.extend(n for n in neighbors(p, w, h) if not mask[n] and is_bg[n])
    return members


def recolor(src: Image.Image, cell: tuple, fill_trapped: bool):
    img = src.convert("RGB")
    w, h = img.size
    px = list(img.get_flattened_data())

    border = [px[y * w + x] for x in range(0, w, 4) for y in (0, h - 1)]
    border += [px[y * w + x] for y in range(0, h, 4) for x in (0, w - 1)]
    bg = tuple(median(c[i] for c in border) for i in range(3))

    d2 = [dist2(c, bg) for c in px]
    is_bg = bytearray(1 if d < HARD * HARD else 0 for d in d2)
    mask = bytearray(w * h)
    edge_seeds = [x for x in range(w)] + [(h - 1) * w + x for x in range(w)]
    edge_seeds += [y * w for y in range(h)] + [y * w + w - 1 for y in range(h)]
    outer = len(flood(edge_seeds, is_bg, w, h, mask))

    trapped_pieces = []
    if fill_trapped:
        seen = bytearray(mask)
        for p in range(w * h):
            if is_bg[p] and not seen[p]:
                members = flood([p], is_bg, w, h, seen)
                if len(members) >= MIN_TRAPPED:
                    for q in members:
                        mask[q] = 1
                    xs = [q % w for q in members]
                    ys = [q // w for q in members]
                    trapped_pieces.append((len(members), (min(xs), min(ys), max(xs), max(ys))))

    out = []
    soft2 = SOFT * SOFT
    for p, c in enumerate(px):
        if mask[p]:
            out.append(cell)
            continue
        d = d2[p]
        if d < soft2 and any(mask[n] for n in neighbors(p, w, h)):
            # 바탕이 섞인 가장자리: 섞인 비율만큼 생성 때의 바탕색을 빼고 새 칸 색을 섞는다.
            f = (d ** 0.5 - HARD) / (SOFT - HARD)
            f = min(1.0, max(0.05, f))
            fg = [min(255, max(0, round((v - k * (1 - f)) / f))) for v, k in zip(c, bg)]
            out.append(tuple(round(fv * f + cv * (1 - f)) for fv, cv in zip(fg, cell)))
        else:
            out.append(c)
    result = Image.new("RGB", (w, h))
    result.putdata(out)
    return result, bg, outer / (w * h), trapped_pieces


def write_imageset(name: str, image: Image.Image):
    folder = CATALOG / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    images = [{"idiom": "universal", "scale": "1x"}]
    for scale, size in SIZES.items():
        file = f"{name}@{scale}.png"
        image.resize((size, size), Image.Resampling.LANCZOS).save(folder / file, optimize=True)
        images.append({"filename": file, "idiom": "universal", "scale": scale})
    contents = {
        "images": images,
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--sheet", type=Path, help="156px 결과와 흑백(잠김)을 나란히 놓은 확인용 시트 경로")
    parser.add_argument("--full-size", type=Path, help="칸색으로 칠한 원본 크기 그림을 이 폴더에 thumb-{id}.png로 저장 (장면 Lottie 입력용)")
    args = parser.parse_args()

    CATALOG.mkdir(exist_ok=True)
    root_contents = CATALOG / "Contents.json"
    if not root_contents.exists():
        root_contents.write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

    results = []
    for sid, (cell, changed) in SCENES.items():
        src = SOURCE / f"thumb-{sid}.png"
        if not src.exists():
            print(f"{sid}: {src.name} 없음, 건너뜀")
            continue
        image, bg, ratio, trapped = recolor(Image.open(src), cell, changed)
        write_imageset(f"SceneThumb-{sid}", image)
        if args.full_size:
            args.full_size.mkdir(parents=True, exist_ok=True)
            image.save(args.full_size / f"thumb-{sid}.png")
        results.append((sid, image))
        line = f"{sid}: 생성 때 바탕 rgb({bg[0]:.0f},{bg[1]:.0f},{bg[2]:.0f}) → #{''.join(f'{v:02X}' for v in cell)}, 가장자리 바탕 {ratio * 100:.0f}%"
        if changed:
            line += f", 갇힌 조각 {len(trapped)}개 칠함" + "".join(f"\n    {n}px 범위 {box}" for n, box in trapped)
        print(line)

    if args.sheet and results:
        side, gap = SIZES["3x"], 12
        sheet = Image.new("RGB", (gap + len(results) * (side + gap), gap * 3 + side * 2), (255, 255, 255))
        for i, (_, image) in enumerate(results):
            small = image.resize((side, side), Image.Resampling.LANCZOS)
            sheet.paste(small, (gap + i * (side + gap), gap))
            sheet.paste(small.convert("L").convert("RGB"), (gap + i * (side + gap), gap * 2 + side))
        sheet.save(args.sheet)
        print(f"비교 시트: {args.sheet}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
