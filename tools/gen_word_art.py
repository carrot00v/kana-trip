#!/usr/bin/env python3
"""단어 그림 후보를 로컬 Z-Image Turbo로 우선순위별로 뽑는다 (docs/design/word-art/brief.md).

  .venv/bin/python tools/gen_word_art.py --priority 1            # 우선순위 1 전체, 단어당 1장
  .venv/bin/python tools/gen_word_art.py --only word-sushi word-ika --count 2
  .venv/bin/python tools/gen_word_art.py --priority 2 --dry-run  # 프롬프트만 출력

단어 목록은 tools/word_art.json (docs/content/word-images.md 2·3번을 옮긴 것). 순서도 그 문서 3번을 따른다.
프롬프트는 gen_item_art.py의 STYLE + PALETTE + "Subject: " + subject + OBJECT_RULES로 아이템과 똑같이 조립한다.
allowFloor인 단어(kutsuonuide, oheya)만 OBJECT_RULES에서 "no floor"를 뺀다.

결과
- docs/design/word-art/source/candidates/word-{이름}_{시드}.png (원본, 옅은 회색 바탕)와 같은 이름의 .json
- docs/design/word-art/source/candidates/cut/word-{이름}_{시드}.png (remove_bg.py로 바탕을 지운 투명 PNG)
  진행률 도구가 candidates/의 word-{이름}_*.png 개수를 세므로 투명본은 하위 폴더에 둔다.
- 고른 한 장을 source/word-{이름}.png로 옮기는 일은 사람이 한다.

동작
- 한 번에 한 장씩 순서대로 ComfyUI 큐에 넣고 끝날 때까지 기다린다. 큐를 다른 작업과 같이 써도 된다
  (남의 작업을 취소하거나 큐를 비우지 않는다).
- 후보가 이미 --count 장 이상 있는 단어는 건너뛴다. 중간에 끊겨도 같은 명령으로 이어서 돌린다.
- 시간 제한(기본 1800초)에 걸리면 prompt_id를 출력하고 다음 단어로 간다. ComfyUI는 그 그림을 끝까지
  만들므로 나중에 /history/<prompt_id>에서 꺼낼 수 있다.
- copyFrom이 있는 단어(tonkatsu, kitsune, hinoki)는 생성하지 않고 그 그림을 source/word-{이름}.png로 복사한다.
  hinoki는 word-ofuro를 고른 뒤에야 복사할 수 있다.

이번 배치에서 뺀 것
- word-yu: 노렌 그림만 만든다. 가운데 빈 원에 ゆ를 KanjiVG 획으로 합성하는 일은 그림을 고른 뒤 따로 한다.
- word-okame: word_art.json에 hold로 남겨 두었다. 고명 구성 확인 뒤 hold를 지우면 생성된다.
"""

import argparse
import json
import random
import shutil
import sys
import time
from pathlib import Path

from PIL import Image

from gen_image import generate, workflow
from gen_item_art import OBJECT_RULES
from remove_bg import remove_bg

# 아이템 그림의 STYLE·PALETTE를 그대로 쓰면 1차 배치(26장)에서 17장이 탈락했다.
# 색 이름을 늘어놓은 PALETTE는 대상에 그 색을 전부 칠하게 만들었고(무지개색 꼬치·노렌, 색 공),
# "kawaii"는 오니기리에 얼굴을 그렸다. 단어 그림은 실물로 알아봐야 하므로 실제 색을 쓰게 한다.
STYLE = (
    "Flat sticker illustration of a real Japanese object, simple and clean: "
    "thick uniform dark chocolate brown outlines (#4A2219) around every shape, flat solid fills, "
    "rounded soft shapes, no gradients, no texture, no shading, no highlights, no drop shadow."
)
PALETTE = (
    "Color the object in its real natural colors, slightly softened and warm, using as few colors as possible. "
    "Never rainbow or multicolor: parts of the same kind share the same color. "
    "Clean plain surfaces."
)

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "tools" / "word_art.json"
SOURCE = ROOT / "docs" / "design" / "word-art" / "source"
OUT = SOURCE / "candidates"
CUT = OUT / "cut"

# gen_image.py 기본값과 같게 둔다
WIDTH = HEIGHT = 1024
STEPS = 8
SHIFT = 3.0


def load_words() -> list[dict]:
    return json.loads(DATA.read_text())["words"]


def file_name(word: dict) -> str:
    return f"word-{word['name']}"


def build_prompt(word: dict) -> str:
    rules = OBJECT_RULES.replace("no floor, ", "") if word.get("allowFloor") else OBJECT_RULES
    # "색 점·색 공·색 견본"을 금지어로 적으면 오히려 그려 넣는다(2차 배치에서 확인). 언급 자체를 뺀다.
    rules = rules.replace("no color swatches, ", "")
    return f"{STYLE} {PALETTE} Subject: {word['subject']} {rules}"


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path)


