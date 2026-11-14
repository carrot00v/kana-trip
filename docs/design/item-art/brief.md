# 리워드 아이템 그림 작업 파일

기리 꾸미기 아이템 그림을 이미지 생성 모델로 그리기 위한 작업 묶음이다. 지금 앱은 아이템 16개를 SF Symbol 임시 표시로 그리고 있고, 이 폴더의 결과물을 넣으면 코드 수정 없이 그림으로 바뀐다.

| 파일 | 내용 |
|---|---|
| `brief.md` | 이 문서. 공통 규격, 공통 프롬프트, 넣는 방법 |
| `items.json` | 아이템 16개의 id, 슬롯, 들어갈 자리(`targetBox`), 아이템별 프롬프트 |
| `reference/onigiri-default.png` | 기리 기본 모습(1080px). 화풍 참고 이미지로 함께 넘긴다 |
| `reference/slot-guide.png`, `.svg` | 기리 위에 슬롯별로 그려도 되는 범위를 점선으로 표시한 그림 |
| `source/` | 고른 그림 `{id}.png`와 같은 이름의 `.json`(프롬프트, 시드). 지금 kippu, noren, yu |
| `source/candidates/` | 생성 후보와 비교 시트. 커밋하지 않는다(.gitignore) |

근거 문서: 아이템 목록은 [reward-system.md](../../content/reward-system.md) 4.2, 그림 규격은 [reward-flow.md](../reward-flow.md) 8번, 색 규칙은 같은 문서 8.3.

## 0. 그리기 전에

- **이름 확인이 먼저다.** PLAN.md 8번에 "리워드 아이템 이름의 현지 표기 확인. のれん, ゆ, きっぷ 외의 히라가나 13개는 웹 대조 전. 그림을 만들기 전에 확인한다"가 남아 있다. 이름이 바뀌면 그림도 바뀔 수 있으니, 확인을 마친 아이템부터 그린다.
- 가타카나 아이템(reward-system.md 4.3)은 초안이라 이 목록에 없다. 확정되면 `items.json`에 같은 꼴로 더한다.

## 1. 공통 규격

| 항목 | 값 |
|---|---|
| 형식 | PNG, **투명 배경**(배경 아이템만 불투명) |
| 크기 | 1024×1024 이상 정사각형. 아이템이 가운데에 오고 둘레에 여백 10% 정도 |
| 한 장에 | 아이템 하나만. 기리, 사람, 손, 그림자 바닥, 글자는 넣지 않는다 |
| 화풍 | 기리와 같은 스티커풍: 진갈색 굵은 외곽선, 단색 면, 그라데이션·질감·광택 없음, 둥근 모서리 |
| 외곽선 | `#4A2219`. 기리가 360px일 때 6px 굵기와 같아 보여야 한다. 아이템 크기 대비로 정하지 말고 **최종 배치 크기 기준**이다(2번) |
| 시점 | 정면 또는 살짝 위에서. 원근을 세게 주지 않는다 |

### 1.1 색

쓸 수 있는 색 (reward-flow.md 8.3):

| 이름 | 값 | 쓰는 곳 예 |
|---|---|---|
| 외곽선 | `#4A2219` | 모든 외곽선 |
| 밥 흰색 | `#FFFDF7` | 흰 면 |
| 밥알 결 | `#EFE3CC` | 옅은 무늬 |
| 김 | `#34402F` | |
| 빨강 | `#E2533F` | 도리이, 부적 |
| 분홍 | `#F5A7A0` | |
| 노랑 | `#F6B92B` | |
| INDIGO | `#2F4A7A` | 노렌, てぬぐい 무늬, はちまき, たすき, まえかけ |
| SKY | `#CFE6F2` | 배경의 하늘 |
| WOOD | `#C68A52` | 우산대, 나무, 접시 |
| PURPLE | `#7C5BA6` | ふろしき |
| MOSS | `#8C9A6B` | 배경의 나무·풀 |
| BEAN | `#6B2E2A` | ようかん |

