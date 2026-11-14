#!/usr/bin/env python3
"""고른 단어 그림을 600px 정사각으로 맞춰 앱 에셋 `WordArt-{이름}`으로 넣는다 (docs/design/word-art.md 9.1).

  .venv/bin/python tools/place_word_art.py              # 있는 그림 모두
  .venv/bin/python tools/place_word_art.py tonkatsu     # 골라서

입력
- docs/design/word-art/source/word-{이름}.png (사람이 고른 그림, 1024px). 이름은 hiragana_scenes.json 단어의 `art` 값.
- 아직 source/에 없고 tools/word_art.json에 item-art 복사(copyFrom)가 적힌 단어(tonkatsu, kitsune)는
  docs/design/item-art/source/의 원래 그림을 바로 읽는다(source/에 복사하는 일은 그림 생성 도구가 한다).
- 그림이 아직 없는 단어는 건너뛰고 목록만 출력한다. 그림이 생성되어 들어오는 대로 다시 돌리면 된다.
  같은 입력이면 결과가 같아서 여러 번 돌려도 안전하다.

처리
1. 바탕이 투명하지 않으면(네 귀퉁이가 불투명) tools/remove_bg.py로 단색 바탕을 지운다.
2. 대상의 경계 상자(투명이 아닌 픽셀)를 재서 600px 캔버스에 놓는다.
   - 보통 그림: 긴 변을 캔버스의 0.80으로, 가로·세로 가운데.
   - 김 그림(tools/word_motion.json에서 움직임에 steam이 있는 단어): 긴 변을 0.72로, 가로 가운데, 아래 끝을 0.90에.
     김이 오를 위 공간을 남긴다.
3. 플랫폼에 묶이지 않는 결과를 build/word-art/word-{이름}.png에 두고(안드로이드용, tools/build_word_lottie.py도 이것을 쓴다),
   iOS 에셋 카탈로그 KanaTrip/Assets.xcassets/WordArt-{이름}.imageset(Single Scale)에 복사한다.

필요: Pillow (tools/requirements.txt)
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from remove_bg import remove_bg  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "design" / "word-art" / "source"
WORD_ART = ROOT / "tools" / "word_art.json"
MOTION = ROOT / "tools" / "word_motion.json"
SCENES = ROOT / "KanaTrip" / "Resources" / "hiragana_scenes.json"
NEUTRAL = ROOT / "build" / "word-art"
ASSETS = ROOT / "KanaTrip" / "Assets.xcassets"

CANVAS = 600
NORMAL_SIDE = 0.80
STEAM_SIDE = 0.72
STEAM_BOTTOM = 0.90
# 이 불투명도보다 옅은 픽셀은 경계 상자에서 뺀다(바탕 지우기의 옅은 테).
ALPHA_FLOOR = 8


def art_names() -> list[str]:
    """단어 데이터의 `art` 값(중복 없이, 데이터 순서)."""
    data = json.loads(SCENES.read_text())
    names: list[str] = []
    for scene in data["scenes"]:
        for step in scene["steps"]:
            for word in step["words"]:
                if word.get("art") and word["art"] not in names:
                    names.append(word["art"])
    return names


def steam_names() -> set[str]:
    words = json.loads(MOTION.read_text())["words"]
    return {name for name, spec in words.items() if "steam" in spec}


def source_path(name: str) -> Path | None:
    own = SOURCE / f"word-{name}.png"
    if own.exists():
        return own
    for word in json.loads(WORD_ART.read_text())["words"]:
        copy = word.get("copyFrom", "")
        if word["name"] == name and "item-art" in copy and (ROOT / copy).exists():
            return ROOT / copy
    return None


def transparent_background(img: Image.Image) -> bool:
    if img.mode != "RGBA":
        return False
    w, h = img.size
    return all(img.getpixel(p)[3] < 16 for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)))


def prepare(name: str, steam: bool | None = None) -> Image.Image | None:
    """600px 정사각 RGBA. 그림이 없으면 None."""
    src = source_path(name)
    if src is None:
        return None
    img = Image.open(src)
    if not transparent_background(img):
        img, _, _ = remove_bg(img)
    img = img.convert("RGBA")
    mask = img.getchannel("A").point(lambda a: 255 if a > ALPHA_FLOOR else 0)
    box = mask.getbbox()
    if box is None:
        return None
    subject = img.crop(box)
    if steam is None:
        steam = name in steam_names()
    side = (STEAM_SIDE if steam else NORMAL_SIDE) * CANVAS
    scale = side / max(subject.size)
    subject = subject.resize((max(1, round(subject.width * scale)), max(1, round(subject.height * scale))), Image.LANCZOS)
    left = (CANVAS - subject.width) // 2
    top = round(STEAM_BOTTOM * CANVAS) - subject.height if steam else (CANVAS - subject.height) // 2
    canvas = Image.new("RGBA", (CANVAS, CANVAS))
    canvas.alpha_composite(subject, (left, top))
    return canvas


def write_imageset(asset: str, img: Image.Image) -> None:
    folder = ASSETS / f"{asset}.imageset"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    img.save(folder / f"{asset}.png", optimize=True)
    contents = {
        "images": [{"filename": f"{asset}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def main() -> int:
    names = art_names()
    wanted = sys.argv[1:] or names
    unknown = [n for n in wanted if n not in names]
    if unknown:
        print(f"단어 데이터의 art에 없는 이름: {unknown}", file=sys.stderr)
        return 2
    NEUTRAL.mkdir(parents=True, exist_ok=True)
    steam = steam_names()
    placed, missing = [], []
    for name in wanted:
        img = prepare(name, name in steam)
        if img is None:
            missing.append(name)
            continue
        img.save(NEUTRAL / f"word-{name}.png", optimize=True)
        write_imageset(f"WordArt-{name}", img)
        placed.append(name)
        src = source_path(name)
        print(f"{name:12} {'김 그림' if name in steam else '보통':6} ← {src.relative_to(ROOT)}")
    stale = sorted(p.name[len("WordArt-"):-len(".imageset")] for p in ASSETS.glob("WordArt-*.imageset")
                   if p.name[len("WordArt-"):-len(".imageset")] not in names)
    print(f"\n배치 {len(placed)}개, 그림 없음 {len(missing)}개")
    if missing:
        print("그림 없음(건너뜀): " + ", ".join(missing))
    if stale:
        print("단어 데이터에 없는 WordArt 에셋(지우지 않음): " + ", ".join(stale))
    return 0


if __name__ == "__main__":
    sys.exit(main())
