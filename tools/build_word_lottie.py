#!/usr/bin/env python3
"""단어 그림 하나를 Lottie JSON 하나로 만든다(정지 그림 + 움직이는 벡터 레이어) (docs/design/word-art.md 6번).

  .venv/bin/python tools/build_word_lottie.py              # 움직임 대상 가운데 정지 그림이 있는 것 모두
  .venv/bin/python tools/build_word_lottie.py kitsune      # 골라서
  .venv/bin/python tools/build_word_lottie.py tonkatsu --test-steam  # 재생 경로 시험용(김을 임시로 붙임)
  .venv/bin/python tools/build_word_lottie.py yu --src docs/design/word-art/source/candidates/cut/word-yu_1.png
      # 고르기 전의 후보로 미리 만들어 앱에서 확인(결과를 커밋하지 않는다)

- 값은 tools/word_motion.json(word-art.md 6.2 종류별 값, 6.3 단어별 표를 옮긴 것)에서 읽는다.
- 정지 그림은 tools/place_word_art.py가 만드는 600px 그림과 같다(`prepare`). 그림이 없는 단어는 건너뛰고 목록을 출력한다.
- 출력: KanaTrip/Resources/word_{이름}.lottie.json. 600×600, 마커 `still`, 앱용 값 `"kt": {"loop", "still"}`.
- 종류: 김(steam), 흔들림(sway: 매달림 hang = 회전, 드리움 drape = 아래 조각 회전, kinds.sway.drapeTransform으로 기울이기도 가능), 깜박임(flicker),
  동전 떨어짐(coin, 한 번), 물결(ripple), 가쓰오부시(katsuobushi).
- 쓰는 기능: 위치·회전·크기·기울이기·불투명도 키프레임, 경로 키프레임, 부모 연결. 표현식·효과·마스크·매트·트림은 쓰지 않는다.
- 김 레이어 이름은 `ink`. 앱이 `ink.**.Color`에 지금 모드의 Ink 색을 넣는다.
- 반복 파일은 프레임 0이 정지 모습이고(`still` = 0), 한 번 파일(동전)은 마지막 프레임이 정지 모습이다.
"""

import base64
import io
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lottie_steam import Steam  # noqa: E402
from place_word_art import art_names, prepare  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MOTION = ROOT / "tools" / "word_motion.json"
OUT = ROOT / "KanaTrip" / "Resources"

EASE_OUT = {"x": [0.42], "y": [0]}   # 키프레임의 나가는 핸들 (easeInOut 앞쪽)
EASE_IN = {"x": [0.58], "y": [1]}    # 다음 키프레임으로 들어가는 핸들
LINEAR_OUT = {"x": [0], "y": [0]}
LINEAR_IN = {"x": [1], "y": [1]}


def rgb(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[k:k + 2], 16) for k in (0, 2, 4))


def rgba(hex_color):
    return [round(c / 255, 4) for c in rgb(hex_color)] + [1]


def static(value):
    return {"a": 0, "k": value}


def transform(**over):
    ks = {"o": static(100), "r": static(0), "p": static([0, 0, 0]), "a": static([0, 0, 0]), "s": static([100, 100, 100])}
    ks.update(over)
    return ks


def eased(points, ease_out=EASE_OUT, ease_in=EASE_IN):
    """[(프레임, 값), ...] → 구간마다 같은 이징의 키프레임."""
    out = []
    for n, (t, v) in enumerate(points):
        kf = {"t": t, "s": v if isinstance(v, list) else [v]}
        if n < len(points) - 1:
            kf["o"], kf["i"] = ease_out, ease_in
        out.append(kf)
    return out


def shape_tr():
    return {"ty": "tr", "p": static([0, 0]), "a": static([0, 0]), "s": static([100, 100]), "r": static(0),
            "o": static(100), "sk": static(0), "sa": static(0)}


def image_asset(asset_id, img):
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return {"id": asset_id, "w": img.width, "h": img.height, "u": "",
            "p": "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii"), "e": 1}


def image_layer(ind, ref, frames, name, ks=None, parent=None):
    layer = {"ddd": 0, "ind": ind, "ty": 2, "nm": name, "refId": ref, "sr": 1, "ks": ks or transform(),
             "ao": 0, "ip": 0, "op": frames, "st": 0, "bm": 0}
    if parent is not None:
        layer["parent"] = parent
    return layer


