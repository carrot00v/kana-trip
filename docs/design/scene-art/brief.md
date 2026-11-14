# 장면 그림 작업 파일

앱 화면에서 장면 그림이 들어갈 자리, 각 그림의 규격과 이미지 생성 요청서, 후보를 고르는 기준을 모은 문서다. 리워드 아이템 16개(모자·두건·손·배경)는 보상 브랜치의 `item-art/brief.md` 몫이라 여기서 다루지 않는다.

- 개정일: 2026-11-14. 흐름 개편안 B(PLAN.md 4번)의 새 8장면 기준으로 고쳤다. 이미 생성한 후보 가운데 다시 쓸 것과 새로 만들 2장(스시집, 소바·우동집)을 정했다

| 파일 | 내용 |
|---|---|
| `brief.md` | 이 문서 |
| `source/` | 고른 그림 `thumb-{장면 id}.png`와 같은 이름의 `.json`(프롬프트, 시드). 아직 없다 |
| `source/candidates/` | 생성 후보. 커밋하지 않는다(.gitignore에 더한다) |
| `source/contact-sheet.png` | 2026-11-14까지 만든 후보 38장의 비교 시트 (옛 장면 이름 기준) |

근거 문서:

- `PLAN.md` 3번, 4번(장면 구성, 개편안 B), 8번
- 보상 브랜치의 `visual-rules.md` 1.2, 3번, 6.2, 7.1, 7.2, 8.3 (2026-11-13 개정판)과 `item-art/brief.md`(아이템 목록, 팔레트)
- [scene-flow.md](../scene-flow.md) 5번(H 홈 장면 행), 17번 결정 11(장면 id)
- 보상 브랜치의 `reward-flow.md` 4.3, 7번, 8.3

## 0. 그리기 전에

- **장면 구조는 정해졌다.** 히라가나 8장면: 스시집, 돈카츠집, 소바·우동집, 역, 신사·축제, 이자카야, 온천, 료칸(PLAN.md 4번). 장면 안의 단계(간판, 메뉴 등)마다 그림을 따로 두지 않는다. 그림은 홈의 장면 행에만 들어가고, 장면 하나에 하나다.
- **새로 만들 그림은 2장이다**: `thumb-sushi`, `thumb-soba`(5.2). 나머지 6장은 이미 만든 후보에서 고른다(5.1, 6번).
- **로컬 환경부터 확인한다.** `curl -s -m 2 http://127.0.0.1:8188/system_stats`가 응답하고 모델 파일 세 개가 있어야 한다(CLAUDE.md "그림 생성"). 하나라도 없으면 생성을 보류하고 다른 방법으로 대신 만들지 않는다.
- **화풍은 기리를 따른다.** 같은 폴더의 `art-direction.md`는 기리를 확정하기 전의 초안이고 이 문서는 따르지 않는다.

## 1. 그림이 들어갈 자리

### 1.1 넣는 자리

| 화면 | 자리 | 표시 크기 | 그림이 들어오면 | 장수 |
|---|---|---|---|---|
| H 홈 | 장면 행 왼쪽 | 52×52pt, 모서리 12pt | 잠긴 장면도 그림으로 보여 홈이 "앞으로 갈 여행 경로"로 읽힌다. 열린 장면만 아이콘이고 나머지가 모두 자물쇠이던 문제를 푼다. 행 높이 76pt는 scene-flow.md 5번이 이미 잡은 값이라 세로 비용이 없다 | 장면 8장 + 대체 그림 1장 |

### 1.2 넣지 않는 자리

| 화면 | 자리 | 넣지 않는 이유 |
|---|---|---|
| S 장면 진입 | 맨 위 배너, 단계 행 | 단계 섹션 두 개(단계 행 + 단어)가 이 화면의 내용이다. 단계 행(72pt)에 그림을 넣으면 같은 그림이 두 단계에 반복되거나 단계마다 그림이 필요해진다 |
| 단계별 그림 | 간판, 메뉴 등 | 같은 가게의 간판과 메뉴는 그림으로 구분이 약하고 장수만 16장으로 는다. 단계는 이름으로 구분한다 |
| C2 장면 완료 | 기리 뒤나 옆 | 화면마다 그림은 하나(visual-rules.md 7.2). 375×667pt에서 523/523pt로 여유가 없다 |
| C1 단계 완료, P2, P3 | | C1에는 기리가 있다. P2·P3은 안내 화면이라 그림을 두지 않는다 |
| L1 단어 카드 | 13pt 장면 아이콘 | 13pt에서 그림은 알아볼 수 없다. SF Symbol을 그대로 둔다 |
| L2, Q1, Q2, W | 학습 화면 | 캔버스와 글자 자리가 우선이다 |
| 잠긴 장면용 그림 | 홈 | 따로 그리지 않는다. 같은 그림을 채도 0으로 그린다(2.2) |
| 가타카나 장면 | 홈 | 홈에 아직 없다. 장면이 정해지면 같은 규격으로 더한다. 그 전까지는 대체 그림 |

