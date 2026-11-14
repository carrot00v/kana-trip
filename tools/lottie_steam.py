"""Lottie 김 레이어 (위로 오르는 S자 선). tools/build_word_lottie.py가 쓴다.

장면 진입 김 카드용 `build_scene_lottie.py`(2026-11-15 김 카드를 빼면서 지움)의 김 함수를 옮겨, 캔버스 크기·주기·
줄 수·정지 위상을 인자로 받게 고쳤다 (docs/design/word-art.md 6.2 "김").

- 경로 키프레임(S자 흔들림), 위치(오름), 불투명도(나타났다 옅어짐)만 쓴다.
  표현식, 트림, 효과, 마스크는 쓰지 않는다(lottie-ios와 lottie-android 공통 기능만).
- 마지막 프레임 = 첫 프레임이라 반복이 끊기지 않는다.
- 줄마다 주기 ÷ 줄 수만큼 엇갈린다.
- `still` 위상만큼 앞으로 옮겨 프레임 0이 정지 모습(모든 줄이 보이는 위상)이 되게 한다.
"""

import math

# 키프레임 간격(프레임).
SAMPLE_STEP = 2
# 원래 그림 자리에 오는 주기 위치(오름의 기준).
RESTING_PROGRESS = 0.4
# 선은 아래 끝에서 오른쪽으로 나갔다가 왼쪽으로 돈다.
BASE_PHASE = 0.35
# 경로 꼭짓점 수(베지어).
VERTICES = 9

LINEAR_OUT = {"x": [0], "y": [0]}
LINEAR_IN = {"x": [1], "y": [1]}


def smoothstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def opacity(p):
    """주기의 0~25%에 0 → 1, 60%까지 1, 100%에 0."""
    return smoothstep(0, 0.25, p) * (1 - smoothstep(0.6, 1, p))


class Steam:
    """김 묶음 하나. 좌표는 캔버스 비율(0~1)."""

    def __init__(self, canvas, frames, count, sway, rise, shift=0):
        self.canvas = canvas
        self.frames = frames
        self.count = count
        self.sway = sway
        self.rise = rise
        self.offset = frames / count
        self.shift = shift

    def progress(self, frame, index):
        return ((frame + self.shift + index * self.offset) % self.frames) / self.frames

    def still_shift(self):
        """가장 옅은 줄이 가장 진한 프레임. 이만큼 위상을 옮기면 프레임 0이 정지 모습이 된다."""
        saved, self.shift = self.shift, 0
        best = max(range(self.frames),
                   key=lambda f: min(opacity(self.progress(f, i)) for i in range(self.count)))
        self.shift = saved
        return best

    def bezier_path(self, line, sway):
        """아래 끝(s=0)에서 위 끝(s=1)까지 S자. Catmull-Rom으로 베지어 핸들을 만든다."""
        c = self.canvas
        pts = []
        for k in range(VERTICES):
            s = k / (VERTICES - 1)
            y = line["bottom"] + (line["top"] - line["bottom"]) * s
            x = line["cx"] + line["amp"] * math.sin(2 * math.pi * s + BASE_PHASE + sway)
            pts.append((x * c, y * c))
        ins, outs = [], []
        for k, p in enumerate(pts):
            prev = pts[max(k - 1, 0)]
            nxt = pts[min(k + 1, len(pts) - 1)]
            span = 6 if 0 < k < len(pts) - 1 else 3
            tx, ty = (nxt[0] - prev[0]) / span, (nxt[1] - prev[1]) / span
            outs.append([round(tx, 2), round(ty, 2)])
            ins.append([round(-tx, 2), round(-ty, 2)])
        return {"i": ins, "o": outs, "v": [[round(x, 2), round(y, 2)] for x, y in pts], "c": False}

    def keyframes(self, values_at, index):
        """0..frames를 SAMPLE_STEP 간격으로 샘플. 주기가 끊기는(진행도가 1에서 0으로 돌아가는) 곳 바로 앞은
        hold로 두어 사이를 보간하지 않는다. 그 순간은 불투명도가 0이라 보이지 않는다."""
        frames = list(range(0, self.frames, SAMPLE_STEP)) + [self.frames]
        out = []
        for n, f in enumerate(frames):
            kf = {"t": f, "s": values_at(f)}
            if n < len(frames) - 1:
                nxt = frames[n + 1]
                if self.progress(nxt, index) < self.progress(f, index):
                    kf["h"] = 1
                else:
                    kf["o"] = LINEAR_OUT
                    kf["i"] = LINEAR_IN
            out.append(kf)
        return out

    def layer(self, line, index, stroke_width, layer_index, color, name="ink"):
        """줄 하나의 셰이프 레이어. 이름 `ink`면 앱이 색을 `Ink` 토큰으로 바꾼다 (word-art.md 6.1)."""
        def path_at(f):
            return [self.bezier_path(line, self.sway * math.sin(2 * math.pi * self.progress(f, index)))]

        def position_at(f):
            return [0, round(self.rise * self.canvas * (RESTING_PROGRESS - self.progress(f, index)), 2), 0]

        def opacity_at(f):
            return [round(100 * opacity(self.progress(f, index)), 2)]

        rgba = [round(c / 255, 4) for c in color] + [1]
        return {
            "ddd": 0, "ind": layer_index, "ty": 4, "nm": name, "sr": 1,
            "ks": {
                "o": {"a": 1, "k": self.keyframes(opacity_at, index)},
                "r": {"a": 0, "k": 0},
                "p": {"a": 1, "k": self.keyframes(position_at, index)},
                "a": {"a": 0, "k": [0, 0, 0]},
                "s": {"a": 0, "k": [100, 100, 100]},
            },
            "ao": 0,
            "shapes": [{
                "ty": "gr", "nm": f"steam {index + 1}",
                "it": [
                    {"ty": "sh", "nm": "path", "ks": {"a": 1, "k": self.keyframes(path_at, index)}},
                    {"ty": "st", "nm": "stroke", "c": {"a": 0, "k": rgba}, "o": {"a": 0, "k": 100},
                     "w": {"a": 0, "k": round(stroke_width * self.canvas, 2)}, "lc": 2, "lj": 2},
                    {"ty": "tr", "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]},
                     "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0},
                     "o": {"a": 0, "k": 100}, "sk": {"a": 0, "k": 0}, "sa": {"a": 0, "k": 0}},
                ],
            }],
            "ip": 0, "op": self.frames, "st": 0, "bm": 0,
        }

    def top_extent(self, line):
        """줄이 가장 높이 오를 때의 위 끝(캔버스 비율)."""
        return line["top"] - self.rise * (1 - RESTING_PROGRESS)
