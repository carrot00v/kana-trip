#!/usr/bin/env python3
"""단색 바탕 위에 그린 아이템 그림에서 바탕을 지워 투명 PNG로 만든다.

그림 가장자리에서 시작해 바탕색과 비슷한 픽셀만 따라가며 지우므로,
진갈색 외곽선 안쪽(아이템의 흰 면 등)은 바탕과 색이 비슷해도 지워지지 않는다.
지운 영역 바로 옆의 애매한 픽셀은 반투명으로 두고 바탕색을 빼서, 다크 바탕에서도 회색 테가 남지 않게 한다.

실행: .venv/bin/python tools/remove_bg.py 입력.png 출력.png [허용차 기본 40] [--outline]
  --outline: 모델이 외곽선 밖에 흰 스티커 테를 그린 그림(2026-11-18 tenugui 7831~7833)에서, 가장 바깥 진한 외곽선
             밖의 남은 픽셀(흰 테, 떨어진 조각)을 지운다. 외곽선 안쪽은 건드리지 않는다.
필요: Pillow (tools/requirements.txt)
"""
import sys
from collections import deque
from statistics import median

from PIL import Image


def remove_bg(src: Image.Image, hard: float = 40, bg: tuple | None = None) -> tuple[Image.Image, tuple, float]:
    """bg를 주면 그 색을 바탕으로 쓴다(땅 띠가 아래 변을 다 차지하는 풍경처럼 네 변 중앙값이 바탕이 아닐 때)."""
    soft = hard * 1.8  # 이 거리까지는 반투명으로 가장자리를 부드럽게
    img = src.convert("RGB")
    w, h = img.size
    px = list(img.get_flattened_data())

    # 바탕색: 네 변 픽셀의 중앙값
    if bg is None:
        border = [px[y * w + x] for x in range(0, w, 4) for y in (0, h - 1)]
        border += [px[y * w + x] for y in range(0, h, 4) for x in (0, w - 1)]
        bg = tuple(median(c[i] for c in border) for i in range(3))

    hard2, soft2 = hard * hard, soft * soft
    d2 = [(r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2 for r, g, b in px]

    alpha = bytearray(b"\xff" * (w * h))
    seen = bytearray(w * h)
    queue = deque()
    for x in range(w):
        queue.extend((x, (h - 1) * w + x))
    for y in range(h):
        queue.extend((y * w, y * w + w - 1))
    removed = 0
    while queue:
        p = queue.pop()
        if seen[p]:
            continue
        seen[p] = 1
        d = d2[p]
        if d < hard2:
            alpha[p] = 0
            removed += 1
            x = p % w
            if x > 0:
                queue.append(p - 1)
            if x < w - 1:
                queue.append(p + 1)
            if p >= w:
                queue.append(p - w)
            if p < (h - 1) * w:
                queue.append(p + w)
        elif d < soft2:
            alpha[p] = int(255 * (d ** 0.5 - hard) / (soft - hard))

    out = []
    for p, (r, g, b) in enumerate(px):
        a = alpha[p]
        if a == 0:
            out.append((0, 0, 0, 0))
        elif a == 255:
            out.append((r, g, b, 255))
        else:
            # 반투명 가장자리: 바탕색이 섞인 만큼 빼서 원래 색을 되살린다
            f = a / 255
            un = [min(255, max(0, round((c - k * (1 - f)) / f))) for c, k in zip((r, g, b), bg)]
            out.append((*un, a))
    result = Image.new("RGBA", (w, h))
    result.putdata(out)
    return result, bg, removed / (w * h)


def keep_inside_outline(img: Image.Image, dark: int = 110) -> tuple[Image.Image, float]:
    """가장 바깥 진한 외곽선(max(r, g, b) < dark) 밖을 투명으로. 투명한 바깥에서 시작해 진하지 않은 픽셀만 따라가며
    지우므로 외곽선 안쪽은 남는다. (결과, 지운 불투명 픽셀 비율)."""
    img = img.convert("RGBA")
    w, h = img.size
    px = list(img.get_flattened_data())
    passable = bytearray(1 if (a < 128 or max(r, g, b) >= dark) else 0 for r, g, b, a in px)
    seen = bytearray(w * h)
    queue = deque(p for p in range(w * h) if px[p][3] < 128)
    for p in queue:
        seen[p] = 1
    removed = 0
    while queue:
        p = queue.pop()
        if px[p][3] >= 128:
            removed += 1
        x = p % w
        for q in (p - 1 if x > 0 else -1, p + 1 if x < w - 1 else -1, p - w, p + w):
            if 0 <= q < w * h and not seen[q] and passable[q]:
                seen[q] = 1
                queue.append(q)
    out = [(0, 0, 0, 0) if seen[p] else px[p] for p in range(w * h)]
    result = Image.new("RGBA", (w, h))
    result.putdata(out)
    opaque = sum(1 for c in px if c[3] >= 128)
    return result, removed / opaque if opaque else 0


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--outline"]
    if len(args) < 2:
        print("usage: remove_bg.py 입력.png 출력.png [허용차] [--outline]", file=sys.stderr)
        return 2
    hard = float(args[2]) if len(args) > 2 else 40
    result, bg, ratio = remove_bg(Image.open(args[0]), hard)
    print(f"바탕 rgb({bg[0]:.0f},{bg[1]:.0f},{bg[2]:.0f}), 지운 비율 {ratio * 100:.0f}%")
    if "--outline" in sys.argv:
        result, extra = keep_inside_outline(result)
        print(f"외곽선 밖 테 지움: 남은 불투명 픽셀의 {extra * 100:.1f}%")
    result.save(args[1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
