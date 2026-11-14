"""앱 아이콘을 만든다. 기리의 기본 표정을 단색 바탕 위에 크게 둔다.

캐릭터 부품은 make_onigiri_svg.py의 함수를 그대로 쓴다. 그림자와 다리는 작은 크기에서
지저분해 보여서 뺐다. 글자는 넣지 않는다. 모서리는 둥글리지 않는다(iOS가 마스크한다).

실행: python3 tools/make_app_icon.py
산출물: docs/design/character/app-icon.svg (원본)
        KanaTrip/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png (1024, 투명 없음)
PNG 변환은 tools/svg_to_png.swift(macOS AppKit)로 한다.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_onigiri_svg import ARMS, body_clip_def, body_layers, body_path, face, hat, scarf  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SVG_OUT = ROOT / "docs/design/character/app-icon.svg"
PNG_OUT = ROOT / "KanaTrip/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
CONVERTER = Path(__file__).resolve().parent / "svg_to_png.swift"

SIZE = 1024
BG = "#F6B92B"   # 노랑 강조(Highlight). 크림 바탕은 흰 밥과 구분이 외곽선뿐이라 작은 크기에서 흐려진다
SCALE = 2.9      # 캐릭터 좌표 1 = 아이콘 2.9px. 몸통 폭 약 248 → 약 720px(70%)
CENTER_X = 150   # 캐릭터 몸통의 가운데
TOP_Y = 12       # 캐릭터의 맨 위(모자 외곽선)
TOP_MARGIN = 52  # 아이콘 위쪽 여백(px)


def icon_svg(bg=BG, scale=SCALE):
    body = body_path()
    tx = SIZE / 2 - CENTER_X * scale
    ty = TOP_MARGIN - TOP_Y * scale
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}" width="{SIZE}" height="{SIZE}">
  <defs>
    {body_clip_def(body)}
  </defs>
  <rect width="{SIZE}" height="{SIZE}" fill="{bg}"/>
  <g transform="translate({tx:.1f} {ty:.1f}) scale({scale})">
  <!-- 팔 -->
  {ARMS["default"]}

  <!-- 몸통 -->
  {body_layers(body)}
{scarf()}
{hat()}
{face("default")}
  </g>
</svg>
'''


def to_png(svg_path, png_path, size=SIZE):
    with tempfile.TemporaryDirectory() as tmp:
        exe = Path(tmp) / "svg_to_png"
        subprocess.run(["swiftc", "-O", str(CONVERTER), "-o", str(exe)], check=True)
        subprocess.run([str(exe), str(svg_path), str(png_path), str(size)], check=True)


if __name__ == "__main__":
    SVG_OUT.write_text(icon_svg(), encoding="utf-8")
    print("wrote", SVG_OUT)
    PNG_OUT.parent.mkdir(parents=True, exist_ok=True)
    to_png(SVG_OUT, PNG_OUT)
    print("wrote", PNG_OUT)
