#!/usr/bin/env python3
"""장면 그림 하나를 Lottie JSON 하나로 만든다(정지 그림 + 김 셰이프 레이어).

    python3 tools/build_scene_lottie.py 칸색으로_칠한_장면그림.png KanaTrip/Resources/scene_{장면 id}.lottie.json

- 입력은 홈 장면 그림과 같은 칸색으로 칠한 원본이다(`place_scene_thumbs.py --full-size`).

- 김을 지운 PNG(`prep_steam_layer.prepare`)를 base64로 임베드한다(`"e": 1`).
- 김 세 줄은 셰이프 레이어. 경로 키프레임(S자 흔들림), 위치(오름), 불투명도(나타났다 옅어짐)만 쓴다.
  표현식, 트림, 효과, 마스크는 쓰지 않는다(lottie-ios와 lottie-android 공통 기능만).
- 한 주기 2.6초, 30fps. 줄마다 1/3 주기씩 엇갈린다. 마지막 프레임 = 첫 프레임이라 반복이 끊기지 않는다.
- 앱이 쓰는 값(바탕색, 동작 줄이기 때 멈출 프레임)은 최상위 "kt" 키와 마커 "still"에 넣는다.
  Lottie 재생기는 모르는 키를 무시한다.
"""

import base64
import json
import math
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prep_steam_layer import prepare  # noqa: E402

# 그림(=캔버스) 변 길이. 카드 높이 180pt @3x = 540px보다 조금 크게.
CANVAS = 768
FPS = 30
PERIOD_SECONDS = 2.6
FRAMES = round(PERIOD_SECONDS * FPS)  # 78
# 줄 사이 위상차: 1/3 주기. FRAMES가 3의 배수라 정수 프레임에 떨어진다.
LINE_OFFSET_FRAMES = FRAMES // 3
# 키프레임 간격(프레임).
SAMPLE_STEP = 2
# 한 주기 동안 오르는 거리(캔버스 변 비율). 원래 그림 자리에 오는 주기 위치.
RISE_DISTANCE = 0.05
RESTING_PROGRESS = 0.4
# S자 굽이가 옮겨 가는 폭(라디안).
SWAY = 0.6
# 원래 그림의 선은 아래 끝에서 오른쪽으로 나갔다가 왼쪽으로 돈다.
BASE_PHASE = 0.35
# 경로 꼭짓점 수(베지어).
VERTICES = 9
LINE_COLOR = (0x4A, 0x22, 0x19)


def smoothstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def progress(frame, index):
    return ((frame + index * LINE_OFFSET_FRAMES) % FRAMES) / FRAMES


def opacity(p):
    return smoothstep(0, 0.25, p) * (1 - smoothstep(0.6, 1, p))


def line_params(steam):
    xs = [c[0] for c in steam["centerline"]]
    ys = [c[1] for c in steam["centerline"]]
    return {
        "cx": (min(xs) + max(xs)) / 2,
        "amp": (max(xs) - min(xs)) / 2,
        "top": min(ys),
        "bottom": max(ys),
    }


def bezier_path(line, sway):
    """아래 끝(s=0)에서 위 끝(s=1)까지 S자. Catmull-Rom으로 베지어 핸들을 만든다."""
    pts = []
    for k in range(VERTICES):
        s = k / (VERTICES - 1)
        y = line["bottom"] + (line["top"] - line["bottom"]) * s
        x = line["cx"] + line["amp"] * math.sin(2 * math.pi * s + BASE_PHASE + sway)
        pts.append((x * CANVAS, y * CANVAS))
    ins, outs = [], []
    for k, p in enumerate(pts):
        prev = pts[max(k - 1, 0)]
        nxt = pts[min(k + 1, len(pts) - 1)]
        span = 6 if 0 < k < len(pts) - 1 else 3
        tx, ty = (nxt[0] - prev[0]) / span, (nxt[1] - prev[1]) / span
        outs.append([round(tx, 2), round(ty, 2)])
        ins.append([round(-tx, 2), round(-ty, 2)])
    return {"i": ins, "o": outs, "v": [[round(x, 2), round(y, 2)] for x, y in pts], "c": False}


LINEAR_OUT = {"x": [0], "y": [0]}
LINEAR_IN = {"x": [1], "y": [1]}


def keyframes(values_at, index):
    """0..FRAMES를 SAMPLE_STEP 간격으로 샘플. 주기가 끊기는(진행도가 1에서 0으로 돌아가는) 곳 바로 앞은
    hold로 두어 사이를 보간하지 않는다. 그 순간은 불투명도가 0이라 보이지 않는다."""
    frames = list(range(0, FRAMES + 1, SAMPLE_STEP))
    out = []
    for n, f in enumerate(frames):
        kf = {"t": f, "s": values_at(f)}
        if n < len(frames) - 1:
            nxt = frames[n + 1]
            if progress(nxt, index) < progress(f, index):
                kf["h"] = 1
            else:
                kf["o"] = LINEAR_OUT
                kf["i"] = LINEAR_IN
        out.append(kf)
    return out


