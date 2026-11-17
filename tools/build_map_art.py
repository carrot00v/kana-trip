#!/usr/bin/env python3
"""지도의 건물 카드와 단어 그림 스티커를 이미 있는 그림에서 다시 내보낸다 (docs/design/home-map.md 6.1, 7.2).

  .venv/bin/python tools/build_map_art.py

새 그림을 만들지 않는다(이미지 모델·ComfyUI를 쓰지 않음). 원본은 읽기만 한다.

입력
- 건물 카드: docs/design/scene-art/source/thumb-{장면 id}.png (1024px 정사각, 장면 그림 원본).
- 스티커: KanaTrip/Resources/map.json의 `stickers`에 적힌 그림 이름(tools/build_map.py가 고름)마다
  build/word-art/word-{art}.png(place_word_art.py 결과, 600px), 없으면 같은 결과를 담은 앱 에셋
  KanaTrip/Assets.xcassets/WordArt-{art}.imageset/WordArt-{art}.png.
  place_word_art.py가 그림 속 가나(ゆ, えき 표지판 등)를 합성한 결과라 word-art/source/의 날것보다 이것을 쓴다.

처리
- 건물 카드: LANCZOS로 192px(@2x), 288px(@3x). 정사각 그대로(모서리·테두리는 앱이 그린다).
- 스티커(@3x 기준): 투명 아닌 픽셀의 경계 상자로 자름 → 긴 변 147px → 알파를 둥글게 9px(3pt) 넓혀 #FFFDF7로 칠한 테두리
  → 그 바깥 1.5px(0.5pt) #4A2219 25% 선 → 168×168px 가운데. @2x(112px)는 @3x 결과를 LANCZOS로 줄인다.
  긴 변을 명세의 150px이 아니라 147px로 한 것은 150 + 테두리 9×2 + 선 1.5×2 = 171px이 168px 캔버스를 넘어
  바깥 선이 잘리기 때문이다(home-map.md 6.1 "구현 값").
  기울이기는 앱이 한다(그림은 똑바로). 라이트·다크 같은 그림 한 장.

출력
- build/map-art/map_building_{id}@2x.png, @3x.png, build/map-art/map_sticker_{art}@2x.png, @3x.png (플랫폼 중립 PNG).
- iOS 에셋 카탈로그 KanaTrip/Assets.xcassets/map_building_{id}.imageset, map_sticker_{art}.imageset (@2x, @3x).
  map.json에 없는 옛 map_sticker_* 에셋은 지운다.

필요: Pillow (tools/requirements.txt). 같은 입력이면 결과가 같다.
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SCENE_ART = ROOT / "docs" / "design" / "scene-art" / "source"
WORD_ART_NEUTRAL = ROOT / "build" / "word-art"
ASSETS = ROOT / "KanaTrip" / "Assets.xcassets"
MAP_JSON = ROOT / "KanaTrip" / "Resources" / "map.json"
OUT = ROOT / "build" / "map-art"

BUILDING_PX = {2: 192, 3: 288}

STICKER_CANVAS = 168  # @3x, 56pt
STICKER_LONG_SIDE = 147  # @3x, 49pt
BORDER = 9  # 3pt @3x
LINE = 1.5  # 0.5pt @3x
BORDER_COLOR = (0xFF, 0xFD, 0xF7)
LINE_COLOR = (0x4A, 0x22, 0x19)
LINE_ALPHA = 0.25
SUPER = 4  # 테두리를 넓힐 때 쓰는 확대 배율(가장자리를 부드럽게)
ALPHA_FLOOR = 8


def imageset(name: str, files: dict[int, Path]) -> None:
    """@2x·@3x imageset을 만든다(원래 있던 것은 지우고 새로)."""
    folder = ASSETS / f"{name}.imageset"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    images = [{"idiom": "universal", "scale": "1x"}]
    for scale in (2, 3):
        target = folder / f"{name}@{scale}x.png"
        shutil.copyfile(files[scale], target)
        images.append({"filename": target.name, "idiom": "universal", "scale": f"{scale}x"})
    contents = {
        "images": images,
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


# MARK: 건물 카드

def build_buildings(scene_ids: list[str]) -> list[str]:
    done = []
    for sid in scene_ids:
        src = SCENE_ART / f"thumb-{sid}.png"
        if not src.exists():
            print(f"  건물 {sid}: 원본 없음, 건너뜀 (앱은 SceneThumb-{sid} 또는 SF Symbol로 대신 그린다)")
            continue
        image = Image.open(src).convert("RGB")
        files = {}
        for scale, px in BUILDING_PX.items():
            out = OUT / f"map_building_{sid}@{scale}x.png"
            save_png(image.resize((px, px), Image.LANCZOS), out)
            files[scale] = out
        imageset(f"map_building_{sid}", files)
        done.append(sid)
    return done


# MARK: 스티커

def word_art_path(art: str) -> Path | None:
    for p in (WORD_ART_NEUTRAL / f"word-{art}.png",
              ASSETS / f"WordArt-{art}.imageset" / f"WordArt-{art}.png"):
        if p.exists():
            return p
    return None


def disk_offsets(radius: float) -> list[tuple[int, int]]:
    r = int(radius) + 1
    return [(dx, dy) for dy in range(-r, r + 1) for dx in range(-r, r + 1) if dx * dx + dy * dy <= radius * radius]


def dilate(mask: Image.Image, radius: float) -> Image.Image:
    """둥근 붓으로 넓힌다: 원 안의 모든 이동을 겹친 최댓값."""
    out = Image.new("L", mask.size, 0)
    for dx, dy in disk_offsets(radius):
        out = ImageChops.lighter(out, ImageChops.offset(mask, dx, dy))
    return out


def build_sticker(art: str) -> Image.Image:
    src = word_art_path(art)
    if src is None:
        raise FileNotFoundError(art)
    image = Image.open(src).convert("RGBA")
    alpha = image.getchannel("A").point(lambda a: 255 if a >= ALPHA_FLOOR else 0)
    box = alpha.getbbox()
    image = image.crop(box)
    w, h = image.size
    scale = STICKER_LONG_SIDE / max(w, h)
    size = (max(1, round(w * scale)), max(1, round(h * scale)))

    # 확대한 캔버스에서 테두리와 선을 만든 뒤 줄여 가장자리를 부드럽게 한다.
    big = STICKER_CANVAS * SUPER
    art_big = image.resize((size[0] * SUPER, size[1] * SUPER), Image.LANCZOS)
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    origin = ((big - art_big.width) // 2, (big - art_big.height) // 2)
    layer.paste(art_big, origin, art_big)
    # 테두리를 넓힐 기준 모양: 그림의 알파를 한 칸 넓혀 반 이상인 곳. 그림 사이 틈은 테두리를 넓히면서 메워진다.
    solid = layer.getchannel("A").filter(ImageFilter.MaxFilter(3)).point(lambda a: 255 if a >= 128 else 0)

    border_mask = dilate(solid, BORDER * SUPER)
    line_mask = dilate(border_mask, LINE * SUPER)

    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    line_layer = Image.new("RGBA", (big, big), LINE_COLOR + (0,))
    line_layer.putalpha(line_mask.point(lambda a: round(a * LINE_ALPHA)))
    canvas = Image.alpha_composite(canvas, line_layer)
    border_layer = Image.new("RGBA", (big, big), BORDER_COLOR + (0,))
    border_layer.putalpha(border_mask)
    canvas = Image.alpha_composite(canvas, border_layer)
    canvas = Image.alpha_composite(canvas, layer)
    return canvas.resize((STICKER_CANVAS, STICKER_CANVAS), Image.LANCZOS)


def build_stickers(arts: list[str]) -> list[str]:
    done = []
    for art in arts:
        if word_art_path(art) is None:
            print(f"  스티커 {art}: 단어 그림 없음, 건너뜀 (앱은 그 자리를 그리지 않는다)")
            continue
        at3 = build_sticker(art)
        at2 = at3.resize((STICKER_CANVAS * 2 // 3, STICKER_CANVAS * 2 // 3), Image.LANCZOS)
        files = {}
        for scale, img in ((2, at2), (3, at3)):
            out = OUT / f"map_sticker_{art}@{scale}x.png"
            save_png(img, out)
            files[scale] = out
        imageset(f"map_sticker_{art}", files)
        done.append(art)
    # map.json에서 빠진 옛 스티커 에셋을 지운다.
    keep = {f"map_sticker_{a}.imageset" for a in done}
    for folder in ASSETS.glob("map_sticker_*.imageset"):
        if folder.name not in keep:
            shutil.rmtree(folder)
    return done


def main() -> int:
    data = json.loads(MAP_JSON.read_text(encoding="utf-8"))
    scene_ids, arts = [], []
    for region in data["regions"]:
        for section in region["sections"]:
            if section["kind"] == "scene":
                scene_ids.append(section["scene"])
            for sticker in section["stickers"]:
                if sticker["art"] not in arts:
                    arts.append(sticker["art"])
    buildings = build_buildings(scene_ids)
    stickers = build_stickers(arts)
    print(f"건물 카드 {len(buildings)}장, 스티커 {len(stickers)}장 → {OUT.relative_to(ROOT)}, 에셋 카탈로그")
    return 0


if __name__ == "__main__":
    sys.exit(main())
