#!/usr/bin/env python3
"""기리 Lottie 파일 하나를 만든다 (docs/design/giri-companion.md 4.4, 5번).

  .venv/bin/python tools/build_giri_lottie.py

- 출력: KanaTrip/Resources/giri.lottie.json. 420 × 432, 60fps, 마커 12개, 앱용 값 "kt" (5.6).
- 입력: tools/make_onigiri_svg.py를 모듈로 불러 부위 함수와 RICES·FACES·ARMS·MARKS 값을 그대로 쓴다.
  SVG 파일을 다시 읽지 않는다(값의 출처를 하나로, 5.9.2). 부위 함수가 내는 SVG 조각을 메모리에서 Lottie 모양으로 옮긴다.
- 좌표: 360 좌표 (x, y)는 캔버스 (x + 60, y + 72)다 (5.6).
- 레이어 이름은 4.4.1 표 그대로다. 색을 바꿀 선·면 항목은 `rice`, `cheek`. 얼굴 안 묶음은 `eyes`, `eyes_fixed`, `mouth`.
- 파일에 구운 기본값은 기본 표정의 흰 밥: `face_default`·`pattern_plain_rice` 100, 다른 얼굴·무늬와 반짝임 0 (5.7).
  이미지 슬롯(`top`, `filling_back`, `filling_front`)은 1080 × 1080 자리의 1 × 1 투명 PNG다.
- 쓰는 기능: 위치·회전·크기·불투명도 키프레임, 경로 키프레임, 부모 연결, 이미지 레이어. 표현식·효과·마스크·매트·트림은 쓰지 않는다 (5.1).
- 검사(못 넘으면 멈춤, 5.9.2): ① 한 번 마커 21프레임 이하 ② 반복 마커의 첫·마지막 값이 같음 ③ 마커의 첫·마지막 프레임이
  시작·끝 자세의 정지 마커와 같음 ④ 팔 뿌리 끝이 몸 외곽선 안쪽 가장자리 안, 팔이 외곽선을 45° 이상으로 지남 (4.4.2)
  ⑤ 모든 마커의 모든 프레임에서 부위의 외곽 상자가 캔버스 안.
- 같은 입력이면 같은 파일이 나온다(키 순서와 숫자 자릿수를 고정).
"""

import base64
import io
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_onigiri_svg as giri  # noqa: E402
from build_word_lottie import EASE_IN, EASE_OUT, LINEAR_IN, LINEAR_OUT  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "KanaTrip" / "Resources" / "giri.lottie.json"

FPS = 60
W, H = 420, 432
OX, OY = 60, 72           # 360 좌표 → 캔버스 (5.6)
SLOT_SIDE = giri.ITEM_PNG_SIDE  # 이미지 슬롯 에셋 크기 1080 (5.7)
MARKER_GAP = 2            # 마커 사이 띄우는 프레임 (1 이상)
ONE_SHOT_MAX = 21         # 0.35초 (검사 ①)
ROOT_CAP = 12             # 팔 바깥 선 굵기 24의 둥근 끝 반지름 (4.4.2)
MIN_CROSS_ANGLE = 45

# 곡선 (5.2의 표기). 나가는 핸들, 들어오는 핸들. 값은 build_word_lottie.py의 상수를 같이 쓴다.
CURVES = {
    "inout": (EASE_OUT, EASE_IN),     # (0.42, 0), (0.58, 1)
    "out": (LINEAR_OUT, EASE_IN),     # (0, 0), (0.58, 1)
    "in": (EASE_OUT, LINEAR_IN),      # (0.42, 0), (1, 1)
    "linear": (LINEAR_OUT, LINEAR_IN),
}
HOLD = "hold"


def r4(v):
    return round(v, 4) if isinstance(v, float) else v


def P(x, y):
    """360 좌표 → 캔버스 좌표."""
    return [r4(x + OX), r4(y + OY)]


def static(value):
    return {"a": 0, "k": value}


def hex_rgba(hex_color, alpha=1):
    h = hex_color.lstrip("#")
    return [round(int(h[k:k + 2], 16) / 255, 4) for k in (0, 2, 4)] + [alpha]


# ---------------------------------------------------------------- SVG 조각 → Lottie 모양

class BezierPath:
    """Lottie 경로 하나: 점, 들어오는·나가는 핸들(점에서 잰 상대값), 닫힘. 좌표는 360 좌표."""

    def __init__(self):
        self.v, self.i, self.o = [], [], []
        self.closed = False

    def move(self, p):
        self.v.append(p)
        self.i.append((0.0, 0.0))
        self.o.append((0.0, 0.0))

    def cubic(self, c1, c2, p):
        last = self.v[-1]
        self.o[-1] = (c1[0] - last[0], c1[1] - last[1])
        self.v.append(p)
        self.i.append((c2[0] - p[0], c2[1] - p[1]))
        self.o.append((0.0, 0.0))

    def close(self):
        self.closed = True
        # 마지막 점이 첫 점과 같으면 합친다(닫는 구간의 핸들은 첫 점의 들어오는 핸들로).
        if len(self.v) > 1 and math.dist(self.v[0], self.v[-1]) < 1e-6:
            self.i[0] = self.i[-1]
            self.v.pop()
            self.i.pop()
            self.o.pop()

    def copy(self):
        c = BezierPath()
        c.v, c.i, c.o, c.closed = list(self.v), list(self.i), list(self.o), self.closed
        return c

    def lottie(self):
        return {"c": self.closed, "v": [P(*p) for p in self.v],
                "i": [[r4(x), r4(y)] for x, y in self.i], "o": [[r4(x), r4(y)] for x, y in self.o]}


