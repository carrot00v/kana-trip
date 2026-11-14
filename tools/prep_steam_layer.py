#!/usr/bin/env python3
"""장면 그림에서 그릇 위 김 선을 지우고, 지운 자리를 JSON으로 알려 준다.

시제품용. 김은 SwiftUI(`SteamingSceneArt`)가 Path로 다시 그려 움직인다.

Pillow 없이 돌게 macOS 기본 도구 `sips`로 PNG <-> 24비트 BMP를 오가고,
픽셀 처리는 파이썬 표준 라이브러리로 한다.

    python3 tools/prep_steam_layer.py \
        docs/design/scene-art/source/thumb-eatery_sign_305.png \
        KanaTrip/Resources/scene_eatery_sign_steamless.png

출력(표준 출력, JSON): 그림 크기, 바탕색, 김 선마다 정규화(0~1) 경계 상자와
중심선 점, 선 굵기, 그릇 위 가장자리 높이. Swift 쪽 김 위치는 이 값을 옮겨 적는다.
"""

import json
import os
import struct
import subprocess
import sys
import tempfile
from collections import deque

# 바탕과 얼마나 다르면 그림(선, 색면)으로 보나. RGB 거리.
FOREGROUND_DISTANCE = 40
# 김 선 둘레의 흐린 가장자리(안티에일리어싱)까지 지우려고 마스크를 넓히는 픽셀 수.
MASK_GROW = 4
# 김 선으로 볼 덩어리: 그림 넓이에 대한 최대 비율.
MAX_STEAM_AREA_RATIO = 0.01


def read_bmp(path):
    with open(path, "rb") as f:
        data = f.read()
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    bpp = struct.unpack_from("<H", data, 28)[0]
    if bpp != 24:
        raise SystemExit(f"24비트 BMP만 다룬다: {bpp}")
    top_down = height < 0
    height = abs(height)
    stride = (width * 3 + 3) & ~3
    pixels = [None] * (width * height)
    for row in range(height):
        y = row if top_down else height - 1 - row
        base = offset + row * stride
        line = data[base:base + width * 3]
        for x in range(width):
            b, g, r = line[x * 3], line[x * 3 + 1], line[x * 3 + 2]
            pixels[y * width + x] = (r, g, b)
    return width, height, pixels


def write_bmp(path, width, height, pixels):
    stride = (width * 3 + 3) & ~3
    pad = b"\x00" * (stride - width * 3)
    size = 54 + stride * height
    out = bytearray()
    out += b"BM" + struct.pack("<IHHI", size, 0, 0, 54)
    out += struct.pack("<IiiHHIIiiII", 40, width, -height, 1, 24, 0, stride * height, 2835, 2835, 0, 0)
    for y in range(height):
        row = bytearray()
        for x in range(width):
            r, g, b = pixels[y * width + x]
            row += bytes((b, g, r))
        out += row + pad
    with open(path, "wb") as f:
        f.write(out)