## 2. 홈 장면 행에 놓는 방법

### 2.1 배치 (왼쪽에서 오른쪽)

| 요소 | 값 |
|---|---|
| 행 | `insetGrouped` 행, 바탕 `CardBackground`, 높이 76pt 이상(그림 52 + 위아래 12) |
| 그림 | 52×52pt, `RoundedRectangle(cornerRadius: 12)`로 자르고 `Outline` 2pt 외곽선(`strokeBorder`, 안쪽). 그림 안의 단색 바탕이 칸이다 |
| 상태 배지 | 지름 22pt 원(바탕 `CardBackground`), 안에 13pt 심벌. 원의 중심은 그림 오른쪽 아래 꼭짓점에서 왼쪽과 위로 7pt |
| 그림과 글자 사이 | 12pt |
| 글자, 오른쪽 숫자, `chevron.right` | scene-flow.md 5번 |

폭 확인(375pt): 행 내용 폭 311pt − 그림 52 − 12 = 247pt. 가장 긴 글자 줄 "ま み も · あ や は"(약 162pt)와 오른쪽 "2/3 ›"(약 50pt)가 들어간다.

### 2.2 상태

| 상태 | 그림 | 배지 | 오른쪽 | 색 밖의 구분 |
|---|---|---|---|---|
| 열림 | 원래 색 | 없음 | "0/3", "1/3" 또는 "2/3" + `chevron.right` | 배지 없음, 숫자 |
| 잠김 | 채도 0(`.saturation(0)`). 불투명도는 낮추지 않는다 | `lock.fill`, `InkSecondary` | 없음 | 자물쇠 모양, 오른쪽이 빔, 흑백 |
| 끝냄 | 원래 색 | `checkmark.circle.fill`, `Correct` | "완료" + `chevron.right` | 체크 모양, "완료" |
| 그림이 아직 없는 장면 | 대체 그림. 상태 규칙은 위와 같다 | 위와 같음 | 위와 같음 | 위와 같음 |

### 2.3 접근성과 그 밖

- VoiceOver: 그림과 배지는 읽지 않는다(`accessibilityHidden(true)`). 행 레이블은 scene-flow.md 5번.
- 큰 글자 크기(`accessibility1` 이상): 그림을 숨기고 SF Symbol 상태 아이콘(28pt)을 그린다.
- 그림 크기는 Dynamic Type을 따르지 않는다(52pt 고정).
- 다크 모드: 한 장으로 두 모드에 쓴다. 칸 경계는 `Outline` 2pt(다크 `#8C7366`)가 맡는다.
- 움직임 없음.
- 에셋이 없으면(`UIImage(named:)`가 nil) 대체 그림을, 대체 그림도 없으면 SF Symbol 상태 아이콘을 그린다. 그림이 하나씩 들어와도 코드를 고치지 않는다.

## 3. 공통 규격

| 항목 | 값 |
|---|---|
| 형식 | PNG, 불투명. 그림 전체를 칸 바탕색 하나로 채운다 |
| 생성 크기 | 1024×1024 |
| 앱 에셋 크기 | @2x 104px, @3x 156px (52pt) |
| 한 장에 | 물건 하나(접시와 그 위 음식처럼 한 덩어리로 보이는 묶음 포함). 가운데, 그림의 약 70%, 둘레에 고른 여백 |
| 기리 | 그리지 않는다 |
| 화풍 | 기리와 같다. 진갈색 `#4A2219`의 굵고 고른 외곽선, 단색 면, 둥근 모양. 그라데이션, 질감, 음영, 광택, 그림자 없음 |
| 외곽선 굵기 | 52pt에서 약 1.5pt(@3x 156px에서 4~5px). 1024px 원본에서 그림 폭의 약 3%(약 30px) |
| 외곽선 닫힘 | 물건 둘레의 외곽선이 닫혀 있어야 한다(7번에서 가장자리부터 바탕을 지우기 때문). 김 줄기처럼 바탕 위에 떠 있는 작은 선은 예외 |
| 시점 | 정면 또는 살짝 위. 원근을 세게 주지 않는다 |
| 글자 | 넣지 않는다. 간판, 행선지, 라벨, 현판은 빈 면 |

### 3.1 색

| 이름 | 값 | 쓰는 곳 |
|---|---|---|
| 외곽선 | `#4A2219` | 모든 외곽선 |
| 밥 흰색 | `#FFFDF7` | 흰 면, 밥, 접시 |
| 밥알 결 | `#EFE3CC` | 옅은 면 |
| 노랑 | `#F6B92B` | 전조등, 달걀 |
| 주황빨강 | `#E2533F` | 도리이, 참치. 빨강은 이것만 쓴다 |
| 분홍 | `#F5A7A0` | 작은 면 |
| INDIGO | `#2F4A7A` | 그릇, 접시 테두리, 전철 줄, 주전자, 소바 장국 잔 |
| SKY | `#CFE6F2` | 칸 바탕(하늘) |
| WOOD | `#C68A52` | 나무, 젓가락, 꼬치, 대발 |
| MOSS | `#8C9A6B` | 잎 |
| 김 | `#34402F` | 김(아주 어두운 올리브). 캐릭터 팔레트의 김과 같은 값 |
| 칸 바탕 SAND | `#F3E4C8` | 칸 바탕(모래) |