def shape_layer(ind, name, shapes, frames, ks=None, parent=None):
    layer = {"ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1, "ks": ks or transform(), "ao": 0,
             "shapes": shapes, "ip": 0, "op": frames, "st": 0, "bm": 0}
    if parent is not None:
        layer["parent"] = parent
    return layer


class Builder:
    def __init__(self, name, spec, kinds, canvas, stroke):
        self.name = name
        self.spec = spec
        self.kinds = kinds
        self.c = canvas
        self.stroke = stroke * canvas
        self.notes = []
        self.loop = "coin" not in spec
        # 파일 길이: 반복 파일은 움직임 가운데 가장 긴 주기(주기는 같거나 정수배, 6.3).
        if "coin" in spec:
            self.fps = kinds["coin"]["fps"]
            self.frames = round(kinds["coin"]["duration"] * self.fps)
        else:
            self.fps = 30
            periods = []
            for kind in spec:
                if kind in ("steam", "ripple", "sway"):
                    periods.append(kinds[kind]["period"])
                elif kind == "katsuobushi":
                    periods.append(kinds[kind]["period"] * 2)
            self.frames = round(max(periods) * self.fps)

    def px(self, v):
        return round(v * self.c, 2)

    # MARK: 김

    def steam(self, top_layers, start_ind):
        s, k = self.spec["steam"], self.kinds["steam"]
        steam = Steam(self.c, round(k["period"] * self.fps), s["count"], k["sway"], k["rise"])
        steam.shift = steam.still_shift()
        if steam.frames != self.frames:
            # 김 2.6초 파일에 가쓰오부시(1.3초)가 두 번 돈다. 다른 주기와 섞이면 값이 잘못된 것이다.
            raise SystemExit(f"{self.name}: 김 주기 {steam.frames}프레임 ≠ 파일 길이 {self.frames}프레임")
        ax, ay = s["anchor"]
        layers = []
        for i in range(s["count"]):
            line = {"cx": ax + (i - (s["count"] - 1) / 2) * s["spacing"], "amp": k["amplitude"],
                    "bottom": ay, "top": ay - s["length"]}
            top = steam.top_extent(line)
            if top < k["topMargin"]:
                self.notes.append(f"김 {i + 1}줄 위 끝 {top:.3f} < {k['topMargin']} (그림 배치를 다시 볼 것, 9.1)")
            layers.append(steam.layer(line, i, self.stroke / self.c * s.get("widthScale", 1.0),
                                      start_ind + i, rgb(k["color"])))
        top_layers.extend(layers)

    # MARK: 흔들림

    def sway_keyframes(self, amplitude):
        q = self.frames / 4
        return eased([(0, 0), (q, amplitude), (2 * q, 0), (3 * q, -amplitude), (4 * q, 0)])

    def sway(self, img, assets, layers, next_ind):
        """매달림: 그림 전체를 끈 위 끝 기준으로 회전. 드리움: 걸린 줄 아래 조각을 걸린 줄 가운데 기준으로 회전(또는 기울이기).
        움직이는 조각의 레이어 번호를 돌려준다(깜박임이 부모로 쓴다)."""
        s, k = self.spec["sway"], self.kinds["sway"]
        ax, ay = s["anchor"]
        anchor = [self.px(ax), self.px(ay), 0]
        motion = self.sway_keyframes(s["amplitude"])
        if s["style"] == "hang":
            assets.append(image_asset("art", img))
            ind = next_ind()
            layers.append(image_layer(ind, "art", self.frames, "art",
                                      transform(a=static(anchor), p=static(anchor), r={"a": 1, "k": motion})))
            return ind
        # 드리움: 자르는 선은 기준점보다 0.02 위. 움직이는 아래 조각을 고정 조각 아래(뒤)에 둔다.
        # 아래 조각은 자르는 선보다 overlap만큼 위까지 남겨, 따로 그린 두 장 사이에 실선 틈이 보이지 않게 한다
        # (겹친 띠는 고정 조각에 가려진다).
        cut = round((ay - k["cutAbove"]) * self.c)
        overlap = round(k["overlap"] * self.c)
        bottom = img.copy()
        bottom.paste((0, 0, 0, 0), (0, 0, img.width, max(0, cut - overlap)))
        top_full = img.copy()
        top_full.paste((0, 0, 0, 0), (0, cut, img.width, img.height))
        assets.append(image_asset("fixed", top_full))
        assets.append(image_asset("moving", bottom))
        fixed_ind = next_ind()
        layers.append(image_layer(fixed_ind, "fixed", self.frames, "fixed"))
        moving_ind = next_ind()
        if k["drapeTransform"] == "skew":
            # 기울이기 축 0°: 위 끝(기준점 높이)은 그대로, 아래 끝만 좌우로 (6.2).
            ks = transform(a=static(anchor), p=static(anchor), sk={"a": 1, "k": motion}, sa=static(0))
        else:
            # 회전: 기준점(걸린 줄 가운데)을 축으로 같은 각도만큼 돈다. lottie-ios 4.6에서 이미지 레이어의
            # 기울이기가 그려지지 않아(2026-11-15 시뮬레이터) word-art.md 6.2의 대안대로 회전으로 바꿨다.
            ks = transform(a=static(anchor), p=static(anchor), r={"a": 1, "k": motion})
        layers.append(image_layer(moving_ind, "moving", self.frames, "moving", ks))
        return moving_ind

    # MARK: 깜박임

    def flicker(self, parent):
        s, k = self.spec["flicker"], self.kinds["flicker"]
        cx, cy = s["center"]
        rx, ry = s["radius"]
        q = self.frames / 4
        values = k["opacity"]
        shapes = [{"ty": "gr", "nm": "glow", "it": [
            {"ty": "el", "nm": "ellipse", "p": static([self.px(cx), self.px(cy)]),
             "s": static([self.px(2 * rx), self.px(2 * ry)])},
            {"ty": "fl", "nm": "fill", "c": static(rgba(k["color"])), "o": static(100), "r": 1},
            shape_tr(),
        ]}]
        ks = transform(o={"a": 1, "k": eased([(n * q, v) for n, v in enumerate(values)])})
        return shapes, ks

    # MARK: 동전

    def coin(self, ind):
        s, k = self.spec["coin"], self.kinds["coin"]
        rx, ry = s["rest"]
        w, h = k["size"]
        t1, t2, t3 = (round(t * self.fps, 2) for t in k["times"])
        rest = [self.px(rx), self.px(ry), 0]
        high = [self.px(rx), self.px(ry - k["drop"]), 0]
        bounce = [self.px(rx), self.px(ry - k["bounce"]), 0]
        ease_in = ({"x": [0.42], "y": [0]}, {"x": [1], "y": [1]})
        ease_out = ({"x": [0], "y": [0]}, {"x": [0.58], "y": [1]})
        position = [
            {"t": 0, "s": high, "o": ease_in[0], "i": ease_in[1]},
            {"t": t1, "s": rest, "o": ease_out[0], "i": ease_out[1]},
            {"t": t2, "s": bounce, "o": ease_in[0], "i": ease_in[1]},
            {"t": t3, "s": rest},
        ]
        fade = round(k["fadeIn"] * self.fps, 2)
        shapes = [{"ty": "gr", "nm": "coin", "it": [
            {"ty": "el", "nm": "ellipse", "p": static([0, 0]), "s": static([self.px(w), self.px(h)])},
            {"ty": "st", "nm": "stroke", "c": static(rgba(k["stroke"])), "o": static(100),
             "w": static(round(self.stroke, 2)), "lc": 2, "lj": 2},
            {"ty": "fl", "nm": "fill", "c": static(rgba(k["fill"])), "o": static(100), "r": 1},
            shape_tr(),
        ]}]
        ks = transform(p={"a": 1, "k": position},
                       o={"a": 1, "k": [{"t": 0, "s": [0], "o": LINEAR_OUT, "i": LINEAR_IN}, {"t": fade, "s": [100]}]})
        return shape_layer(ind, "coin", shapes, self.frames, ks)

    # MARK: 물결

    def ripple(self, start_ind):
        s, k = self.spec["ripple"], self.kinds["ripple"]
        cx, cy = s["center"]
        r0, r1 = k["radius"][0], min(k["radius"][1], s.get("maxRadius", k["radius"][1]))
        period = round(k["period"] * self.fps)
        layers = []
        # 프레임 0에 한 테두리가 중간 크기(위상 0.5), 다른 테두리는 위상 0 (6.5).
        for i, phase0 in enumerate((0.5, 0.0)):
            def at(f):
                p = ((f / period) + phase0) % 1
                r = r0 + (r1 - r0) * p
                if p <= k["peakAt"]:
                    o = k["peakOpacity"] * p / k["peakAt"]
                else:
                    o = k["peakOpacity"] * (1 - p) / (1 - k["peakAt"])
                return r, o
            size_k, op_k = [], []
            frames = list(range(0, period, 2)) + [period]
            for n, f in enumerate(frames):
                r, o = at(f)
                wrap = n < len(frames) - 1 and at(frames[n + 1])[0] < r
                size_kf = {"t": f, "s": [self.px(2 * r), self.px(2 * r / k["aspect"])]}
                op_kf = {"t": f, "s": [round(o, 2)]}
                if n < len(frames) - 1:
                    for kf in (size_kf, op_kf):
                        if wrap:
                            kf["h"] = 1
                        else:
                            kf["o"], kf["i"] = LINEAR_OUT, LINEAR_IN
                size_k.append(size_kf)
                op_k.append(op_kf)
            shapes = [{"ty": "gr", "nm": f"ripple {i + 1}", "it": [
                {"ty": "el", "nm": "ellipse", "p": static([self.px(cx), self.px(cy)]), "s": {"a": 1, "k": size_k}},
                {"ty": "st", "nm": "stroke", "c": static(rgba(k["color"])), "o": static(100),
                 "w": static(round(self.stroke, 2)), "lc": 2, "lj": 2},
                shape_tr(),
            ]}]
            layers.append(shape_layer(start_ind + i, f"ripple {i + 1}", shapes, self.frames,
                                      transform(o={"a": 1, "k": op_k})))
        return layers

    # MARK: 가쓰오부시

    def katsuobushi(self, start_ind):
        s, k = self.spec["katsuobushi"], self.kinds["katsuobushi"]
        w, h = k["size"]
        period = k["period"] * self.fps
        layers = []
        for i, (x, y) in enumerate(s["flakes"]):
            # 모서리 둥근 불규칙 사각형: 아래 가운데가 (0, 0). 조각마다 모양을 조금 다르게.
            jitter = [(-0.5, 0.0), (0.5, 0.0), (0.42, -1.0), (-0.45, -0.9)]
            tilt = 0.08 * (1 if i % 2 else -1)
            verts = [[round(self.px(w) * dx + self.px(h) * dy * tilt, 2), round(self.px(h) * dy, 2)] for dx, dy in jitter]
            path = {"i": [[0, 0]] * 4, "o": [[0, 0]] * 4, "v": verts, "c": True}
            shapes = [{"ty": "gr", "nm": "flake", "it": [
                {"ty": "sh", "nm": "path", "ks": static(path)},
                {"ty": "rd", "nm": "round", "r": static(round(self.px(h) * 0.3, 2))},
                {"ty": "st", "nm": "stroke", "c": static(rgba(k["stroke"])), "o": static(100),
                 "w": static(round(self.stroke, 2)), "lc": 2, "lj": 2},
                {"ty": "fl", "nm": "fill", "c": static(rgba(k["fill"])), "o": static(100), "r": 1},
                shape_tr(),
            ]}]
            # 엇갈림: 이웃한 조각은 반대 방향으로 기울고(반 주기 엇갈림과 같다), 조각마다 기우는 폭을 조금 달리한다.
            # 4분의 1 주기씩 엇갈리면 어느 프레임에서도 두 조각이 ±10°로 기울어 있어 정지 모습(still = 0)이
            # 원래 그림이 되지 않는다. 이렇게 하면 프레임 0(과 반 주기마다)에 네 조각이 모두 0°, 크기 100%다.
            # 말림(세로 크기)은 기울 때(¼, ¾)에 가장 크게 해 곧게 설 때(0, ½)는 원래 모양이다. 한 파일에 두 번 돈다.
            sign = 1 if i % 2 == 0 else -1
            angle = k["rotation"] * k["rotationScale"][i % len(k["rotationScale"])]
            rot, scale = [], []
            for cycle in range(2):
                for fr, rv, sv in [(0, 0, 100), (0.25, sign * angle, k["curl"]), (0.5, 0, 100),
                                   (0.75, -sign * angle, k["curl"])]:
                    t = cycle * period + fr * period
                    rot.append((t, rv))
                    scale.append((t, sv))
            rot.append((2 * period, 0))
            scale.append((2 * period, 100))
            ks = transform(p=static([self.px(x), self.px(y), 0]),
                           r={"a": 1, "k": eased([(round(t, 2), v) for t, v in rot])},
                           s={"a": 1, "k": eased([(round(t, 2), [100, v, 100]) for t, v in scale])})
            layers.append(shape_layer(start_ind + i, f"katsuobushi {i + 1}", shapes, self.frames, ks))
        return layers

    # MARK: 파일

    def build(self, img):
        assets, top, bottom = [], [], []
        counter = iter(range(1, 100))

        def next_ind():
            return next(counter)

        # 위에 그릴 레이어부터 번호를 매긴다(Lottie는 목록 앞이 위).
        if "steam" in self.spec:
            n = self.spec["steam"]["count"]
            self.steam(top, next_ind())
            for _ in range(n - 1):
                next_ind()
        if "katsuobushi" in self.spec:
            flakes = self.katsuobushi(next_ind())
            for _ in range(len(flakes) - 1):
                next_ind()
            top.extend(flakes)
        if "ripple" in self.spec:
            top.extend(self.ripple(next_ind()))
            next_ind()
        if "coin" in self.spec:
            top.append(self.coin(next_ind()))
        if "sway" in self.spec:
            flicker_ind = next_ind() if "flicker" in self.spec else None
            moving = self.sway(img, assets, bottom, next_ind)
            if flicker_ind is not None:
                # 자식 레이어 좌표는 부모(초롱 그림)의 레이어 좌표 = 캔버스 좌표라 그대로 쓴다.
                shapes, ks = self.flicker(moving)
                top.append(shape_layer(flicker_ind, "glow", shapes, self.frames, ks, parent=moving))
        else:
            assets.append(image_asset("art", img))
            bottom.append(image_layer(next_ind(), "art", self.frames, "art"))
        layers = top + bottom
        still = self.frames if not self.loop else 0
        return {
            "v": "5.7.0", "fr": self.fps, "ip": 0, "op": self.frames, "w": self.c, "h": self.c,
            "nm": f"word_{self.name}", "ddd": 0, "assets": assets, "layers": layers,
            "markers": [{"tm": still, "cm": "still", "dr": 0}],
            "kt": {"loop": self.loop, "still": still},
        }


