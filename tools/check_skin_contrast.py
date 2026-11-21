#!/usr/bin/env python3
"""앱 스킨 대비·색 거리 검사 (docs/design/app-skin.md 2.4).

KanaTrip/Resources/skins.json을 읽어 스킨 × 모드(light, dark) × (보통, 대비 증가)마다
2.4 표의 조건을 계산하고 표로 출력한다. 하나라도 못 넘으면 1로 끝난다.

표준 라이브러리만 쓴다. 같은 검사를 Swift 단위 테스트 SkinContrastTests가 한다.

    python3 tools/check_skin_contrast.py            # 전체 표
    python3 tools/check_skin_contrast.py --failures # 못 넘은 줄만
    python3 tools/check_skin_contrast.py --markdown # app-skin.md 3.7에 붙일 마크다운 표
"""

import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKINS = ROOT / "KanaTrip" / "Resources" / "skins.json"

# 2.4 기준
LUMINANCE_LIGHT_MIN = 0.72
LUMINANCE_DARK_MAX = 0.029
CARD_QUIET_MIN = {"light": 1.07, "dark": 1.16}
TEXT_MIN = 4.5
NON_TEXT_MIN = 3.0
SECONDARY_MIX = 0.15
VERDICT_DELTA_E_MIN = 30.0
VERDICT_HUE_MIN = 30.0
VERDICT_CHROMA_FOR_HUE = 30.0
HINT_DELTA_E_MIN = 20.0
# 설계 값 그대로 두고 기준만 못 넘는 조합 (app-skin.md 3.7 구현 메모). 결과에 "예외"로 찍고 종료 코드에 넣지 않는다.
# 여기에 없는 조합이 실패하면 검사가 실패한다. 설계에서 값이나 기준을 고치면 이 목록에서 지운다.
KNOWN_EXCEPTIONS = {
    ("default", "light", "CardBackground / Quiet"): "기준 1.07은 기본 스킨 값 1.065를 올림한 값이라 기본 스킨 자신이 못 넘는다",
    ("noren", "dark", "CardBackground / Quiet"): "1.158. 기본 스킨 다크 1.167보다 조금 낮다. 설계 확인 대기",
    ("eki", "dark", "CardBackground / Quiet"): "1.137. 기본 스킨 다크 1.167보다 낮다. 설계 확인 대기(#171A18이면 1.160)",
}

# 고정 토큰 / 바탕 (visual-rules.md 1.4): 글자 4.5, 글자 아닌 표시 3
FIXED_ON_BACKGROUND = [
    ("Ink", TEXT_MIN),
    ("InkSecondary", TEXT_MIN),
    ("Correct", NON_TEXT_MIN),
    ("Wrong", NON_TEXT_MIN),
    ("HighlightStrong", NON_TEXT_MIN),
    ("Outline", NON_TEXT_MIN),
]


def parse_hex(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))


def to_hex(rgb):
    return "#" + "".join(f"{round(c * 255):02X}" for c in rgb)


def linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(rgb):
    r, g, b = (linear(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def mix(base, top, amount):
    """sRGB 값에서 섞는다(SwiftUI·Compose의 기본 합성과 같다)."""
    return tuple(b * (1 - amount) + t * amount for b, t in zip(base, top))


def lab(rgb):
    r, g, b = (linear(c) for c in rgb)
    x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
    y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b

    def f(t):
        return t ** (1 / 3) if t > (6 / 29) ** 3 else t / (3 * (6 / 29) ** 2) + 4 / 29

    fx, fy, fz = f(x / 0.95047), f(y / 1.0), f(z / 1.08883)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def delta_e(a, b):
    la, lb = lab(a), lab(b)
    return math.sqrt(sum((p - q) ** 2 for p, q in zip(la, lb)))


def chroma(rgb):
    _, a, b = lab(rgb)
    return math.hypot(a, b)


def hue_angle(rgb):
    _, a, b = lab(rgb)
    return math.degrees(math.atan2(b, a)) % 360


def hue_difference(a, b):
    d = abs(hue_angle(a) - hue_angle(b)) % 360
    return min(d, 360 - d)


def hsv(rgb):
    r, g, b = rgb
    mx, mn = max(rgb), min(rgb)
    d = mx - mn
    if d == 0:
        h = 0.0
    elif mx == r:
        h = (60 * ((g - b) / d)) % 360
    elif mx == g:
        h = 60 * ((b - r) / d) + 120
    else:
        h = 60 * ((r - g) / d) + 240
    s = 0 if mx == 0 else d / mx
    return h, s, mx


def hue_banned(rgb):
    """2.4 마지막 줄: 125°~160°(채도 25% 이상), 330°~359°."""
    h, s, _ = hsv(rgb)
    if s == 0:
        return False
    return (125 <= h <= 160 and s >= 0.25) or (330 <= h < 360)


def load(path=SKINS):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def base_color(data, name, mode, high_contrast):
    token = data["base"][name]
    if high_contrast and "highContrast" in token:
        return parse_hex(token["highContrast"][mode])
    return parse_hex(token[mode])


def skin_color(skin, name, mode):
    value = skin["colors"].get(name)
    return parse_hex(value[mode]) if value else None


def exception_reason(skin, mode, what):
    """알려진 예외면 이유. 대비 증가(-hc)는 보통 모드와 같은 예외를 쓴다."""
    return KNOWN_EXCEPTIONS.get((skin, mode.removesuffix("-hc"), what))


def check(data):
    """(스킨, 모드, 조합, 값, 기준, 결과) 줄 목록. 결과는 "통과", "실패", "예외"."""
    rows = []

    def add(skin, mode, what, value, rule, ok):
        result = "통과" if ok else ("예외" if exception_reason(skin, mode, what) else "실패")
        rows.append((skin, mode, what, value, rule, result))

    for skin in data["skins"]:
        sid = skin["id"]
        for mode in ("light", "dark"):
            for hc in (False, True):
                label = mode + ("-hc" if hc else "")
                bg = skin_color(skin, "AppBackground", mode)
                quiet = skin_color(skin, "AppBackgroundQuiet", mode)
                accent = skin_color(skin, "AccentColor", mode)
                accent_fg = skin_color(skin, "AccentForeground", mode)
                ink = skin_color(skin, "PatternInk", mode)
                opacity = skin["patternOpacity"][mode]
                card = base_color(data, "CardBackground", mode, hc)
                # 대비 증가: 강·중 화면도 Quiet, 무늬 없음 (2.5)
                screen_bgs = [("Quiet", quiet)]
                if not hc:
                    screen_bgs.insert(0, ("AppBackground", bg))
                    if skin["images"]["pattern"] and ink and opacity > 0:
                        screen_bgs.append(("무늬 픽셀", mix(bg, ink, opacity)))

                for name, color in screen_bgs:
                    lum = luminance(color)
                    if mode == "light":
                        add(sid, label, f"{name} 휘도", lum, f">= {LUMINANCE_LIGHT_MIN}", lum >= LUMINANCE_LIGHT_MIN)
                    else:
                        add(sid, label, f"{name} 휘도", lum, f"<= {LUMINANCE_DARK_MAX}", lum <= LUMINANCE_DARK_MAX)

                ratio = contrast(card, quiet)
                add(sid, label, "CardBackground / Quiet", ratio, f">= {CARD_QUIET_MIN[mode]}", ratio >= CARD_QUIET_MIN[mode])

                ratio = contrast(accent_fg, accent)
                add(sid, label, "AccentForeground / AccentColor", ratio, f">= {TEXT_MIN}", ratio >= TEXT_MIN)

                for name, color in screen_bgs + [("CardBackground", card)]:
                    ratio = contrast(accent, color)
                    add(sid, label, f"AccentColor / {name}", ratio, f">= {NON_TEXT_MIN}", ratio >= NON_TEXT_MIN)

                for name, color in screen_bgs:
                    if name == "무늬 픽셀":
                        continue
                    secondary = mix(color, accent, SECONDARY_MIX)
                    ratio = contrast(accent, secondary)
                    add(sid, label, f"AccentColor / 보조 버튼 바탕({name})", ratio, f">= {TEXT_MIN}", ratio >= TEXT_MIN)

                for token, minimum in FIXED_ON_BACKGROUND:
                    fixed = base_color(data, token, mode, hc)
                    for name, color in screen_bgs:
                        ratio = contrast(fixed, color)
                        add(sid, label, f"{token} / {name}", ratio, f">= {minimum}", ratio >= minimum)

                # 강조색과 판정색·힌트색의 거리 (대비 증가와 상관없이 같은 값이지만 같이 센다)
                for token in ("Wrong", "Correct"):
                    other = base_color(data, token, mode, hc)
                    de = delta_e(accent, other)
                    add(sid, label, f"AccentColor ΔE {token}", de, f">= {VERDICT_DELTA_E_MIN}", de >= VERDICT_DELTA_E_MIN)
                    if chroma(accent) >= VERDICT_CHROMA_FOR_HUE:
                        dh = hue_difference(accent, other)
                        add(sid, label, f"AccentColor 색상각 차 {token}", dh, f">= {VERDICT_HUE_MIN}°", dh >= VERDICT_HUE_MIN)
                for token in ("HighlightStrong", "Highlight"):
                    other = base_color(data, token, mode, hc)
                    de = delta_e(accent, other)
                    add(sid, label, f"AccentColor ΔE {token}", de, f">= {HINT_DELTA_E_MIN}", de >= HINT_DELTA_E_MIN)

                if not hc:
                    for name in ("AppBackground", "AppBackgroundQuiet", "PatternInk"):
                        color = skin_color(skin, name, mode)
                        if color is None:
                            continue
                        h, s, _ = hsv(color)
                        add(sid, label, f"{name} HSV 색상 {to_hex(color)}", h, "금지 범위 밖", not hue_banned(color))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--failures", action="store_true", help="못 넘은 줄만 출력")
    parser.add_argument("--markdown", action="store_true", help="마크다운 표로 출력")
    parser.add_argument("--file", type=Path, default=SKINS)
    args = parser.parse_args()

    data = load(args.file)
    rows = check(data)
    failures = [r for r in rows if r[5] == "실패"]
    exceptions = [r for r in rows if r[5] == "예외"]
    shown = [r for r in rows if r[5] != "통과"] if args.failures else rows
    if args.markdown:
        print("| 스킨 | 모드 | 조합 | 값 | 기준 | 결과 |")
        print("|---|---|---|---|---|---|")
        for sid, mode, what, value, rule, ok in shown:
            print(f"| {sid} | {mode} | {what} | {value:.3f} | {rule} | {ok} |")
    else:
        print(f"{'스킨':8} {'모드':9} {'조합':44} {'값':>9}  {'기준':12} 결과")
        for sid, mode, what, value, rule, ok in shown:
            print(f"{sid:8} {mode:9} {what:44} {value:9.3f}  {rule:12} {ok}")
    print(f"\n{len(rows)}개 검사, 실패 {len(failures)}개, 알려진 예외 {len(exceptions)}개")
    for (sid, mode, what), reason in KNOWN_EXCEPTIONS.items():
        print(f"  예외 {sid} {mode} {what}: {reason}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