- **넓은 면에 쓰지 않는 색**(한 색이 그림의 10%를 넘으면 넓은 면): 초록 계열(색상 125°~160°, 채도 25% 이상)과 분홍빨강 계열(색상 330°~359°). 끝낸 장면의 초록 체크 배지가 그림 위에 놓이기 때문이다. 김(`#34402F`)은 색상 약 103°, 채도가 낮아 해당하지 않는다.
- 칸 바탕은 장면 순서대로 SKY와 SAND를 번갈아 쓴다(5번 표). 홈 목록에서 이웃한 행이 구분된다.
- 이미지 모델은 색 값을 정확히 지키지 못한다. 프롬프트에는 색 이름을 넣고, 칸 바탕은 넣는 단계에서 정확한 값으로 다시 칠한다(7번).

## 4. 공통 프롬프트 (Z-Image Turbo)

### 4.1 이 모델에 맞춘 점

- 참고 이미지를 받지 못한다. 기리 화풍을 글로 풀어 쓴다(STYLE).
- 투명 배경을 못 만든다. 칸 바탕색으로 바로 그리고, 바탕 정리는 7번에서 한다.
- "mascot", "kawaii", "cute character", "sticker"는 쓰지 않는다(얼굴, 바닥 그림자, 흰 칼선 테두리가 따라온다). "no face", "no ground shadow", "no white outline around the object"를 적는다.
- "app", "UI", "screen", "icon", "thumbnail"은 쓰지 않는다. 둥근 사각 틀을 부른다.
- 글자가 있을 법한 면은 "plain", "blank"로 짚는다.
- 네거티브 프롬프트를 쓰지 않으므로(`gen_image.py`가 빈 조건을 넣는다) 피할 것도 긍정 프롬프트 안에 쓴다.
- 접시를 그리면 접시 밑에 비스듬한 그림자가 생기기 쉽다(6.2의 이자카야 후보). 접시가 나오는 대상 문장에는 "nothing under the plate"와 "seen from the front and slightly above"를 넣는다.

### 4.2 조립

```
{STYLE} {PALETTE} Subject: {대상} {OBJECT} {BACKGROUND}
```

STYLE, PALETTE, OBJECT는 모든 그림에 한 글자도 바꾸지 않는다. BACKGROUND는 `{칸색}`만 바꾼다. 여러 장의 모양이 맞는 것은 이 고정에서 나온다.

**STYLE**

```
Flat cartoon illustration with bold clean outlines. Every shape is outlined with one thick, uniform, dark chocolate brown line (#4A2219), about three percent of the image width, with rounded line ends and rounded joins, and every outline is fully closed. Flat solid color fills only: no gradients, no texture, no shading, no highlights, no shine, no reflections, no drop shadow. Soft, rounded, chunky shapes, simple and friendly.
```

**PALETTE**

```
Colors: warm off-white, pale cream, dark indigo blue, pale sky blue, warm wood brown, warm yellow, soft orange red, soft pink, muted olive, and the dark chocolate brown of the outlines. No bright green, no emerald, no crimson, no magenta, no pure red, no neon colors.
```

**OBJECT**

```
Exactly one object, centered, filling about seventy percent of the square, with an even empty margin on all sides. Seen from the front or slightly above, with almost no perspective. A bold, simple silhouette that is still easy to recognize when shown very small. The object is not a character: it has no face, no eyes, no mouth, no blush. No people, no hands, no animals. No text, no letters, no numbers, no logos, no symbols on any surface; every label, sign and panel is completely plain.
```

**BACKGROUND** (`{칸색}` = `pale sky blue` 또는 `pale sand beige`)

```
The background is one flat solid {칸색} color filling the entire square edge to edge, and nothing else: no floor, no table, no horizon line, no ground shadow, no cast shadow, no border, no frame, no rounded-square frame, no white outline around the object, no vignette.
```

## 5. 그림 목록

장면 id는 scene-flow.md 17번 결정 11의 권장값이다. 데이터의 id가 다르게 정해지면 파일 이름만 그 id로 바꾼다.