**넓은 면에 쓰면 안 되는 색** (아이템 면적의 10%를 넘는 한 색 영역):
- 초록 계열(색상 125°~160°, 채도 25% 이상). 앱의 "맞음" 초록 `#2E7D4A`와 헷갈린다.
- 분홍빨강 계열(색상 330°~359°). 앱의 "틀림" 빨강 `#B8233F`와 헷갈린다. 빨강은 주황빨강 `#E2533F`만 쓴다.

이미지 모델은 색을 정확히 지키지 못하므로, 생성 뒤 넣는 단계(4번)에서 금지 색이 넓게 있는지 다시 본다.

### 1.2 그림 속 가나

이미지 모델은 가나를 틀리게 그리기 쉽다. **그림 안에는 글자를 그리지 말고 자리만 비워 둔다.** のれん의 すし, えき의 역명판, ゆ의 노렌 글자는 넣는 단계에서 KanjiVG 획으로 합성한다(reward-flow.md 8.5). `items.json`의 `kanaInImage`가 있는 아이템이 해당한다.

## 2. 슬롯별 규격

아이템은 기리와 같은 360 좌표계(viewBox `-30 0 360 360`)에 겹쳐 그린다. 이미지 모델이 이 자리를 정확히 맞추기 어려우므로 **아이템만 따로 그리고, 자리 맞추기는 넣는 단계에서 한다.** `items.json`의 `targetBox`가 아이템이 들어갈 상자다. `reference/slot-guide.png`에서 슬롯별 상자를 볼 수 있다.

| 슬롯 | 아이템 | 들어갈 자리 (360 좌표계) | 그릴 때 지킬 것 |
|---|---|---|---|
| 모자 | おめん, はちまき, てぬぐい | x 60~245, y 0~158 | 기리 머리 위에 얹힐 모양. 아래쪽 가장자리가 머리 곡선에 맞게 완만해야 한다. 크기는 기본 요리사 모자 정도 |
| 두건 | たすき, まえかけ, ふろしき | x −30~280, y 196~300 (まえかけ만 x 90~210에서 y 322까지) | 기리 몸 앞을 **왼쪽 아래에서 오른쪽 위로** 비스듬히 지나는 띠. 기본 빨간 두건과 같은 방향. 매듭이나 무늬는 왼쪽에 둔다(오른쪽 아래는 완료 화면의 체크 배지 자리) |
| 손 | すし, きっぷ, かさ, おまもり, ようかん | 쥐는 점 (0,0) 기준 x −40~40, y −80~20 | 세로로 서 있는 모양. **아래쪽 가운데가 쥐는 점**이다. 돌리지 않고 두 자리(기본·웃는 표정)에 옮겨 놓기만 한다. 64pt 홈 화면에서는 14×18pt로 작아지므로 실루엣이 단순해야 한다 |
| 배경 | のれん, えき, まち, とりい, ゆ | 360×360 전체 | 불투명. 가운데(기리가 서는 x 20~280, y 40~350)는 **밝고 비어 있게**. 세부와 물건은 가장자리에. 글자 자리는 왼쪽 위나 오른쪽 위(x −30~60 또는 240~330, y 0~150) |

## 3. 공통 프롬프트

아이템마다 `items.json`의 `prompt` 앞에 아래 공통 문장을 붙이고, `reference/onigiri-default.png`를 화풍 참고 이미지로 함께 넘긴다.

**모자·두건·손 (투명 배경)**

```
Cute flat sticker illustration in the same style as the reference onigiri character: thick dark brown outlines (#4A2219), flat solid fills, rounded shapes, no gradients, no texture, no shading, no drop shadow. Single isolated object, centered, transparent background, generous empty margin. No character, no hands, no text, no letters, no logo.
Subject: {prompt}
```

**배경 (불투명)**

```
Cute flat sticker illustration background in the same style as the reference onigiri character: thick dark brown outlines (#4A2219), flat solid soft colors, no gradients, no texture, no people, no characters. Square 1:1 composition. Keep the central area light and nearly empty because a character will stand in front of it; put details near the edges. No text, no letters.
Subject: {prompt}
```

### 3.1 Z-Image용 프롬프트 차이

로컬 Z-Image Turbo(ComfyUI)로 뽑을 때는 `tools/gen_item_art.py`가 프롬프트를 조립한다. 위 공통 프롬프트와 다른 점:

- **참고 이미지를 못 넘긴다.** 그래서 "same style as the reference"를 빼고 기리 화풍(진갈색 굵은 외곽선, 단색 면, 그라데이션 없음)과 1.1의 색을 글로 풀어 쓴다.
- **바탕은 투명 대신 옅은 회색 단색.** 모델이 투명 PNG를 만들지 못하므로, `tools/remove_bg.swift`가 가장자리부터 바탕색을 지워 `{id}_{seed}-cut.png`를 만든다. 배경 아이템은 지우지 않는다.
- **얼굴과 바닥 그림자를 막는 문장을 넣는다.** "mascot" 같은 말을 쓰면 물건에 눈·입이 생기고 바닥 그림자가 따라 나왔다(2026-11-14 시험). no face/eyes/mouth, no ground shadow를 명시한다.
- 후보는 `source/candidates/{id}_{seed}.png`에 쌓이고, 같은 이름의 `.json`에 프롬프트와 시드가 남는다. 고른 한 장을 `source/{id}.png`로 복사하는 일은 사람이 한다.
- 이 Mac(M4 Pro 24GB)에서 1024px 한 장에 3.5~5분. 한 번에 하나만 돌린다.

## 4. 넣는 방법

1. 생성한 그림을 `source/{id}.png`로 저장한다(예: `source/sushi.png`). 마음에 드는 한 장만 남긴다.
2. 확인할 것: 투명 배경인지(배경 아이템 제외), 글자가 섞이지 않았는지, 금지 색이 넓게 없는지, 외곽선이 기리와 비슷한 굵기인지.
3. 배치 스크립트가 `targetBox`에 맞춰 크기를 줄이고 360 좌표계 캔버스에 놓아 아래 에셋을 만든다. **이 스크립트는 아직 없다.** 그림이 들어오기 시작하면 developer에게 맡긴다.

| 슬롯 | 만들 에셋 | 내용 |
|---|---|---|
| 모자, 두건, 배경 | `Item-{id}` | 360 좌표계 캔버스에 놓은 레이어 |
| 손 | `Item-{id}-default`, `Item-{id}-happy` | 쥐는 점을 (278,284)와 (290,164)에 놓은 레이어 두 장 |
| 모두 | `ItemThumb-{id}` | 슬롯별 썸네일 자르기(reward-flow.md 8.4) |

앱은 `UIImage(named:)`로 에셋이 있는지 보고 그림을 쓰므로 PNG 에셋이어도 동작한다. 지금의 기본 차림 2개(요리사 모자, 빨간 두건)만 SVG이고, 이 둘은 다시 그리지 않는다.

## 5. 아이템 목록

| 장면 | id | 슬롯 | 이름 | 그림 속 가나 |
|---|---|---|---|---|
| 1 밥집 간판 | `noren` | 배경 | のれん 노렌이 걸린 가게 앞 | すし |
| 1 밥집 간판 | `sushi` | 손 | すし 초밥 한 점 | |
| 2 역 | `eki` | 배경 | えき 역 승강장 | えき |
| 2 역 | `kippu` | 손 | きっぷ 기차표 | |
| 3 거리 | `machi` | 배경 | まち 시내 거리 | |
| 3 거리 | `kasa` | 손 | かさ 비닐우산 | |
| 4 신사 | `torii` | 배경 | とりい 도리이가 선 참배길 | |
| 4 신사 | `omamori` | 손 | おまもり 부적 | |
| 5 축제 | `omen` | 모자 | おめん 머리 옆에 건 축제 가면 | |
| 5 축제 | `tasuki` | 두건 | たすき 어깨띠 | |
| 6 이자카야 | `hachimaki` | 모자 | はちまき 머리띠 | |
| 6 이자카야 | `maekake` | 두건 | まえかけ 가게 앞치마 | |
| 7 온천 | `yu` | 배경 | ゆ 목욕탕 노렌 앞 | ゆ |
| 7 온천 | `tenugui` | 모자 | てぬぐい 머리에 얹은 수건 | |
| 8 료칸 | `furoshiki` | 두건 | ふろしき 보자기 | |
| 8 료칸 | `youkan` | 손 | ようかん 양갱 | |