def parse_path(d):
    """SVG 경로(M L Q C Z, 소문자 상대 명령 포함)를 BezierPath 목록으로. 이 그림에 쓰는 명령만 다룬다."""
    tokens = re.findall(r"[MLQCZmlqcz]|-?\d*\.?\d+(?:e-?\d+)?", d)
    paths, cur, pos, start = [], None, (0.0, 0.0), (0.0, 0.0)
    k, cmd = 0, None

    def num():
        nonlocal k
        v = float(tokens[k])
        k += 1
        return v
    while k < len(tokens):
        if tokens[k] in "MLQCZmlqcz":
            cmd = tokens[k]
            k += 1
        rel = cmd.islower()
        c = cmd.upper()
        ox, oy = pos if rel else (0.0, 0.0)
        if c == "M":
            pos = (num() + ox, num() + oy)
            cur = BezierPath()
            cur.move(pos)
            paths.append(cur)
            start = pos
            cmd = "l" if rel else "L"
        elif c == "L":
            p = (num() + ox, num() + oy)
            cur.cubic(pos, p, p)
            pos = p
        elif c == "Q":
            q = (num() + ox, num() + oy)
            p = (num() + ox, num() + oy)
            # 2차 곡선 → 3차: 핸들은 끝점에서 제어점 쪽으로 2/3
            c1 = (pos[0] + 2 / 3 * (q[0] - pos[0]), pos[1] + 2 / 3 * (q[1] - pos[1]))
            c2 = (p[0] + 2 / 3 * (q[0] - p[0]), p[1] + 2 / 3 * (q[1] - p[1]))
            cur.cubic(c1, c2, p)
            pos = p
        elif c == "C":
            c1 = (num() + ox, num() + oy)
            c2 = (num() + ox, num() + oy)
            p = (num() + ox, num() + oy)
            cur.cubic(c1, c2, p)
            pos = p
        elif c == "Z":
            cur.close()
            pos = start
        else:
            raise ValueError(f"다루지 않는 경로 명령 {cmd}: {d}")
    return paths


def local(tag):
    return tag.split("}")[-1]


