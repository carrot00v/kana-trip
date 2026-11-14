#!/usr/bin/env python3
"""단색 바탕 위에 그린 아이템 그림에서 바탕을 지워 투명 PNG로 만든다.

그림 가장자리에서 시작해 바탕색과 비슷한 픽셀만 따라가며 지우므로,
진갈색 외곽선 안쪽(아이템의 흰 면 등)은 바탕과 색이 비슷해도 지워지지 않는다.
지운 영역 바로 옆의 애매한 픽셀은 반투명으로 두고 바탕색을 빼서, 다크 바탕에서도 회색 테가 남지 않게 한다.

실행: .venv/bin/python tools/remove_bg.py 입력.png 출력.png [허용차 기본 40]
필요: Pillow (tools/requirements.txt)
"""
import sys
from collections import deque
from statistics import median

from PIL import Image


def remove_bg(src: Image.Image, hard: float = 40) -> tuple[Image.Image, tuple, float]:
    soft = hard * 1.8  # 이 거리까지는 반투명으로 가장자리를 부드럽게
    img = src.convert("RGB")
    w, h = img.size
    px = list(img.get_flattened_data())

    # 바탕색: 네 변 픽셀의 중앙값
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


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: remove_bg.py 입력.png 출력.png [허용차]", file=sys.stderr)
        return 2
    hard = float(sys.argv[3]) if len(sys.argv) > 3 else 40
    result, bg, ratio = remove_bg(Image.open(sys.argv[1]), hard)
    result.save(sys.argv[2])
    print(f"바탕 rgb({bg[0]:.0f},{bg[1]:.0f},{bg[2]:.0f}), 지운 비율 {ratio * 100:.0f}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