def steam_layer(line, index, stroke_width, layer_index, line_color=LINE_COLOR):
    def path_at(f):
        return [bezier_path(line, SWAY * math.sin(2 * math.pi * progress(f, index)))]

    def position_at(f):
        return [0, round(RISE_DISTANCE * CANVAS * (RESTING_PROGRESS - progress(f, index)), 2), 0]

    def opacity_at(f):
        return [round(100 * opacity(progress(f, index)), 2)]

    color = [round(c / 255, 4) for c in line_color] + [1]
    return {
        "ddd": 0, "ind": layer_index, "ty": 4, "nm": f"steam {index + 1}", "sr": 1,
        "ks": {
            "o": {"a": 1, "k": keyframes(opacity_at, index)},
            "r": {"a": 0, "k": 0},
            "p": {"a": 1, "k": keyframes(position_at, index)},
            "a": {"a": 0, "k": [0, 0, 0]},
            "s": {"a": 0, "k": [100, 100, 100]},
        },
        "ao": 0,
        "shapes": [{
            "ty": "gr", "nm": "line",
            "it": [
                {"ty": "sh", "nm": "path", "ks": {"a": 1, "k": keyframes(path_at, index)}},
                {"ty": "st", "nm": "stroke", "c": {"a": 0, "k": color}, "o": {"a": 0, "k": 100},
                 "w": {"a": 0, "k": round(stroke_width * CANVAS, 2)}, "lc": 2, "lj": 2},
                {"ty": "tr", "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]},
                 "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0},
                 "o": {"a": 0, "k": 100}, "sk": {"a": 0, "k": 0}, "sa": {"a": 0, "k": 0}},
            ],
        }],
        "ip": 0, "op": FRAMES, "st": 0, "bm": 0,
    }


def still_frame(count):
    """동작 줄이기 때 멈출 프레임: 가장 옅은 줄이 가장 진한 프레임."""
    return max(range(FRAMES), key=lambda f: min(opacity(progress(f, i)) for i in range(count)))


def main():
    if len(sys.argv) != 3:
        raise SystemExit("사용법: build_scene_lottie.py 원본.png 출력.json")
    src, dst = sys.argv[1], sys.argv[2]

    with tempfile.TemporaryDirectory() as tmp:
        png = os.path.join(tmp, "steamless.png")
        info = prepare(src, png, size=CANVAS)
        with open(png, "rb") as f:
            image_data = base64.b64encode(f.read()).decode("ascii")

    lines = [line_params(s) for s in info["steam"]]
    stroke = sum(s["strokeWidth"] for s in info["steam"]) / len(info["steam"])
    still = still_frame(len(lines))

    # 김 색: 외곽선으로 그린 김은 진갈색, 옅은 면으로 그린 김(온천)은 그 면의 색 (prep_steam_layer).
    colors = [tuple(int(s["color"][k:k + 2], 16) for k in (1, 3, 5)) for s in info["steam"]]
    layers = [steam_layer(line, i, stroke, i + 1, colors[i]) for i, line in enumerate(lines)]
    layers.append({
        "ddd": 0, "ind": len(layers) + 1, "ty": 2, "nm": "art", "refId": "art", "sr": 1,
        "ks": {
            "o": {"a": 0, "k": 100}, "r": {"a": 0, "k": 0}, "p": {"a": 0, "k": [0, 0, 0]},
            "a": {"a": 0, "k": [0, 0, 0]}, "s": {"a": 0, "k": [100, 100, 100]},
        },
        "ao": 0, "ip": 0, "op": FRAMES, "st": 0, "bm": 0,
    })

    doc = {
        "v": "5.7.0", "fr": FPS, "ip": 0, "op": FRAMES, "w": CANVAS, "h": CANVAS,
        "nm": os.path.splitext(os.path.basename(dst))[0], "ddd": 0,
        "assets": [{"id": "art", "w": CANVAS, "h": CANVAS, "u": "", "p": "data:image/png;base64," + image_data, "e": 1}],
        "layers": layers,
        "markers": [{"tm": still, "cm": "still", "dr": 0}],
        "kt": {"background": info["background"], "stillFrame": still},
    }
    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
    with open(dst, "w") as f:
        json.dump(doc, f, separators=(",", ":"))

    print(json.dumps({
        "output": dst,
        "bytes": os.path.getsize(dst),
        "canvas": CANVAS, "fps": FPS, "frames": FRAMES,
        "background": info["background"],
        "strokeWidthPx": round(stroke * CANVAS, 2),
        "stillFrame": still,
        "lines": lines,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