| 순서 | 장면 id | 장면 | 파일 이름 | 대상 | 칸색 | 출처 | 할 일 |
|---|---|---|---|---|---|---|---|
| - | - | (대체 그림) | `thumb-placeholder` | 여행 가방 | SAND | 후보 `thumb-placeholder_301~304` | 고르기 |
| 1 | `sushi` | 스시집 | `thumb-sushi` | 접시 위 호소마키 세 개 | SKY | **새로 생성** (5.2) | 생성 4장 → 고르기 |
| 2 | `tonkatsu` | 돈카츠집 | `thumb-tonkatsu` | 가츠동 | SAND | 후보 `thumb-eatery_sign_301~306` | 고르기 → 칸색 바꿔 칠하기(7.1) |
| 3 | `soba` | 소바·우동집 | `thumb-soba` | 대발 위 자루소바와 장국 잔 | SKY | **새로 생성** (5.2) | 생성 4장 → 고르기 |
| 4 | `station` | 역 | `thumb-station` | 정면 통근 전철 | SAND | 후보 `thumb-station_301~304` | 고르기 |
| 5 | `shrine` | 신사·축제 | `thumb-shrine` | 도리이 | SKY | 후보 `thumb-shrine_301~304` | 고르기 → 칸색 바꿔 칠하기(7.1) |
| 6 | `izakaya` | 이자카야 | `thumb-izakaya` | 접시 위 야키토리 꼬치 | SAND | 후보 `thumb-izakaya_301~304` | 고르기. 그림자가 남으면 다시 생성(6.3) |
| 7 | `onsen` | 온천 | `thumb-onsen` | 김 오르는 나무 목욕통 | SKY | 후보 `thumb-onsen_301~304` | 고르기 |
| 8 | `ryokan` | 료칸 | `thumb-ryokan` | 찻주전자와 찻잔 | SAND | 후보 `thumb-ryokan_301~304` | 고르기 |

### 5.1 옛 이름과 새 장면의 대응

후보 파일은 개편 전 장면 이름으로 만들어졌다. 고른 후보는 새 파일 이름으로 복사한다(7번).

| 옛 후보 이름 | 옛 장면 | 새 장면 id | 새 파일 이름 | 생성 때 칸색 → 새 칸색 | 비고 |
|---|---|---|---|---|---|
| `thumb-eatery_sign` | 1 밥집 간판 | `tonkatsu` | `thumb-tonkatsu` | SKY → **SAND** | 가츠동(かつ丼)은 돈카츠집 간판 단계의 단어다 |
| `thumb-station` | 2 역 | `station` | `thumb-station` | SAND → SAND | |
| `thumb-street` | 3 거리 | 없음 | | | 거리 장면이 빠졌다. 쓰지 않는다 |
| `thumb-shrine` | 4 신사 | `shrine` | `thumb-shrine` | SAND → **SKY** | 신사·축제 장면의 첫 단계가 신사다 |
| `thumb-festival` | 5 축제 | 없음 | | | 쓰지 않는다. 신사·축제는 도리이 한 장으로 |
| `thumb-izakaya` | 6 이자카야 | `izakaya` | `thumb-izakaya` | SAND → SAND | |
| `thumb-onsen` | 7 온천 | `onsen` | `thumb-onsen` | SKY → SKY | |
| `thumb-ryokan` | 8 료칸 | `ryokan` | `thumb-ryokan` | SAND → SAND | |
| `thumb-placeholder` | 대체 그림 | (공통) | `thumb-placeholder` | SAND → SAND | |
| (없음) | | `sushi` | `thumb-sushi` | SKY | 새로 생성 |
| (없음) | | `soba` | `thumb-soba` | SKY | 새로 생성 |

### 5.2 새로 만들 그림 2장

대상을 고르는 기준(전과 같음): 그 장면의 단어에 나오는 물건이거나 장면을 가장 빨리 알아보게 하는 물건, 52pt에서 알아볼 것, 리워드 아이템과 겹치지 않을 것, 글자 없이도 뜻이 살 것. 이웃한 밥집 그림(가츠동 그릇)과 실루엣이 달라야 한다.

**`thumb-sushi`** (1 스시집, 칸색 `pale sky blue`)

- 대상: 둥근 접시(남색 테두리) 위에 세워 놓은 호소마키 세 개. 단면(김 고리, 흰 밥, 주황빨강 속)이 보이게.
- 고른 이유: 리워드 손 아이템 `sushi`(초밥 한 점, 니기리)와 배경 아이템 `noren`(노렌이 걸린 가게 앞)을 피했다. 마키 단면은 니기리와 실루엣이 다르면서 52pt에서도 "초밥"으로 바로 읽힌다. 남색 테두리 접시는 회전초밥 접시를 떠올리게 해 메뉴 단계(회전초밥)와 이어진다. 가츠동(깊은 그릇, 김 줄기)과도 실루엣이 다르다(낮고 넓은 접시, 둥근 단면 셋).
- 피한 것: 니기리(아이템과 겹침), 노렌(아이템과 겹침, 글자 자리), 회전 레일(물건이 둘이 되고 원근이 생김), 문어·오징어 그림(52pt에서 알아보기 어렵고 얼굴이 생기기 쉬움).
- 안 될 때의 대체 대상: 같은 접시 위의 이쿠라 군함말이 두 개(김 띠 위에 주황 알). 문장은 아래 대상 문장의 rolls 부분만 바꾼다.