STYLE_KEYS = ("fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "opacity", "class")
LINECAP = {"butt": 1, "round": 2, "square": 3}
LINEJOIN = {"miter": 1, "round": 2, "bevel": 3}


class Drawn:
    """그린 요소 하나: Lottie 묶음과 외곽 상자(360 좌표, 선 굵기 포함)."""

    def __init__(self, group, box):
        self.group, self.box = group, box


def shape_group(elem, style, name):
    tag = local(elem.tag)
    items, box = [], None
    if tag == "path":
        paths = parse_path(elem.get("d"))
        for n, bp in enumerate(paths):
            items.append({"ty": "sh", "nm": f"path{n + 1}", "ks": static(bp.lottie())})
        pts = [p for bp in paths for k, p in enumerate(bp.v)]
        pts += [(p[0] + h[0], p[1] + h[1]) for bp in paths for p, h in zip(bp.v, bp.i)]
        pts += [(p[0] + h[0], p[1] + h[1]) for bp in paths for p, h in zip(bp.v, bp.o)]
        closed = any(bp.closed for bp in paths)
    elif tag in ("ellipse", "circle"):
        cx, cy = float(elem.get("cx")), float(elem.get("cy"))
        rx = float(elem.get("rx", elem.get("r", 0)))
        ry = float(elem.get("ry", elem.get("r", 0)))
        assert not elem.get("transform"), "회전한 타원은 경로로 미리 바꿔 넣는다 (5.9.2)"
        items.append({"ty": "el", "nm": "ellipse", "d": 1, "p": static(P(cx, cy)), "s": static([r4(2 * rx), r4(2 * ry)])})
        pts = [(cx - rx, cy - ry), (cx + rx, cy + ry)]
        closed = True
    else:
        raise ValueError(f"다루지 않는 요소 {tag}")
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    pad = 0.0
    cls = style.get("class")
    opacity = float(style.get("opacity", 1)) * 100
    stroke = style.get("stroke")
    if stroke and stroke != "none":
        w = float(style.get("stroke-width", 1))
        # 닫힌 경로의 뾰족한 이음(miter)은 굵기 반보다 더 나갈 수 있어 넉넉히 잡는다
        pad = w / 2 * (1.5 if closed and style.get("stroke-linejoin", "miter") == "miter" else 1)
        items.append({"ty": "st", "nm": cls or "stroke", "c": static(hex_rgba(stroke)), "o": static(r4(opacity)),
                      "w": static(w), "lc": LINECAP[style.get("stroke-linecap", "butt")],
                      "lj": LINEJOIN[style.get("stroke-linejoin", "miter")], "ml": 4})
    fill = style.get("fill")
    if fill is None and closed:
        fill = "#000000"  # SVG 기본값. 이 그림에서는 쓰이지 않는다
    if fill and fill != "none":
        items.append({"ty": "fl", "nm": cls or "fill", "c": static(hex_rgba(fill)), "o": static(r4(opacity)), "r": 1})
    items.append(shape_tr())
    box = (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad)
    return Drawn({"ty": "gr", "nm": name, "it": items}, box)


def shape_tr(anchor=(0, 0), scale=None):
    return {"ty": "tr", "p": static(list(anchor)), "a": static(list(anchor)), "s": scale or static([100, 100]),
            "r": static(0), "o": static(100), "sk": static(0), "sa": static(0)}


def convert(fragment, inherited=None):
    """SVG 조각 → Drawn 목록(그리는 순서, 아래가 먼저). <g id>는 이름 붙은 묶음 하나가 된다."""
    root = ET.fromstring(f'<g xmlns="http://www.w3.org/2000/svg">{fragment}</g>')
    return _convert_children(root, inherited or {})


def _convert_children(node, style):
    out = []
    count = 0
    for child in node:
        tag = local(child.tag)
        if tag in ("defs", "clipPath"):
            continue
        st = dict(style)
        st.update({k: child.get(k) for k in STYLE_KEYS if child.get(k) is not None})
        if tag == "g":
            inner = _convert_children(child, st)
            if child.get("id"):
                out.append(Drawn(group_of(child.get("id"), inner), union([d.box for d in inner])))
            else:
                out += inner
        else:
            count += 1
            out.append(shape_group(child, st, f"{tag}{count}"))
    return out


def group_of(name, drawn, tr=None):
    """Drawn 목록을 묶음 하나로. Lottie는 목록 앞이 위에 그려지므로 순서를 뒤집는다."""
    return {"ty": "gr", "nm": name, "it": [d.group for d in reversed(drawn)] + [tr or shape_tr()]}


def union(boxes):
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


# ---------------------------------------------------------------- 팔 경로

ARM_PATHS = {k: parse_path(d)[0] for k, d in giri.ARMS.items()}
SHOULDER = {"l": ARM_PATHS["l"].v[0], "r_down": ARM_PATHS["r_down"].v[0], "r_up": ARM_PATHS["r_up"].v[0]}


def rotated(bp, deg, pivot):
    a = math.radians(deg)
    cos, sin = math.cos(a), math.sin(a)

    def rot(p):
        x, y = p[0] - pivot[0], p[1] - pivot[1]
        return pivot[0] + x * cos - y * sin, pivot[1] + x * sin + y * cos

    def rotv(h):
        return h[0] * cos - h[1] * sin, h[0] * sin + h[1] * cos
    c = bp.copy()
    c.v = [rot(p) for p in bp.v]
    c.i = [rotv(h) for h in bp.i]
    c.o = [rotv(h) for h in bp.o]
    return c


def moved_tip(bp, dy):
    c = bp.copy()
    c.v = [c.v[0], (c.v[1][0], c.v[1][1] + dy)]
    return c


L_REST = ARM_PATHS["l"]
R_DOWN = ARM_PATHS["r_down"]
R_UP = ARM_PATHS["r_up"]
R_UP_OVER = moved_tip(R_UP, -8)   # 손끝 (290, 156), 듦 자리보다 8 위 (5.2.4)
# 숨쉬기의 팔 따라 움직임: 어깨 축, 바깥으로 (왼팔 시계 방향 +, 오른팔 반시계 방향 −) (5.2.1)
L_BREATH = rotated(L_REST, 2, SHOULDER["l"])
R_DOWN_BREATH = rotated(R_DOWN, -2, SHOULDER["r_down"])
R_UP_BREATH = rotated(R_UP, -3, SHOULDER["r_up"])
L_RAISE = rotated(L_REST, 4, SHOULDER["l"])   # 팔 올리기 때 왼팔 바깥으로 4° (5.2.4)


# ---------------------------------------------------------------- 시간과 움직임 (5.2)

def f(sec):
    return round(sec * FPS)


def S(vert, horiz=None):
    """크기 [가로, 세로, 100]. 문서는 세로/가로 순으로 적는다."""
    return [horiz if horiz is not None else vert, vert, 100]


HOP_PIVOT = P(150, 350)
BREATH_PIVOT = P(150, 322)
SHADOW_PIVOT = P(150, 346)
SPARKLE_PIVOT = P(290, 164)


def hop_pos(y):
    return [HOP_PIVOT[0], r4(HOP_PIVOT[1] + y), 0]


# 움직이는 값(트랙)과 쉼 값. arm은 "down"/"up".
TRACKS = {
    "hop.p": lambda arm: hop_pos(0),
    "squash.s": lambda arm: S(100),
    "breath.s": lambda arm: S(100),
    "breath.r": lambda arm: 0,
    "shadow.s": lambda arm: S(100),
    "shadow.o": lambda arm: 100,
    "arm_l.path": lambda arm: L_REST,
    "arm_r.path": lambda arm: R_DOWN if arm == "down" else R_UP,
    "sparkles.s": lambda arm: S(100),
    **{f"face_{k}.eyes.s": (lambda arm: [100, 100]) for k in giri.BLINKING_FACES},
}

# 마커: (이름, 길이 프레임, 시작 팔, 끝 팔, 반복)
MARKERS = [
    ("still_down", 0, "down", "down", False),
    ("still_up", 0, "up", "up", False),
    ("idle_down", f(6.4), "down", "down", True),
    ("idle_up", f(6.4), "up", "up", True),
    ("react_down", f(0.2), "down", "down", False),
    ("react_up", f(0.2), "up", "up", False),
    ("raise", f(0.25), "down", "up", False),
    ("lower", f(0.2), "up", "down", False),
    ("hop", 20, "down", "up", False),        # 0.333초
    ("hop_move", f(0.35), "down", "up", False),
    ("appear", f(0.35), "down", "up", False),
    ("dress", 13, "down", "down", False),    # 0.217초
]


def blink():
    """깜빡임: 4.0 → 4.067 → 4.1 → 4.233초, 세로 100 → 10 → 10 → 100. 닫기 easeIn, 뜨기 easeOut (5.2.1)."""
    return [(0, [100, 100], HOLD), (f(4.0), [100, 100], "in"), (f(4.067), [100, 10], HOLD),
            (f(4.1), [100, 10], "out"), (f(4.233), [100, 100], HOLD), (f(6.4), [100, 100], HOLD)]


def idle(arm):
    breathe = [(0, S(100), "inout"), (f(1.6), S(101.75, 99.7), "inout"), (f(3.2), S(100), "inout"),
               (f(4.8), S(101.75, 99.7), "inout"), (f(6.4), S(100), HOLD)]
    # 팔은 숨보다 0.1초 늦고, 마지막 구간(4.9 → 6.4초)을 짧게 해 끝을 맞춘다.
    times = [0, f(1.7), f(3.3), f(4.9), f(6.4)]

    def follow(rest, out):
        return [(t, rest if n % 2 == 0 else out, "inout" if n < 4 else HOLD) for n, t in enumerate(times)]
    keys = {"breath.s": breathe, "arm_l.path": follow(L_REST, L_BREATH),
            "arm_r.path": follow(R_DOWN, R_DOWN_BREATH) if arm == "down" else follow(R_UP, R_UP_BREATH)}
    for k in giri.BLINKING_FACES:
        keys[f"face_{k}.eyes.s"] = blink()
    return keys


def burst(t0, t1, t2, end):
    """반짝임이 손끝에서 커져 나옴: t0에 0 → t1에 110% → t2에 100% (5.2.2)."""
    keys = [(0, S(0), HOLD), (t0, S(0), "out"), (t1, S(110), "inout"), (t2, S(100), HOLD)]
    return keys + ([(end, S(100), HOLD)] if end > t2 else [])


def segment_keys(name):
    if name in ("still_down", "still_up"):
        return {}
    if name == "idle_down":
        return idle("down")
    if name == "idle_up":
        return idle("up")
    if name in ("react_down", "react_up"):
        return {"squash.s": [(0, S(100), "out"), (f(0.067), S(97, 102), "inout"), (f(0.133), S(101, 99.5), "in"),
                             (f(0.2), S(100), HOLD)]}
    if name == "raise":
        return {"arm_r.path": [(0, R_DOWN, "out"), (f(0.167), R_UP_OVER, "inout"), (f(0.25), R_UP, HOLD)],
                "breath.r": [(0, 0, "inout"), (f(0.117), 1.5, "inout"), (f(0.25), 0, HOLD)],
                "arm_l.path": [(0, L_REST, "inout"), (f(0.117), L_RAISE, "inout"), (f(0.25), L_REST, HOLD)],
                "sparkles.s": burst(f(0.1), f(0.2), f(0.25), f(0.25))}
    if name == "lower":
        return {"arm_r.path": [(0, R_UP, "inout"), (f(0.2), R_DOWN, HOLD)]}
    if name == "hop":
        end = 20
        return {"squash.s": [(0, S(100), "out"), (f(0.05), S(93, 105), "inout"), (f(0.1), S(106, 96), "inout"),
                             (f(0.167), S(100), "inout"), (f(0.25), S(103, 98), "inout"), (f(0.3), S(95, 104), "out"),
                             (end, S(100), HOLD)],
                "hop.p": [(0, hop_pos(0), HOLD), (f(0.05), hop_pos(0), "out"), (f(0.167), hop_pos(-36), "in"),
                          (f(0.283), hop_pos(0), HOLD), (end, hop_pos(0), HOLD)],
                "arm_r.path": [(0, R_DOWN, HOLD), (f(0.05), R_DOWN, "out"), (f(0.2), R_UP_OVER, "inout"),
                               (f(0.267), R_UP, HOLD), (end, R_UP, HOLD)],
                "shadow.s": [(0, S(100), HOLD), (f(0.05), S(100), "out"), (f(0.167), S(80), "in"),
                             (f(0.283), S(100), HOLD), (end, S(100), HOLD)],
                "shadow.o": [(0, 100, HOLD), (f(0.05), 100, "out"), (f(0.167), 62, "in"),
                             (f(0.283), 100, HOLD), (end, 100, HOLD)],
                "sparkles.s": burst(f(0.15), f(0.233), f(0.3), end)}
    if name == "hop_move":
        end = f(0.35)
        return {"squash.s": [(0, S(100), "out"), (f(0.05), S(93, 105), "inout"), (f(0.1), S(106, 96), "inout"),
                             (f(0.2), S(100), HOLD), (f(0.3), S(100), "inout"), (f(0.317), S(95, 104), "out"),
                             (end, S(100), HOLD)],
                # 팔은 0.05 → 0.25초에 넘침과 함께 (넘침은 raise처럼 3분의 2 지점)
                "arm_r.path": [(0, R_DOWN, HOLD), (f(0.05), R_DOWN, "out"), (f(0.183), R_UP_OVER, "inout"),
                               (f(0.25), R_UP, HOLD), (end, R_UP, HOLD)],
                "sparkles.s": burst(f(0.15), f(0.233), f(0.3), end)}
    if name == "appear":
        end = f(0.35)
        return {"squash.s": [(0, S(85, 85), "out"), (f(0.217), S(103, 103), "inout"), (end, S(100), HOLD)],
                # 0.15초부터 raise와 같은 모양(넘침은 3분의 2 지점)으로 올라가 0.35초에 듦
                "arm_r.path": [(0, R_DOWN, HOLD), (f(0.15), R_DOWN, "out"), (f(0.283), R_UP_OVER, "inout"),
                               (end, R_UP, HOLD)],
                "sparkles.s": burst(f(0.217), f(0.3), end, end)}
    if name == "dress":
        return {"squash.s": [(0, S(100), "out"), (f(0.083), S(96, 104), "inout"), (f(0.167), S(102, 99), "in"),
                             (13, S(100), HOLD)]}
    raise KeyError(name)


def layout():
    """마커 자리와 트랙별 전체 키프레임 [(프레임, 값, 곡선)]."""
    placed, t = [], 0
    for name, dur, arm0, arm1, loop in MARKERS:
        placed.append((name, t, dur, arm0, arm1, loop))
        t += dur + MARKER_GAP
    total = t
    tracks = {k: [] for k in TRACKS}
    for name, start, dur, arm0, arm1, loop in placed:
        keys = segment_keys(name)
        for k, rest in TRACKS.items():
            seg = keys.get(k) or [(0, rest(arm0), HOLD)]
            if keys.get(k) is None and rest(arm0) != rest(arm1):
                raise SystemExit(f"{name}: {k}의 시작·끝 쉼 값이 다른데 움직임이 없음")
            for dt, v, curve in seg:
                assert 0 <= dt <= dur, f"{name} {k}: 키프레임 {dt}가 마커 밖"
                tracks[k].append((start + dt, v, curve))
    for k, kfs in tracks.items():
        frames = [kf[0] for kf in kfs]
        assert frames == sorted(frames) and len(set(frames)) == len(frames), f"{k}: 키프레임 순서"
    return placed, total, tracks


def value_json(v):
    if isinstance(v, BezierPath):
        return [v.lottie()]
    return [r4(x) for x in v] if isinstance(v, list) else [r4(v)]


def animated(kfs):
    out = []
    for n, (t, v, curve) in enumerate(kfs):
        kf = {"t": t, "s": value_json(v)}
        if n < len(kfs) - 1:
            if curve == HOLD:
                kf["h"] = 1
            else:
                o, i = CURVES[curve]
                kf["o"], kf["i"] = o, i
        out.append(kf)
    return {"a": 1, "k": out}


# ---------------------------------------------------------------- 값 계산 (검사용)

def bezier_y(o, i, x):
    """Lottie 이징: (0,0), o, i, (1,1) 3차 곡선에서 x에 대한 y."""
    x1, y1, x2, y2 = o["x"][0], o["y"][0], i["x"][0], i["y"][0]
    lo, hi = 0.0, 1.0
    for _ in range(40):
        t = (lo + hi) / 2
        bx = 3 * (1 - t) ** 2 * t * x1 + 3 * (1 - t) * t * t * x2 + t ** 3
        if bx < x:
            lo = t
        else:
            hi = t
    t = (lo + hi) / 2
    return 3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t * t * y2 + t ** 3


def lerp(a, b, p):
    if isinstance(a, BezierPath):
        c = a.copy()
        c.v = [(x0 + (x1 - x0) * p, y0 + (y1 - y0) * p) for (x0, y0), (x1, y1) in zip(a.v, b.v)]
        c.i = [(x0 + (x1 - x0) * p, y0 + (y1 - y0) * p) for (x0, y0), (x1, y1) in zip(a.i, b.i)]
        c.o = [(x0 + (x1 - x0) * p, y0 + (y1 - y0) * p) for (x0, y0), (x1, y1) in zip(a.o, b.o)]
        return c
    if isinstance(a, list):
        return [x + (y - x) * p for x, y in zip(a, b)]
    return a + (b - a) * p


def evaluate(kfs, frame):
    if frame <= kfs[0][0]:
        return kfs[0][1]
    for n in range(len(kfs) - 1):
        t0, v0, curve = kfs[n]
        t1, v1, _ = kfs[n + 1]
        if t0 <= frame < t1:
            if curve == HOLD:
                return v0
            o, i = CURVES[curve]
            return lerp(v0, v1, bezier_y(o, i, (frame - t0) / (t1 - t0)))
    return kfs[-1][1]


def same(a, b, eps=1e-6):
    if isinstance(a, BezierPath):
        return all(math.dist(p, q) < eps for p, q in zip(a.v + a.i + a.o, b.v + b.i + b.o))
    if isinstance(a, list):
        return all(abs(x - y) < eps for x, y in zip(a, b))
    return abs(a - b) < eps


# ---------------------------------------------------------------- 레이어

class Layer:
    def __init__(self, ind, name, ty, parent=None, anchor=(0, 0), ks_over=None, box=None, shapes=None, ref=None):
        self.ind, self.name, self.ty, self.parent = ind, name, ty, parent
        self.anchor = list(anchor)
        self.ks_over = ks_over or {}
        self.box = box            # 360 좌표 외곽 상자 (검사 ⑤). None이면 검사하지 않음(null)
        self.shapes = shapes
        self.ref = ref

    def json(self, total):
        a = self.anchor + [0]
        ks = {"o": static(100), "r": static(0), "p": static(a), "a": static(a), "s": static([100, 100, 100])}
        ks.update(self.ks_over)
        out = {"ddd": 0, "ind": self.ind, "ty": self.ty, "nm": self.name, "sr": 1, "ks": ks, "ao": 0,
               "ip": 0, "op": total, "st": 0, "bm": 0}
        if self.parent is not None:
            out["parent"] = self.parent
        if self.ty == 4:
            out["shapes"] = self.shapes
        if self.ty == 2:
            out["refId"] = self.ref
        return out


def transparent_png():
    buf = io.BytesIO()
    Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


# 이미지 슬롯의 그려도 되는 범위 (360 좌표, item-art/brief.md 2.1.3·2.3.2, visual-rules.md 7.2)
SLOT_BOX = {"top": (64, 10, 236, 144), "filling_back": (-26, 152, 90, 218), "filling_front": (-26, 152, 90, 218)}


def arm_layer(ind, name, track, rest, tracks):
    """팔: 바깥 선(진갈색 24)과 안쪽 선(밥 색 12). 두 선이 같은 경로 키프레임을 쓴다."""
    path = animated(tracks[track]) if track else static(rest.lottie())
    inner = {"ty": "gr", "nm": "inner", "it": [{"ty": "sh", "nm": "path", "ks": path},
                                              {"ty": "st", "nm": "rice", "c": static(hex_rgba(giri.RICE)),
                                               "o": static(100), "w": static(24 - 2 * giri.SW), "lc": 2, "lj": 2,
                                               "ml": 4}, shape_tr()]}
    outer = {"ty": "gr", "nm": "outline", "it": [{"ty": "sh", "nm": "path", "ks": path},
                                                {"ty": "st", "nm": "outline", "c": static(hex_rgba(giri.LINE)),
                                                 "o": static(100), "w": static(24), "lc": 2, "lj": 2, "ml": 4},
                                                shape_tr()]}
    return [inner, outer]


def shapes_of(fragment):
    drawn = convert(fragment)
    return [d.group for d in reversed(drawn)], union([d.box for d in drawn])


def build():
    placed, total, tracks = layout()
    layers = []  # 아래에서 위 순서 (4.4.1). 마지막에 뒤집는다.
    HOP, SQUASH, BREATH = 1, 2, 3
    nulls = [
        Layer(HOP, "hop", 3, anchor=HOP_PIVOT, ks_over={"p": animated(tracks["hop.p"])}),
        Layer(SQUASH, "squash", 3, parent=HOP, anchor=HOP_PIVOT, ks_over={"s": animated(tracks["squash.s"])}),
        Layer(BREATH, "breath", 3, parent=SQUASH, anchor=BREATH_PIVOT,
              ks_over={"s": animated(tracks["breath.s"]), "r": animated(tracks["breath.r"])}),
    ]
    ind = iter(range(10, 100))
    assets = []

    def slot(name):
        assets.append({"id": name, "w": SLOT_SIDE, "h": SLOT_SIDE, "u": "", "p": transparent_png(), "e": 1})
        scale = round(360 / SLOT_SIDE * 100, 3)
        layers.append(Layer(next(ind), name, 2, parent=BREATH, ref=name, box=SLOT_BOX[name],
                            ks_over={"p": static(P(-30, 0) + [0]), "a": static([0, 0, 0]),
                                     "s": static([scale, scale, 100])}))

    def shape(name, fragment, parent=BREATH, anchor=(0, 0), ks_over=None, opacity=100):
        shapes, box = shapes_of(fragment)
        over = {"o": static(opacity)}
        over.update(ks_over or {})
        layers.append(Layer(next(ind), name, 4, parent=parent, anchor=anchor, ks_over=over, box=box, shapes=shapes))

    slot("filling_back")
    shape("shadow", giri.shadow(), parent=None, anchor=SHADOW_PIVOT,
          ks_over={"s": animated(tracks["shadow.s"]), "o": animated(tracks["shadow.o"])})
    shape("leg_l", giri.leg("l"), parent=SQUASH)
    shape("leg_r", giri.leg("r"), parent=SQUASH)
    for name, track, rest in (("arm_l", "arm_l.path", L_REST), ("arm_r", "arm_r.path", R_DOWN)):
        layers.append(Layer(next(ind), name, 4, parent=BREATH, anchor=P(*SHOULDER["l" if name == "arm_l" else "r_down"]),
                            box=None, shapes=arm_layer(0, name, track, rest, tracks)))
    shape("body_fill", giri.body_fill())
    for rice in giri.RICES:
        shape(f"pattern_{rice}", giri.pattern(rice), opacity=100 if rice == "plain_rice" else 0)
    shape("body_front", giri.body_front())
    slot("filling_front")
    slot("top")
    for kind in giri.FACES:
        drawn = convert(giri.face(kind))
        groups = []
        for d in reversed(drawn):
            g = d.group
            if g["nm"] == "eyes":
                pivot = P(*giri.EYES_PIVOT.get(kind, giri.EYES_PIVOT_DEFAULT))
                g["it"][-1] = shape_tr(pivot, animated(tracks[f"face_{kind}.eyes.s"]))
            groups.append(g)
        layers.append(Layer(next(ind), f"face_{kind}", 4, parent=BREATH, box=union([d.box for d in drawn]),
                            shapes=groups, ks_over={"o": static(100 if kind == "default" else 0)}))
    shape("sparkles", giri.MARKS, anchor=SPARKLE_PIVOT, opacity=0,
          ks_over={"s": animated(tracks["sparkles.s"])})

    all_layers = nulls + layers
    doc = {
        "v": "5.7.4", "fr": FPS, "ip": 0, "op": total, "w": W, "h": H, "nm": "giri", "ddd": 0,
        "assets": assets,
        "layers": [layer.json(total) for layer in reversed(layers)] + [n.json(total) for n in nulls],
        "markers": [{"tm": start, "cm": name, "dr": dur} for name, start, dur, *_ in placed],
        "kt": {"rices": {rid: {"rice": r["fill"], "cheek": r["cheek"]} for rid, r in giri.RICES.items()},
               "faces": list(giri.FACES), "slots": ["top", "filling_back", "filling_front"]},
    }
    return doc, placed, tracks, all_layers


# ---------------------------------------------------------------- 검사

def check_markers(placed, tracks):
    """① 한 번 마커 길이 ② 반복 첫·끝 ③ 첫·끝 프레임 = 정지 마커."""
    still = {arm: next(start for name, start, *_ in placed if name == f"still_{arm}") for arm in ("down", "up")}
    fails = []
    for name, start, dur, arm0, arm1, loop in placed:
        if not loop and dur > ONE_SHOT_MAX:
            fails.append(f"① {name} {dur}프레임 > {ONE_SHOT_MAX}")
        for k, kfs in tracks.items():
            first, last = evaluate(kfs, start), evaluate(kfs, start + dur)
            if loop and not same(first, last):
                fails.append(f"② {name} {k}")
            # 예외: 등장은 85%에서 시작하고(5.2.7), 반짝임은 켜지는 마커에서 0부터 커져 나온다(시작 표정에는 꺼져 있음).
            skip_first = (name == "appear" and k == "squash.s") or (k == "sparkles.s" and name in ("hop", "hop_move", "raise", "appear"))
            if not skip_first and not same(first, evaluate(kfs, still[arm0])):
                fails.append(f"③ {name} 첫 프레임 {k}")
            if not same(last, evaluate(kfs, still[arm1])):
                fails.append(f"③ {name} 끝 프레임 {k}")
    for name, start, dur, *_ in placed:
        print(f"  {name:11} {start:4}프레임부터 {dur:3}프레임 ({dur / FPS:.3f}초)")
    return fails


def bezier_points(bp, n=24):
    pts = []
    for k in range(len(bp.v) - 1):
        p0, p3 = bp.v[k], bp.v[k + 1]
        p1 = (p0[0] + bp.o[k][0], p0[1] + bp.o[k][1])
        p2 = (p3[0] + bp.i[k + 1][0], p3[1] + bp.i[k + 1][1])
        for j in range(n + 1):
            t = j / n
            pts.append(tuple((1 - t) ** 3 * a + 3 * (1 - t) ** 2 * t * b + 3 * (1 - t) * t * t * c + t ** 3 * d
                             for a, b, c, d in zip(p0, p1, p2, p3)))
    return pts


def inner_polygon():
    """몸 외곽선 안쪽 가장자리(몸 경로를 3 줄인 모양)를 점으로 편다 (head_inner_path)."""
    path = parse_path(giri.head_inner_path())[0]
    path.v.append(path.v[0])
    path.i.append(path.i[0])
    path.o.append((0, 0))
    return bezier_points(path, 16)


def check_arms(tracks):
    """④ 팔 경로의 모든 키프레임과 그 사이 4등분 지점에서 뿌리 끝·외곽선을 지나는 각을 잰다 (4.4.2)."""
    inner = inner_polygon()
    outline = giri.clip_polygon()
    fails, worst = [], {}
    for key in ("arm_l.path", "arm_r.path"):
        kfs = tracks[key]
        samples = []
        for n in range(len(kfs)):
            samples.append(kfs[n][1])
            if n < len(kfs) - 1 and kfs[n][2] != HOLD:
                samples += [lerp(kfs[n][1], kfs[n + 1][1], q / 4) for q in (1, 2, 3)]
        min_depth, min_angle = 1e9, 1e9
        for bp in samples:
            root = bp.v[0]
            d = bp.o[0] if math.hypot(*bp.o[0]) > 1e-6 else (bp.v[1][0] - root[0], bp.v[1][1] - root[1])
            L = math.hypot(*d)
            tip = (root[0] - ROOT_CAP * d[0] / L, root[1] - ROOT_CAP * d[1] / L)
            depth = min(giri.segment_distance(tip, inner[j], inner[j + 1]) for j in range(len(inner) - 1))
            if not giri.inside(inner, *tip):
                fails.append(f"④ {key} 뿌리 끝 {tip[0]:.1f},{tip[1]:.1f}이 외곽선 안쪽 가장자리 밖")
            min_depth = min(min_depth, depth)
            line = bezier_points(bp, 64)
            angle = crossing_angle(line, outline)
            if angle is None:
                fails.append(f"④ {key} 팔이 몸 외곽선을 지나지 않음")
                continue
            min_angle = min(min_angle, angle)
            if angle < MIN_CROSS_ANGLE:
                fails.append(f"④ {key} 외곽선을 지나는 각 {angle:.0f}° < {MIN_CROSS_ANGLE}°")
        worst[key] = (min_depth, min_angle)
        print(f"  {key}: 뿌리 끝이 안쪽 가장자리에서 가장 얕게 {min_depth:.1f} 안, 외곽선을 지나는 각 최소 {min_angle:.0f}°")
    return fails


def crossing_angle(line, poly):
    """팔 중심선이 몸 외곽선을 지나는 첫 자리에서 두 접선 사이의 각(0~90°)."""
    n = len(poly)
    for a, b in zip(line, line[1:]):
        for j in range(n):
            c, d = poly[j], poly[(j + 1) % n]
            den = (b[0] - a[0]) * (d[1] - c[1]) - (b[1] - a[1]) * (d[0] - c[0])
            if abs(den) < 1e-12:
                continue
            t = ((c[0] - a[0]) * (d[1] - c[1]) - (c[1] - a[1]) * (d[0] - c[0])) / den
            u = ((c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])) / den
            if 0 <= t <= 1 and 0 <= u <= 1:
                # 외곽선 접선은 이웃 구간까지 넓혀 잰다(다각형 꺾임에 덜 흔들리게)
                c0, d0 = poly[(j - 2) % n], poly[(j + 3) % n]
                v1 = (b[0] - a[0], b[1] - a[1])
                v2 = (d0[0] - c0[0], d0[1] - c0[1])
                cos = abs(v1[0] * v2[0] + v1[1] * v2[1]) / (math.hypot(*v1) * math.hypot(*v2))
                return math.degrees(math.acos(min(1.0, cos)))
    return None


