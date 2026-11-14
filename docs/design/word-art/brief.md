# 단어 그림 작업 파일

학습 단어 그림을 로컬 이미지 모델(ComfyUI, Z-Image Turbo)로 그리기 위한 작업 묶음이다. 어떤 단어를 무엇으로 그리는지는 [word-images.md](../../content/word-images.md)가 기준이고, 이 문서는 만드는 방법과 고른 결과만 적는다.

## 1. 화풍

리워드 아이템과 같다. [item-art/brief.md](../item-art/brief.md) 1번(화풍, 1.1 색, 1.2 그림 속 가나)과 3.1(Z-Image용 프롬프트)을 따른다. 슬롯 자리(targetBox, 쥐는 점)는 따르지 않는다.

- 프롬프트는 `tools/gen_item_art.py`의 `STYLE` + `PALETTE` + `Subject: ` + 단어별 Subject + `OBJECT_RULES`로 조립한다. 공통 문장을 고치면 아이템 그림에도 같이 적용된다.
- `word-kutsuonuide`, `word-oheya`만 `OBJECT_RULES`에서 "no floor"를 뺀다(바닥·다다미가 뜻의 일부).
- 움직일 부분(김, 가쓰오부시 등)은 정지 그림에 그리지 않는다(word-images.md 1번).

## 2. 파일

| 위치 | 내용 |
|---|---|
| `tools/word_art.json` | 단어 목록(이름, 가나, 우선순위, Subject, 복사 원본). word-images.md 2·3번을 옮긴 것. 표가 바뀌면 함께 고친다 |
| `source/candidates/word-{이름}_{시드}.png`, `.json` | 생성 후보(옅은 회색 바탕)와 프롬프트·시드. 커밋하지 않는다(.gitignore) |
| `source/candidates/cut/word-{이름}_{시드}.png` | 바탕을 지운 투명본(`tools/remove_bg.py`) |
| `source/word-{이름}.png`, `.json` | 고른 한 장(투명 PNG 1024×1024). 사람이 후보에서 골라 옮긴다 |

- 이름은 `word-{로마자}` (word-images.md 1번).
- 생성하지 않고 복사하는 단어: `word-tonkatsu`, `word-kitsune`(item-art/source에서), `word-hinoki`(`word-ofuro`를 고른 뒤 그 그림을 복사).
- 이번 배치에서 뺀 것: `word-yu`의 ゆ 합성(노렌 그림만 만들고, 고른 뒤 가운데 원에 KanjiVG 획으로 합성), `word-okame`(고명 구성 확인 전이라 `word_art.json`에 `hold`).

## 3. 생성

```bash
.venv/bin/python tools/gen_word_art.py --priority 1        # 생성 26장 + 복사 2
.venv/bin/python tools/gen_word_art.py --priority 2        # 생성 14장 + 복사 1(word-ofuro를 고른 뒤)
.venv/bin/python tools/gen_word_art.py --only word-sushi word-ika --count 3 --seed 100
.venv/bin/python tools/gen_word_art.py --priority 1 --dry-run   # 프롬프트만 출력
```

- 한 번에 한 장씩. 이 Mac에서 1024px 한 장에 3.5~5분, ComfyUI 큐를 다른 작업과 같이 쓰면 더 걸린다.
- 후보가 이미 `--count`장 있는 단어는 건너뛰므로, 끊기면 같은 명령을 다시 돌린다.
- 한 장에 1800초가 넘으면 그 단어를 건너뛰고 prompt_id를 출력한다. ComfyUI는 그 그림을 끝까지 만들므로 `/history/<prompt_id>`에서 꺼내 `word-{이름}_{시드}.png`로 저장하면 된다.

## 4. 진행률

```bash
python3 .claude/skills/image-progress/progress.py --dir docs/design/word-art/source/candidates \
  --expect word-sushi:1 word-ika:1 word-tako:1 word-maguro:1 word-katsudon:1 word-hirekatsu:1 \
  word-gohan:1 word-udon:1 word-soba:1 word-zaru:1 word-eki:1 word-otsuri:1 word-kippuuriba:1 \
  word-omamori:1 word-omikuji:1 word-takoyaki:1 word-ringoame:1 word-yakitori:1 word-tsukune:1 \
  word-onigiri:1 word-yu:1 word-onsen:1 word-yukata:1 word-houjicha:1 word-ofuro:1 word-futon:1
```

위는 우선순위 1(생성 26장, `--count 1`)이다. 우선순위 2는 `word-ikura word-ebi word-inari word-oroshi word-wakame word-tanuki word-noriba word-omatsuri word-yakisoba word-kawa word-shiitake word-uzura word-kutsuonuide word-oheya`.

## 5. 고른 그림

확인할 것: 투명 바탕, 글자·숫자 없음, 금지 색(초록, 분홍빨강)이 넓게 없음, 외곽선 굵기가 기리와 비슷함, 김 등 움직일 부분이 그려져 있지 않음.

| 파일 | 고른 후보(시드) | 날짜 | 메모 |
|---|---|---|---|
| | | | |
