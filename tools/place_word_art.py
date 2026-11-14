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
   바탕 지우기에서 남은 작은 조각(가장 큰 덩어리의 1% 미만)과 가는 호(5% 미만이고 가늘고 긴 것, 스티커 테두리 부스러기)는 지운다.
   남겨 두면 경계 상자가 커져 대상이 가운데에서 밀린다.
2. 대상의 경계 상자(투명이 아닌 픽셀)를 잘라(트림) 600px 캔버스에 놓는다.
   - 보통 그림: 긴 변을 캔버스의 0.80으로, 가로·세로 가운데.
   - 김 그림(tools/word_motion.json에서 움직임에 steam이 있는 단어): 긴 변을 0.72로, 가로 가운데, 아래 끝을 0.90에.
     김이 오를 위 공간을 남긴다.
3. 그림 속 가나가 있는 단어(KANA_IN_ART, 지금 yu)는 그림의 빈 원(옅은 크림색의 둥근 면 가운데 가장 큰 것)을 찾아
   그 안에 KanjiVG 획으로 가나를 합성한다(place_item_art.py의 kana_glyph, item-art/brief.md 1.2).
   원을 그림에서 찾으므로 그림을 다시 골라도 좌표를 고칠 필요가 없다. 원을 못 찾으면 멈춘다.
4. 플랫폼에 묶이지 않는 결과를 build/word-art/word-{이름}.png에 두고(안드로이드용, tools/build_word_lottie.py도 이것을 쓴다),
   iOS 에셋 카탈로그 KanaTrip/Assets.xcassets/WordArt-{이름}.imageset(Single Scale)에 복사한다.

필요: Pillow (tools/requirements.txt)
"""
import json
import shutil
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from place_item_art import kana_glyph  # noqa: E402
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
# 가장 큰 덩어리 넓이에 대한 이 비율보다 작은 덩어리는 부스러기로 보고 지운다.
SPECK_RATIO = 0.01
# 가늘고 긴 조각(남은 스티커 테두리의 호)은 이 비율까지 지운다. 가늘다 = 넓이 / 바깥 사각형 넓이가 THIN_FILL 미만.
THIN_RATIO = 0.05
THIN_FILL = 0.15
# 덩어리를 셀 때 줄여 보는 격자(픽셀). 1024px 원본이면 4px 칸.
SPECK_GRID = 256

# 그림 속 가나 (word-images.md 1번 "글자", item-art/brief.md 1.2). 그림의 빈 원 안에 합성한다.
# 색은 남색 노렌 위 크림색 원에 진갈색 외곽선 색(えき 역명판과 같음). 크기는 원 지름에 대한 글자 칸 한 변의 비율.
KANA_IN_ART = {
    "yu": {"text": "ゆ", "color": "#4A2219", "scale": 0.74},
}


def components(mask: list[list[bool]]) -> list[list[tuple[int, int]]]:
    """4방향 연결 덩어리. 큰 것부터."""
    h, w = len(mask), len(mask[0])
    seen = [[False] * w for _ in range(h)]
    out = []
    for y in range(h):
        for x in range(w):
            if not mask[y][x] or seen[y][x]:
                continue
            seen[y][x] = True
            queue, cells = deque([(x, y)]), []
            while queue:
                cx, cy = queue.popleft()
                cells.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            out.append(cells)
    return sorted(out, key=len, reverse=True)


def drop_specks(img: Image.Image) -> Image.Image:
    """대상 덩어리에서 떨어진 조각을 지운다(줄인 격자에서 세고 원본에서 지움).

    지우는 것: 가장 큰 덩어리의 SPECK_RATIO보다 작은 덩어리, THIN_RATIO보다 작고 가늘고 긴 덩어리,
    그리고 격자에서 덩어리로 잡히지 않을 만큼 옅은 픽셀(남은 덩어리의 이웃 칸 밖에 있는 것 모두).
    """
    alpha = img.getchannel("A")
    small = alpha.resize((SPECK_GRID, SPECK_GRID), Image.BOX)
    grid = [[small.getpixel((x, y)) > ALPHA_FLOOR for x in range(SPECK_GRID)] for y in range(SPECK_GRID)]
    parts = components(grid)
    if not parts:
        return img
    biggest = len(parts[0])

    def speck(cells: list[tuple[int, int]]) -> bool:
        if len(cells) < biggest * SPECK_RATIO:
            return True
        xs, ys = [c[0] for c in cells], [c[1] for c in cells]
        fill = len(cells) / ((max(xs) - min(xs) + 1) * (max(ys) - min(ys) + 1))
        return len(cells) < biggest * THIN_RATIO and fill < THIN_FILL

    keep = Image.new("L", (SPECK_GRID, SPECK_GRID), 0)
    for cells in [parts[0]] + [c for c in parts[1:] if not speck(c)]:
        for x, y in cells:
            keep.putpixel((x, y), 255)
    # 남은 덩어리의 이웃 칸까지 살린다(외곽선의 옅은 가장자리를 깎지 않게).
    keep = keep.filter(ImageFilter.MaxFilter(3)).resize(img.size, Image.NEAREST)
    out = img.copy()
    out.putalpha(ImageChops.multiply(alpha, keep))
    return out


def find_blank_circle(img: Image.Image) -> tuple[float, float, float] | None:
    """그림 안의 빈 원(옅은 크림색의 둥근 면)을 찾아 (가운데 x, y, 지름)을 돌려준다. 가장 큰 것."""
    w, h = img.size
    data = img.load()
    mask = []
    for y in range(h):
        row = []
        for x in range(w):
            r, g, b, a = data[x, y]
            row.append(a > 200 and min(r, g, b) > 200 and max(r, g, b) - min(r, g, b) < 60)
        mask.append(row)
    best = None
    for cells in components(mask):
        if len(cells) < (w * h) * 0.005:
            break
        xs = [c[0] for c in cells]
        ys = [c[1] for c in cells]
        bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
        fill = len(cells) / (bw * bh)
        # 원의 넓이 / 바깥 사각형 넓이 = π/4 ≈ 0.785
        if 0.70 <= fill <= 0.86 and 0.85 <= bw / bh <= 1.18:
            best = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (bw + bh) / 2)
            break
    return best


def compose_kana(name: str, img: Image.Image) -> Image.Image:
    spec = KANA_IN_ART.get(name)
    if spec is None:
        return img
    circle = find_blank_circle(img)
    if circle is None:
        raise SystemExit(f"{name}: 가나를 넣을 빈 원을 그림에서 찾지 못했다. 그림을 확인한다")
    cx, cy, diameter = circle
    size = round(diameter * spec["scale"])
    glyph = kana_glyph(spec["text"], size, spec["color"])
    out = img.copy()
    out.alpha_composite(glyph, (round(cx - size / 2), round(cy - size / 2)))
    return out


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


def prepare(name: str, steam: bool | None = None, src: Path | None = None) -> Image.Image | None:
    """600px 정사각 RGBA. 그림이 없으면 None. src를 주면 source/ 대신 그 그림을 쓴다(후보 미리 보기용)."""
    src = src or source_path(name)
    if src is None:
        return None
    img = Image.open(src)
    if not transparent_background(img):
        img, _, _ = remove_bg(img)
    img = drop_specks(img.convert("RGBA"))
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
    return compose_kana(name, canvas)


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
