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
- 이번 배치에서 뺀 것: `word-yu`의 ゆ 합성(노렌 그림만 만든다. 고른 뒤 `tools/place_word_art.py`가 그림의 빈 크림색 원을 찾아 KanjiVG 획으로 합성한다. 좌표를 적지 않으므로 다시 그려도 그대로 된다), `word-okame`(고명 구성 확인 전이라 `word_art.json`에 `hold`).

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

비교 시트: `source/contact-sheet.png` (`tools/word_art_sheet.py --priority 1`. 투명본을 푸른 바둑판 위에 놓아 남은 바탕 테가 보인다).

판정 기준: 기리 화풍(굵은 진갈색 외곽선, 평평한 색), word-images.md의 Subject와 맞는지, 글자·얼굴·엉뚱한 사물이 없는지, 바탕 제거가 깨끗한지, 여행자가 현지에서 알아볼 모습인지. 애매하면 다시 그림.

### 5.1 우선순위 1 (2026-11-15, 후보 26장, 단어당 1장)

| 파일 | 후보(시드) | 판정 | 이유 |
|---|---|---|---|
| word-sushi | 20261115 | 통과 | 참치·달걀 초밥 두 점과 게타. 바탕 깨끗 |
| word-ika | 716365333 | 통과 | 칼집 낸 흰 오징어 한 점 |
| word-tako | 716365333 | 다시 그림 | 윗면이 하늘색·보라 얼룩이라 문어로 안 보인다. 빨판도 없음 |
| word-maguro | 716365333 | 다시 그림 | 연한 주황 살에 흰 지방 줄무늬라 연어로 읽힌다 |
| word-katsudon | 716365333 | 통과(보정) | 덮밥으로 잘 읽힌다. 밥 위의 색 점 5개(초록·주황·분홍·보라·하늘)는 엉뚱한 것이라 밥 색으로 덮었다(`source/word-katsudon.json`의 `selected.retouch`) |
| word-hirekatsu | 716365333 | 다시 그림 | 둥근 빵·만두처럼 보인다. 왼쪽 위 조각은 흰 바탕에 하늘색·연두 줄 |
| word-gohan | 716365333 | 통과 | 남색 공기에 밥. 바닥 그림자는 바탕 지우기에서 빠짐 |
| word-udon | 716365333 | 통과 | 굵은 흰 면과 국물. 면이 소용돌이 모양이지만 우동으로 읽힌다. 스티커 흰 테는 지워짐 |
| word-soba | 716365333 | 다시 그림 | 면 위에 노랑·보라·분홍·주황 공 모양 고명. Subject에 없는 것 |
| word-zaru | 716365333 | 다시 그림 | 채반 뒤에 남색·크림·하늘색 공 세 개. 면도 덩어리처럼 보인다 |
| word-eki | 716365333 | 다시 그림 | 역이 아니라 단층 집·가게로 보인다(시계가 작은 점). 스티커 흰 테 부스러기가 남음 |
| word-otsuri | 716365333 | 다시 그림 | 구멍 난 동전이 도넛처럼 보이고, 뒤에 Subject에 없는 보라 동전 |
| word-kippuuriba | 716365333 | 다시 그림 | 세로로 긴 작은 기계에 다리가 달려 휴대 게임기·작은 냉장고처럼 보인다. 발매기로 알아보기 어렵다 |
| word-omamori | 716365333 | 다시 그림 | 끈 묶은 자루(복주머니) 모양. 평평한 직사각 부적이 아니다. 스티커 테 부스러기 |
| word-omikuji | 716365333 | 다시 그림 | 종이 대신 색 공 여덟 개와 흰 띠. 제비로 안 보인다 |
| word-takoyaki | 716365333 | 다시 그림 | 공이 흰색·남색·하늘색·주황·노랑·보라로 제각각. 다코야키가 아니라 색 공 |
| word-ringoame | 716365333 | 통과 | 막대에 꽂은 빨간 사과. 잎(작은 초록)은 허용 범위 |
| word-yakitori | 716365333 | 다시 그림 | 꼬치 조각이 크림·노랑·분홍·주황·보라·하늘색 무지개 |
| word-tsukune | 716365333 | 다시 그림 | 길쭉한 경단 하나가 아니라 둥근 경단 세 개(당고처럼 보임)와 남색 점. 테 부스러기 |
| word-onigiri | 716365333 | 다시 그림 | 얼굴(눈, 입, 볼)이 있다. 김도 붙어 있음(Subject는 김 없음) |
| word-yu | 716365333 | 다시 그림 | 노렌 한쪽 폭이 하늘색, 아랫단이 주황·노랑·초록·분홍·보라 무지개. 원이 가운데가 아닌 왼쪽 폭에 있다. ゆ 합성 자체는 이 후보로 시험해 동작을 확인했다 |
| word-onsen | 716365333 | 통과 | 둥근 돌 테두리와 하늘색 물. 김·물결을 얹으면 온천으로 읽힌다 |
| word-yukata | 716365333 | 통과 | 옷걸이에 건 흰 유카타, 남색 깃, 주황 띠 |
| word-houjicha | 716365333 | 다시 그림 | 손잡이가 달린 찻잔(서양식 컵). 유노미가 아니다 |
| word-ofuro | 716365333 | 통과 | 나무 욕조와 바가지. ひのき도 이 그림을 쓴다 |
| word-futon | 716365333 | 다시 그림 | 다리 달린 침대 틀 위의 이불이라 서양식 침대로 보인다 |

통과 9장(katsudon 보정 1장 포함), 다시 그림 17장. 통과한 그림은 `source/word-{이름}.png`(투명 1024px)와 `.json`(프롬프트, 시드, `selected`)으로 두었다.

다시 그릴 17장의 Subject는 `tools/word_art.json`에 고쳐 두었다(색이 섞이는 문제는 부분마다 색을 적고 "no other colors", "no balls"를 붙였다. 모양이 틀린 것은 틀린 모양을 직접 금지했다). docs/content/word-images.md의 Subject 열은 아직 옛 문장이다.

- 다시 돌릴 때: `gen_word_art.py`는 후보가 `--count`장 있으면 건너뛰므로 `--only word-tako ... --count 2`처럼 장수를 올리거나 옛 후보를 옮긴 뒤 돌린다.
- 무지개색은 공통 PALETTE 문장(색 이름 10개)에서 오는 것으로 보인다(아이템 はちまき와 같은 현상, item-art/brief.md 3.1). onigiri의 얼굴은 STYLE의 "kawaii"가 원인일 수 있다. 공통 문장은 아이템 그림과 같이 쓰므로 고치지 않았다.