```
A small round flat plate seen from the front and slightly above: a warm off-white plate with a thick dark indigo rim, and on it three round thin sushi rolls standing upright side by side so that their flat cut faces show. Each roll is a ring of very dark olive seaweed around white rice with a small soft orange red center. Nothing else on the plate and nothing under the plate.
```

**`thumb-soba`** (3 소바·우동집, 칸색 `pale sky blue`)

- 대상: 네모난 대발(자루) 위에 담은 소바 한 무더기, 위에 김 몇 가닥, 옆에 남색 장국 잔 하나.
- 고른 이유: 메뉴 단계의 단어 ざる(채반에 담은 찬 면)다. 가츠동의 둥근 그릇과 실루엣이 달라(평평한 네모 대발) 홈에서 이웃한 두 밥집 행이 구분된다. 김 오르는 그릇을 피해 온천(김 오르는 목욕통)과도 겹치지 않는다. 돈카츠집·소바·우동집의 새 리워드 아이템은 아직 정해지지 않았다(PLAN.md 8번). 아이템을 정할 때 자루소바를 피하도록 item-art 쪽에 알린다.
- 피한 것: 김 오르는 우동 그릇(가츠동 그릇과 실루엣이 같다), 노렌(아이템과 겹침), 면 끌어올리는 젓가락(손이 들어가기 쉽다).
- 안 될 때의 대체 대상: 흰 그릇에 담긴 키츠네 우동(넓적한 유부 한 장, 굵은 흰 면). 그릇은 남색이 아닌 off-white로 해 가츠동과 구분한다.

```
A Japanese zaru soba set seen from the front and slightly above: a flat square tray of woven bamboo slats in warm wood brown, with a neat rounded mound of thin muted grayish brown buckwheat noodles on it, a few thin short strips of very dark olive seaweed on top of the noodles, and beside the tray one small cylindrical dark indigo dipping cup filled with dark brown sauce. Nothing under the tray.
```

### 5.3 이미 만든 그림의 대상 문장 (기록)

후보를 다시 뽑아야 할 때(6.3) 그대로 쓴다. 칸색은 5번 표의 새 칸색을 쓴다.

`thumb-tonkatsu` (옛 `thumb-eatery_sign`, 칸색 `pale sand beige`)

```
A Japanese katsudon rice bowl seen from the front and slightly above: a round deep bowl in dark indigo blue, a layer of white rice, sliced golden brown breaded pork cutlet with soft yellow egg on top, a pair of plain light wooden chopsticks resting across the rim, and three soft wavy steam lines rising above the bowl.
```

`thumb-station` (칸색 `pale sand beige`)

```
The front of a Japanese commuter train seen straight on: a rounded boxy warm off-white body, a wide dark indigo windshield, a dark indigo stripe across the lower body, two round warm yellow headlights, a small plain blank destination panel above the windshield, and a small gray pantograph on the roof.
```

`thumb-shrine` (칸색 `pale sky blue`)

```
A single Japanese torii gate seen straight from the front: two round soft orange red pillars, a dark chocolate brown top beam that curves gently upward at both ends, a straight soft orange red tie beam below it, a small plain blank plaque between the two beams, and two small gray stone bases.
```

`thumb-izakaya` (칸색 `pale sand beige`). 다시 뽑을 때는 아래 v2를 쓴다. 처음 문장(접시를 대각선으로 놓음)에서 4장 모두 접시 밑 그림자가 생겼다(6.2).

```
Two Japanese yakitori skewers lying side by side on a small long rectangular warm off-white plate, seen from the front and slightly above with the plate held level and straight: each plain light wooden skewer holds four round pieces of grilled chicken in flat warm brown, with small pale cream leek pieces between them. Nothing under the plate.
```

`thumb-onsen` (칸색 `pale sky blue`)

```
A round Japanese wooden bath bucket seen from the front and slightly above: warm wood brown staves held by two dark indigo hoops, filled with milky off-white hot water, and three tall soft wavy steam lines rising from it.
```

`thumb-ryokan` (칸색 `pale sand beige`)

```
A Japanese teapot with a straight side handle, in dark indigo blue with a small round lid, next to one small cylindrical warm off-white teacup filled with light brown tea, with one soft wavy steam line rising from the cup.
```

`thumb-placeholder` (칸색 `pale sand beige`)

```
A small rounded hard-shell travel suitcase standing upright, seen from the front: a warm off-white body with two vertical dark indigo stripes, a short dark indigo handle on top, two small round wheels at the bottom, and a small plain warm yellow luggage tag with no writing hanging from the handle.
```

## 6. 생성과 고르기

### 6.1 명령

`tools/gen_image.py`로 만든다. 결과는 `--out` 폴더에 `{name}_{seed}.png`와 `.json`(프롬프트, 시드)으로 남는다. `--steps 8 --shift 3.0`(기본값)은 바꾸지 않는다. 기존 후보와 같은 시드 범위(301~304)로 뽑아 선 굵기와 밝기를 맞춘다. 한 번에 하나씩 돌리고, 오래 걸리면 백그라운드로 돌린다.

