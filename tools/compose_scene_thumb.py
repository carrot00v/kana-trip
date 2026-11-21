#!/usr/bin/env python3
"""단어 그림(투명 배경 원본)을 장면 그림 원본 규격으로 옮긴다 (docs/design/scene-art/brief.md 3번, 5번 표).

  .venv/bin/python tools/compose_scene_thumb.py sushi sushi

인자: 장면 id, 단어 그림 이름(art). 새 그림을 만들지 않는다(이미지 모델을 쓰지 않음).

입력: docs/design/word-art/source/word-{art}.png (1024px, tools/remove_bg.py로 바탕을 지운 투명 원본, 스티커 테두리 없음)
출력: docs/design/scene-art/source/thumb-{장면 id}.png (1024×1024 불투명)

처리: 알파 경계 상자로 자른 뒤 긴 변을 1024의 70%(brief.md 3번 "그림의 약 70%, 둘레에 고른 여백")로 맞추고
가운데에 놓는다. 바탕은 그 장면의 칸 색(place_scene_thumbs.py의 SCENES)으로 채운다.
이어서 tools/place_scene_thumbs.py(SceneThumb-*)와 tools/build_map_art.py(map_building_*)를 돌린다.

2026-11-21: 스시집 장면 그림을 단어 그림 すし(타마고·연어가 나무 받침에 놓인 그림)로 바꿀 때 만들었다(사용자 지시, 이슈 #8).
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from place_scene_thumbs import SCENES  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
WORD_ART = ROOT / "docs/design/word-art/source"
SCENE_ART = ROOT / "docs/design/scene-art/source"
SIDE = 1024
FILL = 0.70
ALPHA_FLOOR = 8


def compose(scene_id: str, art: str) -> Path:
    cell, _ = SCENES[scene_id]
    src = Image.open(WORD_ART / f"word-{art}.png").convert("RGBA")
    box = src.getchannel("A").point(lambda a: 255 if a >= ALPHA_FLOOR else 0).getbbox()
    obj = src.crop(box)
    scale = SIDE * FILL / max(obj.size)
    obj = obj.resize((round(obj.width * scale), round(obj.height * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIDE, SIDE), cell + (255,))
    canvas.alpha_composite(obj, ((SIDE - obj.width) // 2, (SIDE - obj.height) // 2))
    out = SCENE_ART / f"thumb-{scene_id}.png"
    canvas.convert("RGB").save(out, optimize=True)
    return out


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    out = compose(sys.argv[1], sys.argv[2])
    print(f"{out.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