def matrix(p, a, s, r):
    """Lottie 변환: T(p) R(r) S(s) T(-a)를 2×3 행렬로."""
    rad = math.radians(r)
    cos, sin = math.cos(rad), math.sin(rad)
    sx, sy = s[0] / 100, s[1] / 100
    m = [cos * sx, -sin * sy, sin * sx, cos * sy]
    tx = p[0] - (m[0] * a[0] + m[1] * a[1])
    ty = p[1] - (m[2] * a[0] + m[3] * a[1])
    return (m[0], m[1], tx, m[2], m[3], ty)


def compose(A, B):
    a, b, c, d, e, f_ = A
    g, h, i, j, k, l_ = B
    return (a * g + b * j, a * h + b * k, a * i + b * l_ + c, d * g + e * j, d * h + e * k, d * i + e * l_ + f_)


def apply(M, p):
    return M[0] * p[0] + M[1] * p[1] + M[2], M[3] * p[0] + M[4] * p[1] + M[5]


def check_bounds(placed, tracks, layers):
    """⑤ 모든 마커의 모든 프레임에서 부위의 외곽 상자가 캔버스 안 (이미지 슬롯은 그려도 되는 범위 상자)."""
    by_ind = {layer.ind: layer for layer in layers}
    fails = set()
    tight = {"left": 1e9, "top": 1e9, "right": 1e9, "bottom": 1e9}

    def local_matrix(layer, frame):
        if layer.name == "hop":
            return matrix(evaluate(tracks["hop.p"], frame), HOP_PIVOT, [100, 100], 0)
        if layer.name == "squash":
            return matrix(HOP_PIVOT, HOP_PIVOT, evaluate(tracks["squash.s"], frame), 0)
        if layer.name == "breath":
            return matrix(BREATH_PIVOT, BREATH_PIVOT, evaluate(tracks["breath.s"], frame),
                          evaluate(tracks["breath.r"], frame))
        if layer.name == "shadow":
            return matrix(SHADOW_PIVOT, SHADOW_PIVOT, evaluate(tracks["shadow.s"], frame), 0)
        if layer.name == "sparkles":
            return matrix(SPARKLE_PIVOT, SPARKLE_PIVOT, evaluate(tracks["sparkles.s"], frame), 0)
        return (1, 0, 0, 0, 1, 0)

    def world(layer, frame):
        M = local_matrix(layer, frame)
        while layer.parent is not None:
            layer = by_ind[layer.parent]
            M = compose(local_matrix(layer, frame), M)
        return M

    for name, start, dur, *_ in placed:
        for frame in range(start, start + dur + 1):
            for layer in layers:
                if layer.ty == 3:
                    continue
                if layer.name in ("arm_l", "arm_r"):
                    bp = evaluate(tracks[f"{layer.name}.path"], frame)
                    pts = bezier_points(bp, 16)
                    box = (min(p[0] for p in pts) - 12, min(p[1] for p in pts) - 12,
                           max(p[0] for p in pts) + 12, max(p[1] for p in pts) + 12)
                else:
                    box = layer.box
                x0, y0, x1, y1 = box
                M = world(layer, frame)
                corners = [apply(M, (x + OX, y + OY)) for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1))]
                xs, ys = [c[0] for c in corners], [c[1] for c in corners]
                tight["left"] = min(tight["left"], min(xs))
                tight["top"] = min(tight["top"], min(ys))
                tight["right"] = min(tight["right"], W - max(xs))
                tight["bottom"] = min(tight["bottom"], H - max(ys))
                if min(xs) < 0 or min(ys) < 0 or max(xs) > W or max(ys) > H:
                    fails.add(f"⑤ {name} {layer.name} 프레임 {frame - start}: 캔버스 밖")
    print("  캔버스 가장자리까지 가장 좁은 여유: " + ", ".join(f"{k} {v:.1f}" for k, v in tight.items()))
    return sorted(fails)


def main():
    doc, placed, tracks, layers = build()
    print("마커")
    fails = check_markers(placed, tracks)
    print("팔 이음매 (4.4.2)")
    fails += check_arms(tracks)
    print("캔버스 (5.6)")
    fails += check_bounds(placed, tracks, layers)
    if fails:
        raise SystemExit("검사 실패:\n  " + "\n  ".join(fails))
    text = json.dumps(doc, ensure_ascii=False, separators=(",", ":"), sort_keys=False)
    OUT.write_text(text + "\n", encoding="utf-8")
    print(f"wrote {OUT} ({len(text.encode()) / 1024:.1f} KB, {len(doc['layers'])}레이어, 마커 {len(doc['markers'])}개)")


if __name__ == "__main__":
    main()
