#!/usr/bin/env python3
"""리워드 아이템 그림 후보를 로컬 Z-Image Turbo로 뽑는다 (docs/design/item-art/brief.md).

  .venv/bin/python tools/gen_item_art.py kippu noren yu --count 4
  .venv/bin/python tools/gen_item_art.py --list

아이템마다 items.json의 prompt 앞뒤에 공통 문장을 붙여 gen_image.py로 생성하고,
모자·두건·손 아이템은 tools/remove_bg.py로 바탕을 지워 투명 PNG를 함께 만든다.
결과: docs/design/item-art/source/candidates/{id}_{seed}.png (원본), {id}_{seed}-cut.png (투명)
고른 한 장을 source/{id}.png로 복사하는 일은 사람이 한다 (brief.md 4번).

brief.md 3번의 공통 프롬프트는 참고 이미지(onigiri-default.png)를 함께 넘기는 모델을 기준으로 썼다.
Z-Image Turbo는 글로만 지시하므로, 참고 이미지 대신 기리 화풍을 글로 풀어 쓰고
2026-11-14 시험에서 나온 문제(얼굴이 생김, 바닥 그림자)를 막는 문장을 더했다.
"""

import argparse
import json
import random
import subprocess
import sys
from pathlib import Path

from PIL import Image

from remove_bg import remove_bg

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "docs" / "design" / "item-art"
OUT = ART / "source" / "candidates"
GEN = ROOT / "tools" / "gen_image.py"

# 기리의 화풍 (onigiri-default.png를 글로 옮김)
STYLE = (
    "Cute flat sticker illustration in a simple Japanese kawaii sticker style: "
    "thick uniform dark chocolate brown outlines (#4A2219) around every shape, flat solid fills, "
    "rounded soft shapes, no gradients, no texture, no shading, no highlights, no drop shadow."
)
PALETTE = (
    "Use only these soft colors: warm off-white rice white, pale cream, dark indigo blue, pale sky blue, "
    "warm wood brown, warm yellow, soft orange red, soft pink, muted moss olive, plum purple. "
    "No bright green, no crimson or magenta."
)
OBJECT_RULES = (
    "Single isolated object, centered, generous empty margin around it. "
    "The object is not a character: it has no face, no eyes, no mouth, no blush. "
    "No ground shadow, no floor, no character, no hands, no text, no letters, no numbers, no logo. "
    "Plain solid flat light gray background filling the whole image."
)
BACKGROUND_RULES = (
    "Square 1:1 background scene filling the whole image edge to edge, no border. "
    "Keep the central area light and nearly empty because a character will stand in front of it; "
    "put details near the edges. No people, no characters, no faces on objects, no text, no letters, no numbers."
)


def load_items() -> list[dict]:
    return json.loads((ART / "items.json").read_text())["items"]


def build_prompt(item: dict) -> str:
    rules = BACKGROUND_RULES if item["slot"] == "background" else OBJECT_RULES
    return f"{STYLE} {PALETTE} Subject: {item['prompt']} {rules}"


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("ids", nargs="*", help="아이템 id (items.json)")
    p.add_argument("--count", type=int, default=4)
    p.add_argument("--seed", type=int, help="첫 시드 (없으면 무작위)")
    p.add_argument("--list", action="store_true", help="아이템 목록만 보여 준다")
    a = p.parse_args()

    items = {i["id"]: i for i in load_items()}
    if a.list:
        for i in items.values():
            print(f"{i['id']:10} {i['slot']:10} {i['kana']}  {i['nameKo']}")
        return 0
    unknown = [x for x in a.ids if x not in items]
    if not a.ids or unknown:
        print(f"아이템 id를 주세요. 모르는 id: {unknown}" if unknown else "아이템 id를 주세요 (--list)")
        return 2

    OUT.mkdir(parents=True, exist_ok=True)
    seed = a.seed if a.seed is not None else random.randint(0, 2**31 - 1)
    # 아이템을 번갈아 돌려서 중간에 멈춰도 모든 아이템의 후보를 하나 이상 볼 수 있게 한다
    for n in range(a.count):
        for item_id in a.ids:
            item, s = items[item_id], seed + n
            print(f"[{n + 1}/{a.count}] {item_id} seed={s}", flush=True)
            r = subprocess.run([sys.executable, str(GEN), build_prompt(item), "--name", item_id,
                                "--seed", str(s), "--out", str(OUT)])
            if r.returncode != 0:
                continue
            src = OUT / f"{item_id}_{s}.png"
            if item["slot"] != "background":
                cut, _, ratio = remove_bg(Image.open(src))
                cut.save(src.with_name(f"{item_id}_{s}-cut.png"))
                print(f"  바탕 지움 {ratio * 100:.0f}%", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