def sips(src, dst, fmt):
    subprocess.run(["sips", "-s", "format", fmt, src, "--out", dst],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def median(values):
    s = sorted(values)
    return s[len(s) // 2]


def background_color(width, height, pixels):
    """테두리 한 줄의 채널별 중앙값."""
    border = []
    for x in range(width):
        border.append(pixels[x])
        border.append(pixels[(height - 1) * width + x])
    for y in range(height):
        border.append(pixels[y * width])
        border.append(pixels[y * width + width - 1])
    return tuple(median([p[i] for p in border]) for i in range(3))


def distance(a, b):
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def components(width, height, mask):
    """4방향 연결 덩어리. (픽셀 목록, 경계 상자)."""
    seen = bytearray(width * height)
    result = []
    for start in range(width * height):
        if not mask[start] or seen[start]:
            continue
        seen[start] = 1
        queue = deque([start])
        members = []
        while queue:
            i = queue.popleft()
            members.append(i)
            x, y = i % width, i // width
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    j = ny * width + nx
                    if mask[j] and not seen[j]:
                        seen[j] = 1
                        queue.append(j)
        xs = [i % width for i in members]
        ys = [i // width for i in members]
        result.append((members, (min(xs), min(ys), max(xs), max(ys))))
    return result


def main():
    if len(sys.argv) != 3:
        raise SystemExit("사용법: prep_steam_layer.py 입력.png 출력.png")
    src, dst = sys.argv[1], sys.argv[2]

    with tempfile.TemporaryDirectory() as tmp:
        bmp_in = os.path.join(tmp, "in.bmp")
        sips(src, bmp_in, "bmp")
        width, height, pixels = read_bmp(bmp_in)

        bg = background_color(width, height, pixels)
        fg = bytearray(1 if distance(p, bg) > FOREGROUND_DISTANCE else 0 for p in pixels)
        blobs = components(width, height, fg)
        blobs.sort(key=lambda c: len(c[0]), reverse=True)

        # 가장 큰 덩어리가 그릇(밥, 돈가스, 젓가락 포함). 그 위쪽에 따로 떨어진 작은 덩어리가 김.
        # 김 끝이 그릇 맨 위(돈가스 꼭대기)보다 살짝 내려올 수 있어 덩어리의 가운데 높이로 가른다.
        bowl_members, bowl_box = blobs[0]
        bowl_top = bowl_box[1]
        max_area = width * height * MAX_STEAM_AREA_RATIO
        steam = [c for c in blobs[1:]
                 if (c[1][1] + c[1][3]) / 2 < bowl_top and len(c[0]) < max_area and (c[1][3] - c[1][1]) > height * 0.04]
        steam.sort(key=lambda c: c[1][0])
        if len(steam) != 3:
            raise SystemExit(f"김 선을 3개 찾지 못했다: {len(steam)}개 {[c[1] for c in steam]}")

        # 지울 마스크: 김 덩어리를 MASK_GROW만큼 넓힌다.
        erase = bytearray(width * height)
        for members, _ in steam:
            for i in members:
                x, y = i % width, i // width
                for dy in range(-MASK_GROW, MASK_GROW + 1):
                    for dx in range(-MASK_GROW, MASK_GROW + 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < width and 0 <= ny < height:
                            erase[ny * width + nx] = 1

        # 채우기: 같은 줄에서 지운 구간 좌우의 바탕 픽셀(각 3픽셀 평균)을 선형 보간한다.
        out = list(pixels)
        for y in range(height):
            x = 0
            while x < width:
                if not erase[y * width + x]:
                    x += 1
                    continue
                start = x
                while x < width and erase[y * width + x]:
                    x += 1
                end = x  # [start, end)
                left = [pixels[y * width + k] for k in range(max(0, start - 3), start)] or [bg]
                right = [pixels[y * width + k] for k in range(end, min(width, end + 3))] or [bg]
                lc = tuple(sum(p[i] for p in left) / len(left) for i in range(3))
                rc = tuple(sum(p[i] for p in right) / len(right) for i in range(3))
                span = end - start + 1
                for k in range(start, end):
                    t = (k - start + 1) / span
                    out[y * width + k] = tuple(int(round(lc[i] + (rc[i] - lc[i]) * t)) for i in range(3))

        bmp_out = os.path.join(tmp, "out.bmp")
        write_bmp(bmp_out, width, height, out)
        os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
        sips(bmp_out, dst, "png")

    # 김 선마다 중심선(줄마다 진한 선 픽셀의 x 평균)과 굵기(가로 연속 길이의 중앙값).
    lines = []
    for members, (x0, y0, x1, y1) in steam:
        rows = {}
        for i in members:
            x, y = i % width, i // width
            if distance(pixels[i], (0x4A, 0x22, 0x19)) < 90:
                rows.setdefault(y, []).append(x)
        runs = []
        for xs in rows.values():
            xs.sort()
            run = 1
            for a, b in zip(xs, xs[1:]):
                if b == a + 1:
                    run += 1
                else:
                    runs.append(run)
                    run = 1
            runs.append(run)
        step = max(1, (y1 - y0) // 12)
        center = []
        for y in range(y0, y1 + 1, step):
            if y in rows:
                xs = rows[y]
                center.append([round(sum(xs) / len(xs) / width, 4), round(y / height, 4)])
        lines.append({
            "box": [round(x0 / width, 4), round(y0 / height, 4), round(x1 / width, 4), round(y1 / height, 4)],
            "centerline": center,
            "strokeWidth": round(median(runs) / width, 4),
        })

    print(json.dumps({
        "source": src,
        "output": dst,
        "size": [width, height],
        "background": "#%02X%02X%02X" % bg,
        "bowlTop": round(bowl_top / height, 4),
        "steamBottom": round(max(l["box"][3] for l in lines), 4),
        "steam": lines,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