`thumb-sushi`:

```bash
.venv/bin/python tools/gen_image.py "Flat cartoon illustration with bold clean outlines. Every shape is outlined with one thick, uniform, dark chocolate brown line (#4A2219), about three percent of the image width, with rounded line ends and rounded joins, and every outline is fully closed. Flat solid color fills only: no gradients, no texture, no shading, no highlights, no shine, no reflections, no drop shadow. Soft, rounded, chunky shapes, simple and friendly. Colors: warm off-white, pale cream, dark indigo blue, pale sky blue, warm wood brown, warm yellow, soft orange red, soft pink, muted olive, and the dark chocolate brown of the outlines. No bright green, no emerald, no crimson, no magenta, no pure red, no neon colors. Subject: A small round flat plate seen from the front and slightly above: a warm off-white plate with a thick dark indigo rim, and on it three round thin sushi rolls standing upright side by side so that their flat cut faces show. Each roll is a ring of very dark olive seaweed around white rice with a small soft orange red center. Nothing else on the plate and nothing under the plate. Exactly one object, centered, filling about seventy percent of the square, with an even empty margin on all sides. Seen from the front or slightly above, with almost no perspective. A bold, simple silhouette that is still easy to recognize when shown very small. The object is not a character: it has no face, no eyes, no mouth, no blush. No people, no hands, no animals. No text, no letters, no numbers, no logos, no symbols on any surface; every label, sign and panel is completely plain. The background is one flat solid pale sky blue color filling the entire square edge to edge, and nothing else: no floor, no table, no horizon line, no ground shadow, no cast shadow, no border, no frame, no rounded-square frame, no white outline around the object, no vignette." --name thumb-sushi --out docs/design/scene-art/source/candidates --seed 301 --count 4
```

`thumb-soba`:

```bash
.venv/bin/python tools/gen_image.py "Flat cartoon illustration with bold clean outlines. Every shape is outlined with one thick, uniform, dark chocolate brown line (#4A2219), about three percent of the image width, with rounded line ends and rounded joins, and every outline is fully closed. Flat solid color fills only: no gradients, no texture, no shading, no highlights, no shine, no reflections, no drop shadow. Soft, rounded, chunky shapes, simple and friendly. Colors: warm off-white, pale cream, dark indigo blue, pale sky blue, warm wood brown, warm yellow, soft orange red, soft pink, muted olive, and the dark chocolate brown of the outlines. No bright green, no emerald, no crimson, no magenta, no pure red, no neon colors. Subject: A Japanese zaru soba set seen from the front and slightly above: a flat square tray of woven bamboo slats in warm wood brown, with a neat rounded mound of thin muted grayish brown buckwheat noodles on it, a few thin short strips of very dark olive seaweed on top of the noodles, and beside the tray one small cylindrical dark indigo dipping cup filled with dark brown sauce. Nothing under the tray. Exactly one object, centered, filling about seventy percent of the square, with an even empty margin on all sides. Seen from the front or slightly above, with almost no perspective. A bold, simple silhouette that is still easy to recognize when shown very small. The object is not a character: it has no face, no eyes, no mouth, no blush. No people, no hands, no animals. No text, no letters, no numbers, no logos, no symbols on any surface; every label, sign and panel is completely plain. The background is one flat solid pale sky blue color filling the entire square edge to edge, and nothing else: no floor, no table, no horizon line, no ground shadow, no cast shadow, no border, no frame, no rounded-square frame, no white outline around the object, no vignette." --name thumb-soba --out docs/design/scene-art/source/candidates --seed 301 --count 4
```

다른 그림을 다시 뽑을 때는 `Subject:` 뒤의 문장(5.2, 5.3), `{칸색}`, `--name thumb-{장면 id}`만 바꾼다.

### 6.2 이미 만든 후보에서 본 문제

`source/contact-sheet.png`와 일부 원본(이자카야 301·304, 온천 302, 가츠동 305)을 보고 적었다. 고를 때 원본을 확대해 다시 확인한다.

| 문제 | 해당 후보 | 왜 안 되나 |
|---|---|---|
| 둥근 사각 틀, 칸 테두리 | eatery_sign 301, onsen 301, festival 301·303·304 | 앱이 52pt 칸을 모서리 12pt로 자르고 `Outline` 2pt를 두르므로 틀이 이중으로 보인다. 7번의 바탕 지우기도 틀 안쪽에서 멈춘다 |
| 바닥 그림자 | eatery_sign 304, onsen 303·304, placeholder 301(옅음) | 물건 밑 타원이 바탕 지우기에서 남아 칸 색 위에 얼룩으로 보인다 |
| 접시 밑 비스듬한 그림자, 광택 점 | izakaya 301~304 전부 | 4장 모두 같은 문제라 문장 탓이다(대각선으로 놓인 접시). 고르기보다 5.3의 v2 문장으로 다시 뽑는 쪽을 우선 본다 |
| 바닥선, 선로 | station 301·302·303 | "no floor"를 어겼다. 52pt에서 선로가 물건 아래로 삐져나와 실루엣이 흐려진다 |
| 외곽선 없는 김 | onsen 302 등 | 김 줄기가 외곽선 없이 크림색 면으로만 그려졌다. 바탕 위에 떠 있는 작은 선이라 허용한다(3번 "외곽선 닫힘"의 예외) |