def copy_word(word: dict, head: str, dry_run: bool) -> None:
    name = head
    src = ROOT / word["copyFrom"]
    dst = SOURCE / f"{file_name(word)}.png"
    if dst.exists():
        print(f"{name}: 복사본 있음, 건너뜀", flush=True)
        return
    if not src.exists():
        print(f"{name}: 원본 {rel(src)} 없음, 건너뜀 (원본을 고른 뒤 다시 돌린다)", flush=True)
        return
    if dry_run:
        print(f"{name}: 복사 예정 {rel(src)} -> {rel(dst)}", flush=True)
        return
    SOURCE.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    if src.with_suffix(".json").exists():
        shutil.copy2(src.with_suffix(".json"), dst.with_suffix(".json"))
    print(f"{name}: 복사 {rel(src)} -> {rel(dst)}", flush=True)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--priority", type=int, default=1, help="우선순위 (1 또는 2). --only가 있으면 무시")
    p.add_argument("--only", nargs="+", metavar="word-이름", help="이 단어들만 (우선순위 무관)")
    p.add_argument("--count", type=int, default=1, help="단어당 후보 장수")
    p.add_argument("--seed", type=int, help="첫 시드 (없으면 무작위). 단어 안에서 +1씩")
    p.add_argument("--dry-run", action="store_true", help="생성하지 않고 프롬프트만 출력")
    p.add_argument("--host", default="127.0.0.1:8188")
    p.add_argument("--timeout", type=float, default=1800)
    a = p.parse_args()

    words = load_words()
    if a.only:
        by_name = {file_name(w): w for w in words}
        unknown = [x for x in a.only if x not in by_name]
        if unknown:
            print(f"모르는 단어: {unknown}. tools/word_art.json의 이름에 word-를 붙여 준다")
            return 2
        targets = [by_name[x] for x in a.only]
    else:
        targets = [w for w in words if w["priority"] == a.priority]
    if not targets:
        print("대상 단어가 없다")
        return 2

    seed = a.seed if a.seed is not None else random.randint(0, 2**31 - 1)
    gen = [w for w in targets if "copyFrom" not in w and "hold" not in w]
    print(f"대상 {len(targets)}개: 생성 {len(gen)}개 x {a.count}장, "
          f"복사 {sum('copyFrom' in w for w in targets)}개, 보류 {sum('hold' in w for w in targets)}개", flush=True)

    done = failed = 0
    for i, word in enumerate(targets, 1):
        name = file_name(word)
        head = f"[{i}/{len(targets)}] {name}"
        if "hold" in word:
            print(f"{head}: 보류 ({word['hold']})", flush=True)
            continue
        if "copyFrom" in word:
            copy_word(word, head, a.dry_run)
            continue
        prompt = build_prompt(word)
        if a.dry_run:
            print(f"{head}\n{prompt}\n", flush=True)
            continue

        have = len(list(OUT.glob(f"{name}_*.png")))
        if have >= a.count:
            print(f"{head}: 후보 {have}장 있음, 건너뜀", flush=True)
            continue
        OUT.mkdir(parents=True, exist_ok=True)
        CUT.mkdir(parents=True, exist_ok=True)
        for n in range(have, a.count):
            s = seed + n
            t0 = time.time()
            try:
                png = generate(a.host, workflow(prompt, s, WIDTH, HEIGHT, STEPS, SHIFT), a.timeout)
            except TimeoutError as e:
                print(f"{head} seed={s}: 시간 제한, 건너뜀. {e}", flush=True)
                failed += 1
                break
            except Exception as e:  # 연결 끊김, 노드 오류 등. 다음 단어로 간다
                print(f"{head} seed={s}: 실패, 건너뜀. {type(e).__name__}: {e}", flush=True)
                failed += 1
                break
            path = OUT / f"{name}_{s}.png"
            path.write_bytes(png)
            meta = {"word": name, "kana": word["kana"], "prompt": prompt, "seed": s, "width": WIDTH,
                    "height": HEIGHT, "steps": STEPS, "shift": SHIFT, "model": "z_image_turbo_bf16"}
            path.with_suffix(".json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n")
            cut, _, ratio = remove_bg(Image.open(path))
            cut.save(CUT / path.name)
            done += 1
            print(f"{head} {rel(path)} ({time.time() - t0:.0f}s, 바탕 지움 {ratio * 100:.0f}%)", flush=True)

    if not a.dry_run:
        print(f"끝: 새로 {done}장, 실패 {failed}개", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