def main() -> int:
    argv = sys.argv[1:]
    src = None
    if "--src" in argv:
        # 후보 그림으로 미리 만들어 앱에서 움직임을 확인할 때: --src <후보 PNG> <이름 하나>. 커밋하지 않는다.
        at = argv.index("--src")
        src = Path(argv[at + 1]).resolve()
        argv = argv[:at] + argv[at + 2:]
    args = [a for a in argv if not a.startswith("--")]
    if src is not None and len(args) != 1:
        print("--src는 그림 이름 하나와 함께 쓴다", file=sys.stderr)
        return 2
    test_steam = "--test-steam" in sys.argv
    data = json.loads(MOTION.read_text())
    kinds, words = data["kinds"], data["words"]
    if test_steam:
        if len(args) != 1:
            print("--test-steam은 그림 이름 하나와 함께 쓴다", file=sys.stderr)
            return 2
        words = {args[0]: {"measured": False,
                           "steam": {"anchor": [0.5, 0.30], "count": 3, "spacing": 0.12, "length": 0.16, "widthScale": 1.0}}}
    known = set(art_names())
    targets = args or list(words)
    unknown = [n for n in targets if n not in words or n not in known]
    if unknown:
        print(f"움직임 대상이 아니거나 단어 데이터의 art에 없는 이름: {unknown}", file=sys.stderr)
        return 2
    built, skipped = [], []
    for name in targets:
        spec = {k: v for k, v in words[name].items() if not k.startswith("_") and k != "measured"}
        img = prepare(name, steam="steam" in spec, src=src)
        if img is None:
            skipped.append(name)
            continue
        builder = Builder(name, spec, kinds, data["canvas"], data["strokeWidth"])
        doc = builder.build(img)
        dst = OUT / f"word_{name}.lottie.json"
        dst.write_text(json.dumps(doc, separators=(",", ":")))
        built.append(name)
        flag = "" if words[name].get("measured") else "  (기준점 시작값, 그림 위에서 재야 함)"
        print(f"{name:10} {', '.join(spec):24} {builder.frames}프레임 @{builder.fps}fps "
              f"{'반복' if builder.loop else '한 번'} → {dst.relative_to(ROOT)} ({dst.stat().st_size // 1024}KB){flag}")
        for note in builder.notes:
            print(f"  ! {note}")
    print(f"\n만듦 {len(built)}개, 정지 그림이 없어 건너뜀 {len(skipped)}개")
    if skipped:
        print("건너뜀: " + ", ".join(skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