### 6.3 고르는 기준

아래를 위에서부터 본다. 하나라도 걸리면 그 후보는 버린다.

| 순서 | 확인 | 기준 |
|---|---|---|
| 1 | 틀 | 둥근 사각 틀, 칸 테두리, 물건 둘레의 흰 칼선이 없다 |
| 2 | 그림자·바닥 | 물건 밑 타원 그림자, 비스듬한 그림자, 바닥선, 선로, 탁자 면이 없다. 다만 바탕 색과 거의 같은 옅은 그림자는 7번을 거친 뒤 156px에서 보이지 않으면 통과 |
| 3 | 글자 | 확대해서 글자, 숫자, 글자처럼 보이는 낙서가 없다. 전철 행선지 칸, 도리이 현판, 가방 짐표를 특히 본다 |
| 4 | 얼굴 | 물건에 눈, 입, 볼이 없다 |
| 5 | 52pt | 156px로 줄여 무엇인지 알아보인다. 외곽선이 4px 이상으로 남는다 |
| 6 | 외곽선 닫힘 | 물건 둘레가 끊긴 곳이 없다 |
| 7 | 색 | 초록(125°~160°)이나 분홍빨강(330°~359°) 면이 10%를 넘지 않는다. 도리이와 마키 속이 진홍이 아니다 |
| 8 | 광택 | 흰 광택 점이 156px에서 보이지 않는다(작은 점은 줄이면 사라져 허용) |
| 9 | 세트 | 이미 고른 그림 옆에 놓았을 때 선 굵기, 밝기, 물건 크기가 같은 계열이다. 이웃한 행(1·2·3 밥집)끼리 실루엣이 다르다 |
| 10 | 흑백 | 채도 0으로 바꿨을 때(잠김) 물건과 바탕이 구분된다. 소바의 회갈색 면과 대발이 흑백에서 한 덩어리가 되지 않는지 특히 본다 |
| 11 | 일본 고증 | 도리이, 전철, 오케, 마키, 자루소바의 모양이 다른 나라 것과 섞이지 않았다 |

- 4장 중 3장 이상이 같은 이유로 걸리면 시드 탓이 아니라 문장 탓이다. STYLE·PALETTE·OBJECT·BACKGROUND는 그대로 두고 대상 문장만 고쳐 다시 뽑는다(이자카야 v2가 그 예).
- 기존 후보 가운데 위 기준에 걸리지 않는 것: eatery_sign 302·303·305·306(303은 김 줄기가 회색이라 세트를 본다), station 304, shrine 301~304, onsen 302, ryokan 301~304, placeholder 302~304. 이자카야는 v2로 다시 뽑은 뒤 고른다. 이 목록은 비교 시트로 1차로 거른 것이고, 원본 확대 확인은 고를 때 한다.

### 6.4 장수와 시간

기준 Mac(M4 Pro 24GB)에서 1024px 한 장에 3.5~5분.

| 그림 | 생성 | 예상 시간 |
|---|---|---|
| `thumb-sushi` | 4 | 15~20분 |
| `thumb-soba` | 4 | 15~20분 |
| `thumb-izakaya` v2 (필요하면) | 4 | 15~20분 |
| `thumb-tonkatsu`, `thumb-shrine` 칸색 다시 뽑기 (7.1에서 필요하면) | 각 1 (고른 시드) | 7~10분 |
| 합계 | 8~18 | 약 30분~1시간 10분 |

## 7. 넣는 방법

1. 고른 한 장을 `source/thumb-{장면 id}.png`로 복사하고 `.json`도 같은 이름으로 함께 둔다. 옛 이름 후보(`thumb-eatery_sign_305.png` 등)는 5.1 표의 새 이름으로 복사한다. 이 일은 사람이 한다.
2. 바탕을 정확한 칸 색으로 맞춘다: `tools/remove_bg.py`로 가장자리부터 바탕을 지운 뒤, 그 아래에 정확한 칸 색(SKY `#CFE6F2`, SAND `#F3E4C8`)을 깔아 다시 불투명하게 만든다.
3. 104px, 156px로 줄여 에셋 카탈로그의 Image Set `SceneThumb-{장면 id}`(대체 그림은 `SceneThumb-placeholder`)에 @2x, @3x로 넣는다. Render As는 Original Image.
4. 2, 3번을 하는 스크립트는 아직 없다. 그림이 들어오기 시작하면 developer에게 맡긴다. 리워드 쪽 `tools/place_item_art.py`를 참고할 수 있다.

### 7.1 칸색이 바뀐 두 장 (돈카츠집, 신사·축제)

`remove_bg.py`는 가장자리에서 이어진 바탕만 지운다. 외곽선에 갇힌 바탕(도리이의 두 들보 사이와 현판 양옆, 가츠동의 젓가락과 그릇 테두리 사이)은 생성 때의 칸색으로 남는다. 칸색이 같으면 보이지 않지만, 이 두 장은 칸색이 바뀌므로 다른 색 조각으로 보인다.

1. 먼저 2번대로 칠한 뒤 156px에서 갇힌 조각이 보이는지 본다.
2. 보이면 갇힌 조각을 같은 칸 색으로 칠한다. 생성 때의 칸 색에 가까운 색(허용 오차 안)을 그림 전체에서 찾아 바꾸는 방식이면 된다. 도리이(주황빨강, 진갈색, 회색)와 가츠동(남색, 흰 밥, 노랑, 갈색)에는 칸 색과 가까운 면이 없어 물건이 지워질 위험이 적다.
3. 그래도 어색하면 고른 후보의 시드(`--seed {시드} --count 1`)로 BACKGROUND의 `{칸색}`만 새 칸색으로 바꿔 다시 뽑는다. 시드가 같아도 그림이 조금 달라질 수 있으니 6.3으로 다시 본다.

## 8. 이 그림들을 쓰기로 하면 visual-rules.md에서 바꿀 곳

그림을 넣는 것은 visual-rules.md 머리말의 "그림은 캐릭터 레이어 SVG와 아이템 SVG만 쓴다"를 넓히는 결정이다(PLAN.md 9번 2026-11-14에서 홈 장면 그림을 넣기로 했다). 보상 브랜치가 들어온 뒤 visual-rules.md에서 아래를 고친다. 이 문서에서는 고치지 않았다.

| 절 | 바꿀 내용 |
|---|---|
| 머리말 | "그림은 캐릭터 레이어 SVG, 아이템 그림, 홈의 장면 그림(PNG)만 쓴다" |
| 1.2 | "장면 그림의 색은 그림 안에만 있고 reward-flow.md 8.3의 금지 색상 범위를 지킨다" 추가 |
| 1.5 | "장면 그림은 밝은 칸 바탕까지 그린 한 장으로 두 모드에 쓴다" 추가 |
| 2.4 표 | "장면 그림(52pt 고정). 큰 글자 크기에서는 숨기고 SF Symbol 상태 아이콘으로 바꾼다" 추가 |
| 3번 모서리 표 | "홈 장면 그림: 12pt, `Outline` 2pt" 행 추가 |
| 7.1 표 | 장면 아이콘 행: "홈 장면 행에서는 장면 그림이 대신한다. SF Symbol은 L1 단어 카드(13pt)와 큰 글자 크기의 홈에서만 쓴다. 밥집 3장면은 `fork.knife`" |
| 7.3 새 절 "장면 그림" | 이 문서 2번 절의 자리, 상태, 배지, 대체 순서, VoiceOver |
| 8.3 표 | 장면 행의 색 밖의 표시: "그림 위 배지 모양(없음, 자물쇠, 체크), 잠긴 그림의 흑백, 오른쪽 글자('0/3', 없음, '완료')" |
| 9번 표 | "홈 장면 그림 52pt: 알아보이는지, 흑백(잠김)에서 물건이 보이는지, 다크 모드에서 밝은 칸이 튀지 않는지, 초록 배지가 그림 색과 섞이지 않는지" 추가 |

## 9. 변경 기록

- 2026-11-14: 최초 작성(개편 전 8장면 기준). 후보 38장 생성.
- 2026-11-14: 흐름 개편안 B 반영. 장면 8개를 스시집, 돈카츠집, 소바·우동집, 역, 신사·축제, 이자카야, 온천, 료칸으로 바꾸고 칸색 순서를 다시 매겼다. 옛 후보 이름과 새 장면 id의 대응(5.1)을 적었다. 가츠동은 돈카츠집, 전철은 역, 도리이는 신사·축제로 쓰고, 자판기(거리)와 사탕 사과(축제)는 쓰지 않는다. 새로 만들 `thumb-sushi`(접시 위 호소마키)와 `thumb-soba`(자루소바)의 대상 문장과 명령을 더했다. 후보에서 본 문제(틀, 그림자, 선로)와 고르는 기준(6.2, 6.3), 칸색이 바뀐 두 장의 처리(7.1), 이자카야 v2 문장을 더했다.
- 2026-11-14: 고른 그림을 source/thumb-{장면 id}.png로 복사(PM). sushi←thumb-sushi_303, tonkatsu←thumb-eatery_sign_305, soba←thumb-soba_301, station←thumb-station_304, shrine←thumb-shrine_304, izakaya←thumb-izakaya-v2_304(옅은 그림자 남음), onsen←thumb-onsen_302, ryokan←thumb-ryokan_304, placeholder←thumb-placeholder_302. 7번 2~3단계(칸색 칠하기, 에셋 카탈로그)는 developer
