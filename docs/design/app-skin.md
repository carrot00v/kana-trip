# 앱 스킨: "배경" 아이템을 앱 전체 스킨으로

- 작성일: 2026-11-17
- 상태: **구상안**. 사용자 결정 "배경 아이템은 전체 앱 스킨의 형태였으면 좋겠어"를 화면·데이터·그림 규칙으로 옮긴 안이다. 9.2의 결정이 나기 전까지는 [reward-flow.md](reward-flow.md)와 [visual-rules.md](visual-rules.md)의 지금 규칙(배경은 꾸미기 화면 미리보기에서만)이 기준이다
- 기준 문서: `PLAN.md` 3번("시각 스타일", "기리 꾸미기"), 7번(안드로이드), 8번, [visual-rules.md](visual-rules.md) 1·2.5·3·6·8번, [reward-flow.md](reward-flow.md) 3·6·7·8번, [giri-companion.md](giri-companion.md), `docs/design/item-art/brief.md`, `docs/design/item-art/items.json`, `docs/content/reward-system.md` 1.2·4.2·4.6·5번, `KanaTrip/Resources/rewards.json`, `KanaTrip/App/AppStyle.swift`, `KanaTrip/Rewards/RewardModel.swift`, `KanaTrip/Rewards/GiriView.swift`
- 함께 보는 문서: `docs/design/home-map.md`(다른 designer가 작성 중인 지도 홈). 이 문서는 지도 쪽이 받아 쓸 것(5.1의 지도 계약)만 정하고 지도 배치는 정하지 않는다
- 고치지 않은 문서: home-map.md, scene-flow.md, item-art/의 items.json·brief.md·head-fit.md, tools/. 바꿀 곳은 8.6과 9.1에 목록으로 적었다

화면 기호는 scene-flow.md 1번과 reward-flow.md를 따른다: H 홈, S 장면 진입, L1 글자 소개, L2 따라 쓰기, W 단어 읽기, QI 퀴즈 안내, QA·QD·QC 퀴즈(글자 → 발음, 단어 → 읽기, 기억으로 쓰기), C1 세션 완료, C2 장면 완료, K 기리 꾸미기. 정보 화면(홈 "더 보기" → 앱 정보)은 이 문서에서 **I**로 부른다.

## 0. 요약

| 정한 것 | 안 | 절 |
|---|---|---|
| 스킨이 바꾸는 것 | 화면 바탕색, 바탕 무늬, 강조색(주 버튼·진행 막대·고른 탭), 지도의 길 색과 장소 그림, K 미리보기의 기리 뒤 그림 | 1.1 |
| 바꾸지 않는 것 | 글자·획 색과 대비, 카드·캔버스 바탕, 외곽선, 맞음·틀림 색, 힌트 노랑, 글꼴·크기, 배치·간격, 햅틱, 소리, 기리 그림 | 1.2 |
| 토큰 | 스킨이 채우는 것 12개(색 7 × 라이트·다크, 수치 2, 그림 3). 고정 토큰 9개는 모든 스킨이 같이 쓴다 | 2 |
| 다크 모드 | 스킨마다 다크 값을 **반드시** 둔다. 그림은 한 벌, 다크에서는 덮개로 어둡게 | 2.3 |
| 강도 | 강(H·K·C2) / 중(S·C1·QI·I) / 약(학습·퀴즈 화면: 옅은 바탕색과 버튼 강조색만, 무늬·그림 없음) | 4.1 |
| 스킨 목록 | 기본(스킨 0) + のれん·えき·とりい·ゆ 4개 = 5개. ゆ는 のれん과 그림이 닮아 보강이 필요하다 | 3 |
| 데이터 | 저장 키 `background`를 그대로 쓰고 뜻만 "스킨"으로 바꾼다. 저장 형식 이행 없음 | 8.1, 8.2 |
| 플랫폼 | 스킨 정의는 `skins.json` 하나(HEX와 그림 파일 이름). iOS·Android가 같은 파일을 읽는다 | 7 |
| 도입 | 1단계 색 토큰만(그림 0장) → 2단계 무늬·썸네일(스크립트, 이미지 모델 0~1장) → 3단계 지도 그림과 지도 연동(이미지 모델 4장) | 8.4 |

## 1. 스킨의 정의

스킨은 앱이 입는 "여행지의 분위기"다. 기리의 차림(머리·속재료·밥)은 기리 몸에만 걸리고, 스킨은 기리가 서 있는 앱 화면 전체에 걸린다. 한 번에 하나만 쓴다. 고르지 않은 상태가 기본 스킨(스킨 0, 지금 앱 모습)이다.

### 1.1 스킨이 바꾸는 것

| 자리 | 바뀌는 것 | 토큰 (2번) | 비고 |
|---|---|---|---|
| 화면 바탕 | 바탕색 | `AppBackground`, `AppBackgroundQuiet` | 학습·퀴즈 화면은 옅은 쪽(`Quiet`) |
| 바탕 무늬 | 이어 붙는 무늬 타일 하나, 색, 진하기 | `pattern`, `PatternInk`, `patternOpacity` | 강·중 화면만(4.1). 무늬는 판단이 걸린 표시 밑에 깔리지 않는다 |
| 강조색 | 주 버튼 바탕, 보조 버튼(`.bordered`) 글자·옅은 바탕, 진행 막대, 할 차례 세션 번호 원, 홈 메뉴 아이콘, 장면 아이콘, K의 고른 탭·쓰는 중 외곽선·체크 배지·미리 보는 중 점선, 글자 버튼 | `AccentColor`, `AccentForeground` | 앱 루트의 `.tint`가 이 값을 따른다 |
| 홈(지도) | 길의 면·가장자리 색, 지도 위 장소 그림 | `PathFill`, `PathEdge`, `mapScenery`, `sceneryScrimDark` | 지도 쪽이 받아 쓴다(5.1) |
| K 미리보기 | 기리 뒤 그림 | `giriBackdrop` | 지금의 배경 아이템 그림(`Item-{id}`) 그대로. **기리 뒤에 그림을 까는 곳은 여전히 K 미리보기 한 곳이다**(reward-flow.md 7번의 작은 기리 규칙은 그대로) |
| 내비게이션 바 | 바 뒤에 비치는 바탕 | (바탕을 따름) | 바는 지금처럼 투명이라 화면 바탕과 무늬가 비친다. 제목 색(`Ink`)은 고정 |

탭 바는 앱에 없다. 뒤에 생기면 바탕은 `AppBackground`, 고른 탭 색은 `AccentColor`를 따른다.

### 1.2 바꾸지 않는 것

학습과 판정에 직결되거나, 바꾸면 접근성 계산을 스킨마다 다시 해야 하는 것은 모든 스킨에서 같다.

| 자리 | 고정하는 토큰·값 | 이유 |
|---|---|---|
| 글자, 제목, 판정 문구, 획 데이터 글자, 캔버스의 완성된 획·가이드 획·쓰는 중인 선 | `Ink`, `InkSecondary` | 획 모양과 대비가 학습 내용이다. 쓰기 판정 화면의 선 색이 스킨마다 다르면 "맞아서 진해졌다"의 감각이 흔들린다 |
| 카드·캔버스·선택지·말풍선·목록 행 바탕 | `CardBackground` | "종이"는 늘 같은 종이다. 캔버스 바탕이 같으면 가이드 획(`Ink` 0.22)의 보이는 정도도 같다 |
| 카드·선택지 외곽선 | `Outline` 2pt | |
| 맞음·틀림 | `Correct`, `Wrong`, 아이콘 모양, 문구, 햅틱 | 화면에서 초록·빨강의 뜻이 바뀌면 안 된다 |
| 힌트 | `Highlight`, `HighlightStrong`, `OnHighlight` | 시작점 번호 원, 고리 점선, 엔 아이콘 |
| L1의 "지금 글자" | 색을 `AccentColor` → **`Ink`로 바꿔 고정**(형광펜 바탕과 밑줄은 그대로) | 지금은 강조색 = 본문 색이라 모습이 같다. 강조색이 스킨을 따라가면 학습 글자의 색이 스킨마다 달라진다(9.1의 visual-rules.md 2.5) |
| 글꼴, 텍스트 스타일, 가나 크기, Dynamic Type | visual-rules.md 2번 | |
| 배치, 간격, 버튼 크기, 모서리 반지름 | visual-rules.md 3·4번 | 스킨은 색과 그림만 바꾼다. 화면 구조는 하나다 |
| 기리 그림, 아이템 그림 | SVG·PNG 그대로 | 다크용 그림을 따로 두지 않는 방침 그대로 |
| 시스템 확인 창(`confirmationDialog`)의 버튼 색 | 에셋 카탈로그의 `AccentColor`(기본 스킨 값) | 시스템이 띄우는 창은 앱 환경값을 다 따르지 않는다. 억지로 맞추지 않는다 |
| 앱 아이콘, 실행 화면 | 지금 그대로 | 스킨별 대체 아이콘은 범위 밖(9.2의 10) |

**범위 밖**: 효과음(앱은 발음 소리 말고 소리를 쓰지 않는다, visual-rules.md 6.1), 스킨별 움직임·Lottie, 스킨별 기리 대사 묶음, 스킨별 글꼴. 스킨이 바꾸는 움직임은 "스킨을 바꿀 때의 0.3초 교차 페이드" 하나다(5.3).

## 2. 토큰 구조

### 2.1 스킨이 채우는 토큰 (12개)

| 이름 | 종류 | 역할 | 기본 스킨 값 (라이트 / 다크) |
|---|---|---|---|
| `AppBackground` | 색 | 강·중 화면의 바탕 | `#FDF5E6` / `#1F1714` |
| `AppBackgroundQuiet` | 색 | 약 화면(학습·퀴즈)의 바탕. `AppBackground`를 카드 바탕 쪽으로 옅게 당긴 색 | `#FDF5E6` / `#1F1714` (기본은 같음) |
| `AccentColor` | 색 | 1.1의 강조 자리 | `#4A2219` / `#F7EEDF` |
| `AccentForeground` | 색 | 강조색 위 글자 | `#FFFDF7` / `#1F1714` |
| `PatternInk` | 색 | 무늬 선의 색. 무늬 타일은 모양(알파)만 있고 색은 이 값으로 칠한다 | 없음 (기본은 무늬 없음) |
| `PathFill` | 색 | 지도 길의 면 | `#FFFDF7` / `#2E2420` |
| `PathEdge` | 색 | 지도 길의 가장자리 | `#E6D6BC` / `#4A3A32` |
| `patternOpacity` | 수치 | 강 화면의 무늬 불투명도 (라이트 / 다크) | 0 / 0 |
| `sceneryScrimDark` | 수치 | 다크 모드에서 지도 그림 위에 덮는 `AppBackground`(다크)의 불투명도 | 0.45 |
| `pattern` | 그림 | 무늬 타일 파일 이름 | 없음 |
| `mapScenery` | 그림 | 지도에 놓는 세로 장소 그림 | 지도 쪽이 정한 기본 그림이 있으면 그것, 없으면 없음 |
| `giriBackdrop` | 그림 | K 미리보기의 기리 뒤 그림 | 없음 (지금처럼 `CardBackground`로 칠함) |

그 밖에 스킨마다 메타 값 `id`, `itemID`(이 스킨을 여는 리워드 아이템 id, 기본은 없음), `nameKo`, `thumbnail`(그리는 법만, 파일 없음, 5.2)을 둔다.

`PathFill`·`PathEdge`는 지도에 길이 있을 때 쓰는 값이다. home-map.md가 길을 고정 토큰으로 그리기로 하면 이 둘은 빼도 된다(5.1).

### 2.2 모든 스킨이 같이 쓰는 고정 토큰 (9개)

`CardBackground`, `Ink`, `InkSecondary`, `Outline`, `Highlight`, `HighlightStrong`, `OnHighlight`, `Correct`, `Wrong`. 값은 visual-rules.md 1.1 그대로다. Android가 같은 파일을 읽도록 `skins.json`의 `base`에도 함께 적는다(7.1). 대비 증가용 값(visual-rules.md 8.4)도 `base`에 적는다.

### 2.3 라이트·다크와의 관계

- **스킨마다 다크 값을 둔다. 다크 값이 없는 스킨은 넣지 않는다.** 시스템 설정이 다크면 스킨의 다크 값을 쓴다. "스킨 = 라이트 전용" 같은 예외는 없다.
- 다크의 바탕은 모두 아주 어둡고 채도가 낮다(상대 휘도 0.029 이하, 2.4). 스킨 사이의 차이는 다크에서 색조와 강조색, 무늬로 남는다. 다크 바탕을 밝게 하면 `Outline`(다크 `#8C7366`)의 3:1이 깨진다.
- 그림(`mapScenery`, `giriBackdrop`)은 한 벌이다. `mapScenery`는 다크에서 그 스킨의 다크 `AppBackground`를 `sceneryScrimDark`(0.45)만큼 덮어 어둡게 그린다. `giriBackdrop`은 K의 미리보기 카드 안에만 있어 지금처럼 그대로 둔다(사진을 넣은 카드와 같은 취급, reward-flow.md 8.4).
- 다크 전용 지도 그림은 1차에 만들지 않는다. 실기기에서 덮개를 씌운 그림이 탁해 보이면 그때 만든다(6.4).

### 2.4 접근성 기준

visual-rules.md 1.4의 기준(글자 4.5:1, 글자 아닌 표시 3:1)을 모든 스킨이 그대로 지킨다. 스킨 값에 대한 조건으로 풀면 아래와 같다. **무늬가 있는 화면은 바탕 대신 "무늬 선 위의 가장 나쁜 픽셀"(바탕과 `PatternInk`를 그 불투명도로 섞은 색)로 계산한다.**

| 조건 | 라이트 | 다크 | 근거 |
|---|---|---|---|
| 바탕(무늬 섞은 가장 나쁜 픽셀 포함)의 상대 휘도 | **0.72 이상** | **0.029 이하** | 라이트: `InkSecondary`가 4.5:1이 되는 하한(0.714). 다크: `Outline`이 3:1이 되는 상한 |
| `AppBackgroundQuiet`와 `CardBackground`의 대비 | 1.07 이상 | 1.16 이상 | 기본 스킨의 값보다 작아지면 안 된다. 외곽선이 없는 캔버스의 네 변이 기본 스킨보다 덜 보이면 안 되기 때문이다 |
| `AccentForeground` / `AccentColor` | 4.5 이상 (강조색 상대 휘도 0.12 이하) | 4.5 이상 (강조색 상대 휘도 0.35 이상) | 주 버튼 글자 |
| `AccentColor` / 바탕, `AccentColor` / `CardBackground` | 3 이상 | 3 이상 | 진행 막대, 번호 원, 쓰는 중 외곽선 |
| `AccentColor` / 보조 버튼 바탕(바탕에 강조색 15%) | 4.5 이상 | 4.5 이상 | 보조 버튼 글자 |
| `Ink`, `InkSecondary`, `Correct`, `Wrong`, `HighlightStrong`, `Outline` / 바탕 | 각각 visual-rules.md 1.4의 기준 | 같음 | 고정 토큰이 스킨 바탕 위에서도 통과해야 한다 |
| 강조색의 색상(hue) | 0°~17°(상대 휘도 0.05 초과일 때), 35°~65°, 125°~160°(채도 25% 이상), 330°~359° 금지 | 같음 | 빨강 = 틀림(visual-rules.md 1.2), 노랑·호박 = 힌트, 초록 = 맞음. 기본 스킨의 진갈색(약 11°, 휘도 0.027)은 갈색으로 읽혀 예외 조건 안에 든다 |
| 바탕·무늬의 넓은 면 색상 | 125°~160°(채도 25% 이상), 330°~359° 금지 | 같음 | item-art 금지 범위와 같다 |

**자동 검사**: `tools/check_skin_contrast.py`(새로 만듦, developer)가 `skins.json`을 읽어 스킨 × 모드마다 위 표를 계산하고, 하나라도 못 넘으면 실패로 끝난다.

- 무늬의 가장 나쁜 픽셀은 계산식으로 낸다: `바탕 × (1 − 불투명도) + PatternInk × 불투명도`(sRGB 값에서 섞음, SwiftUI·Compose의 기본 합성과 같다). 타일 그림을 렌더하지 않아도 된다.
- 출력은 표(스킨, 모드, 조합, 대비, 기준, 결과)로 낸다. 결과를 이 문서 3.6에 옮겨 둔다.
- 같은 검사를 Swift 단위 테스트(`SkinContrastTests`)로도 둔다. `xcodebuild test`에 묻어 가므로 `skins.json`을 고치고 검사를 잊는 일을 막는다. 파이썬 스크립트는 Android 쪽에서도 같은 결과를 내는 기준이다.

### 2.5 접근성 설정과의 관계

| 설정 | 스킨에서 일어나는 일 |
|---|---|
| 대비 증가 | 모든 화면에서 무늬를 끄고, 바탕은 강·중 화면에서도 `AppBackgroundQuiet`. 강조색은 그대로. 고정 토큰의 대비 증가 값(visual-rules.md 8.4)은 그대로 쓴다 |
| 동작 줄이기 | 스킨을 바꿀 때의 교차 페이드를 없애고 바로 바꾼다 |
| 다크 모드 | 2.3 |
| 굵은 텍스트, Dynamic Type | 스킨과 상관없다 |

## 3. 배경 아이템을 스킨으로 옮긴 안

히라가나 배경 아이템은 4개다(rewards.json `slot: "background"`). 아이템 하나 = 스킨 하나로 옮긴다. 아이템 id, 이름, 값, 배정 장면은 바꾸지 않는다(기획 결정이라 planner·PM 몫이다).

### 3.1 대응표

| 스킨 | 아이템 (장면) | 스킨 이름 후보 | 분위기 | 바탕 무늬 | 기리 뒤 그림 |
|---|---|---|---|---|---|
| 0 | 없음 (기본) | 기본 | 크림 종이, 진갈색 | 없음 | 없음 |
| 1 | `noren` のれん (1 스시집) | 노렌 · 쪽빛 | 회벽과 쪽빛 천 | 청해파(青海波, 겹친 반원 물결) | `Item-noren` 그대로 |
| 2 | `eki` えき (4 역) | 승강장 · 하늘 | 맑은 하늘과 승강장 | 점자 블록의 점 격자 | `Item-eki` 그대로 |
| 3 | `torii` とりい (5 신사·축제) | 참배길 · 주홍 | 살구빛 돌길과 주홍 기둥 | 삼잎(麻の葉) | `Item-torii` 그대로 |
| 4 | `yu` ゆ (7 온천) | 목욕탕 · 등나무빛 | 저녁 김과 등나무 보라 | 다테와쿠(立涌, 피어오르는 김) | `Item-yu` 그대로, 다시 그리기 권장(3.7) |

스킨 이름은 화면에서 쓰지 않을 수도 있다. K의 칸과 안내 줄은 지금처럼 아이템 이름(가나 + 한국어)을 쓰고, 스킨 이름은 VoiceOver 값과 정보 화면 같은 곳에서만 쓰는 안이 단순하다(9.2의 1).

### 3.2 팔레트: 라이트

| 토큰 | 0 기본 | 1 노렌 | 2 승강장 | 3 참배길 | 4 목욕탕 |
|---|---|---|---|---|---|
| `AppBackground` | `#FDF5E6` | `#E3E9F4` | `#DCEFF4` | `#F8E6DA` | `#ECE6F2` |
| `AppBackgroundQuiet` | `#FDF5E6` | `#EEF1F6` | `#EBF5F7` | `#FBF0E8` | `#F3F0F6` |
| `AccentColor` | `#4A2219` | `#2F4A7A` (쪽빛, 218°) | `#1D5E6E` (청록, 192°) | `#7A4422` (적갈, 23°) | `#5B4482` (등나무 보라, 262°) |
| `AccentForeground` | `#FFFDF7` | `#FFFDF7` | `#FFFDF7` | `#FFFDF7` | `#FFFDF7` |
| `PatternInk` | 없음 | `#2F4A7A` | `#1D5E6E` | `#C9663F` | `#5B4482` |
| `patternOpacity` | 0 | 0.06 | 0.06 | 0.06 | 0.06 |
| `PathFill` | `#FFFDF7` | `#F7F9FC` | `#F5ECDC` | `#ECEAE6` | `#F6EBDD` |
| `PathEdge` | `#E6D6BC` | `#B9C5DD` | `#C9B48E` | `#C9C3BA` | `#D9B48A` |

### 3.3 팔레트: 다크

| 토큰 | 0 기본 | 1 노렌 | 2 승강장 | 3 참배길 | 4 목욕탕 |
|---|---|---|---|---|---|
| `AppBackground` | `#1F1714` | `#151A24` | `#12201F` | `#24150F` | `#1C1626` |
| `AppBackgroundQuiet` | `#1F1714` | `#1A191C` | `#191C1A` | `#221612` | `#1E171D` |
| `AccentColor` | `#F7EEDF` | `#B4C3E6` | `#9ED3DE` | `#E9B59A` | `#CDBDE8` |
| `AccentForeground` | `#1F1714` | `#151A24` | `#12201F` | `#24150F` | `#1C1626` |
| `PatternInk` | 없음 | `#B4C3E6` | `#9ED3DE` | `#E9A58A` | `#CDBDE8` |
| `patternOpacity` | 0 | 0.05 | 0.05 | 0.05 | 0.05 |
| `PathFill` | `#2E2420` | `#232836` | `#22302E` | `#2D2725` | `#2C2420` |
| `PathEdge` | `#4A3A32` | `#3A4560` | `#3A5552` | `#4A403C` | `#4D3B2E` |

- 다크의 `AccentForeground`는 그 스킨의 다크 바탕과 같은 값이다(기본 스킨과 같은 규칙).
- 색 값은 기존 배경 그림의 색(노렌 쪽빛, 승강장 하늘, 도리이 주홍, 목욕탕 나무)과 item-art 덧붙임 팔레트(`INDIGO #2F4A7A` 등)에서 뽑아 2.4의 조건 안으로 옮겼다.

### 3.4 그림 재료

| 스킨 | 무늬 타일 | 지도 장소 그림 (`mapScenery`) | 기리 뒤 (`giriBackdrop`) |
|---|---|---|---|
| 0 기본 | 없음 | home-map.md의 기본 그림(있다면) | 없음 |
| 1 노렌 | `skin-pattern-seigaiha` | `skin-map-noren` (새로) | `Item-noren` |
| 2 승강장 | `skin-pattern-tenji` | `skin-map-eki` (새로) | `Item-eki` |
| 3 참배길 | `skin-pattern-asanoha` | `skin-map-torii` (새로) | `Item-torii` |
| 4 목욕탕 | `skin-pattern-tatewaku` | `skin-map-yu` (새로) | `Item-yu` (다시 그리기 권장) |

무늬 이름은 일본 전통 무늬 이름이다. 무늬마다 그 장소와의 연결: 청해파는 바다(스시), 점자 블록 점은 승강장 바닥, 삼잎은 신사·부적에 흔한 무늬, 다테와쿠는 피어오르는 김을 본뜬 무늬다.

### 3.5 손으로 계산한 대비 (자동 검사 전의 확인값)

sRGB 상대 휘도로 계산했다. "무늬"는 무늬 선 위의 가장 나쁜 픽셀이다. 자동 검사(2.4)를 돌리면 이 표를 그 결과로 바꾼다.

라이트:

| 조합 | 기준 | 0 기본 | 1 노렌 | 2 승강장 | 3 참배길 | 4 목욕탕 |
|---|---|---|---|---|---|---|
| 바탕 휘도 / 무늬 픽셀 휘도 | 0.72 이상 | 0.92 / – | 0.81 / 0.74 | 0.83 / 0.76 | 0.82 / 0.76 | 0.81 / 0.74 |
| `Ink` / 무늬 픽셀 | 4.5 | 12.6 | 10.2 | 10.6 | 10.6 | 10.2 |
| `InkSecondary` / 무늬 픽셀 | 4.5 | 5.7 | 4.6 | 4.8 | 4.8 | 4.6 |
| `InkSecondary` / `Quiet` | 4.5 | 5.7 | 5.5 | 5.6 | 5.5 | 5.5 |
| `AccentForeground` / `AccentColor` | 4.5 | 13.5 | 8.6 | 7.2 | 7.7 | 8.0 |
| `AccentColor` / 바탕 | 3 | 12.6 | 7.2 | 6.1 | 6.5 | 6.6 |
| `Correct` / 바탕 | 3 | 4.7 | 4.2 | 4.3 | 4.2 | 4.1 |
| `Wrong` / 바탕 | 3 | 5.8 | 5.1 | 5.3 | 5.2 | 5.1 |
| `HighlightStrong` / 바탕 | 3 | 4.1 | 3.6 | 3.8 | 3.7 | 3.6 |
| `CardBackground` / `Quiet` | 1.07 | 1.07 | 1.11 | 1.09 | 1.10 | 1.11 |

다크:

| 조합 | 기준 | 0 기본 | 1 노렌 | 2 승강장 | 3 참배길 | 4 목욕탕 |
|---|---|---|---|---|---|---|
| 바탕 휘도 / 무늬 픽셀 휘도 | 0.029 이하 | 0.010 / – | 0.010 / 0.016 | 0.013 / 0.020 | 0.009 / 0.015 | 0.010 / 0.015 |
| `InkSecondary` / 무늬 픽셀 | 4.5 | 7.6 | 6.9 | 6.5 | 7.0 | 7.0 |
| `Outline` / 무늬 픽셀 | 3 | 4.0 | 3.6 | 3.4 | 3.7 | 3.7 |
| `AccentForeground` / `AccentColor` | 4.5 | 15.3 | 9.9 | 10.2 | 10.8 | 10.1 |
| `Correct` / 바탕 | 3 | 8.7 | 8.6 | 8.2 | 8.7 | 8.7 |
| `Wrong` / 바탕 | 3 | 6.4 | 6.3 | 6.1 | 6.4 | 6.4 |

- 가장 빠듯한 곳은 라이트의 `InkSecondary` / 무늬 픽셀(4.6)과 다크의 `Outline` / 무늬 픽셀(3.4)이다. 무늬 불투명도를 올리고 싶으면 이 두 줄이 먼저 깨진다. `patternOpacity`의 상한을 라이트 0.06, 다크 0.05로 둔 이유다.
- `HighlightStrong`(라이트 `#A86A00`)은 기본 스킨에서도 4.1이고 스킨 바탕에서 3.6~3.8로 내려간다. 기준(3)은 넘는다. 엔 아이콘은 K와 홈에서 강 화면 위에 놓이므로 실기기에서 본다(9.3).

### 3.6 자동 검사 결과

(1단계 구현 때 `tools/check_skin_contrast.py`의 출력을 여기에 붙인다.)

### 3.7 스킨으로 부족해 보이는 것

1. **のれん과 ゆ가 닮았다.** 두 기리 뒤 그림이 모두 "남색 노렌 + 나무 틀 + 크림 벽"이다. 팔레트(쪽빛 / 등나무 보라)와 무늬(청해파 / 다테와쿠)로 나눴지만, K 미리보기에서 두 그림을 나란히 보면 같은 장소로 보인다. 권장: ゆ의 기리 뒤 그림을 **노천탕 바위와 김, 등나무 보라 노렌**으로 다시 그린다(6.3). 노렌 위 ゆ 합성 자리는 그대로 둔다.
2. **とりい의 강조색이 기본 스킨과 가깝다.** 도리이의 정체성은 주홍인데, 주홍은 두건 빨강과 같은 계열이라 UI 강조색으로 쓸 수 없다(visual-rules.md 1.2, 2.4의 색상 금지). 그래서 강조색은 적갈 `#7A4422`이고 기본 스킨의 진갈색과 같은 갈색 계열이다. 이 스킨은 살구 바탕과 주홍 삼잎 무늬, 지도 그림이 구분을 맡는다. 실기기에서 기본 스킨과 구분되지 않으면 강조색을 남색 계열로 바꾸는 대안이 있지만, 쪽빛(のれん)과 겹친다.
3. **えき의 청록이 "맞음" 초록과 같은 쪽으로 읽힐 수 있다.** 색상 차이는 약 50°(청록 192°, 맞음 141°)이고 어두워서 파랑 쪽으로 보인다. 판정은 늘 아이콘 모양과 문구가 함께 전하므로 규칙은 지킨다. S 장면 진입에서 "할 차례 번호 원(청록)"과 "완료 체크(초록)"가 한 화면에 있을 때 바로 구분되는지 실기기에서 본다.
4. **스킨 4개는 적다.** 장면 8개 가운데 4장면만 스킨을 준다. 가타카나 후보 コンビニ·カフェ·ホテル(reward-system.md 4.6)이 배경 종류로 남으면 스킨이 7개 + 기본이 된다. 히라가나 범위에서 더 늘리는 일은 기획 결정이라 제안만 한다(9.2의 8).
5. **값이 같다.** 스킨은 앱 전체를 바꾸는데 머리 토핑과 같은 300엔이다. reward-system.md가 "값은 하나"로 정한 이유(값 표가 생기지 않게)는 여전히 맞으므로 그대로 두는 것을 권장한다.

## 4. 적용 범위와 화면별 모습

### 4.1 강도 단계

| 단계 | 화면 | 바탕 | 무늬 | 강조색 | 그림 |
|---|---|---|---|---|---|
| **강** | H 홈(지도), K 꾸미기, C2 장면 완료 | `AppBackground` | `patternOpacity` × 1 | 스킨 | H: `mapScenery`, K: `giriBackdrop`(미리보기 카드 안) |
| **중** | S 장면 진입, C1 세션 완료, QI 퀴즈 안내, I 정보 | `AppBackground` | `patternOpacity` × 0.5 | 스킨 | 없음 |
| **약** | L1, L2, W, QA, QD, QC | `AppBackgroundQuiet` | 없음 | 스킨(주 버튼, 보조 버튼, 진행 막대만) | 없음 |

- 약 단계의 규칙: 글자, 캔버스, 선택지가 있는 화면에는 무늬와 그림을 깔지 않는다. 옅은 바탕색 하나와 버튼 색만 스킨을 따른다. 사용자는 "내 스킨" 안에 있다는 것을 버튼과 바탕의 색조로만 느낀다. 획을 긋는 동안 눈에 들어오는 것은 기본 스킨과 같다(캔버스 바탕, 선 색이 고정이므로).
- 화면 하나에는 단계 하나다. 같은 화면 안에서 영역마다 강도를 바꾸지 않는다. 예외는 강·중 화면의 "아래 고정 영역"(기리, 말풍선, 주 버튼)이다: 무늬를 빼고 `AppBackground` 단색을 깔고, 위 끝 16pt는 무늬에서 단색으로 이어지는 그라데이션으로 둔다. 말풍선과 버튼 글자 뒤에 무늬가 비치지 않게 하기 위해서다.
- 무늬는 화면에 붙어 있고 내용과 함께 스크롤되지 않는다(목록 화면). 지도는 예외로, 지도와 함께 스크롤할지는 home-map.md가 정한다(5.1).
- 구현: 화면 뿌리에서 `.skinBackground(.strong / .medium / .quiet)` 하나를 붙인다. 이 수정자가 바탕색·무늬를 깔고, 환경값 `skinLevel`을 아래로 내려 준다.

### 4.2 H 홈(지도)

지도 배치는 home-map.md가 정한다. 스킨이 넘겨주는 층만 그린다.

```
┌──────────────────────────────────────┐
│ 니혼go                          (…)  │ 내비게이션 바: 투명, 아래 층이 비침
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│ ░ = AppBackground + 무늬(강)
│░┌──────────────────────────────────┐░│
│░│   mapScenery (장소 그림)          │░│ 자리·크기는 지도 쪽이 정함
│░│   아래 25%는 바탕색으로 녹아듦     │░│ 다크: 바탕색 0.45 덮개
│░└──────────────────────────────────┘░│
│░░░░░░ ●━━━━━━━━━━━● ░░░░░░░░░░░░░░░░░│ 길: PathFill 면 + PathEdge 가장자리
│░░░░░░░░░░░░░░░░░░░ ┃ ░░░░░░░░░░░░░░░░│ 장면 노드: 고정 토큰(Outline, Ink,
│░░░░░░░░░░░░░░░░░░░ ● ░░░░░░░░░░░░░░░░│   Correct, 자물쇠 InkSecondary)
├──────────────────────────────────────┤ ← 위 16pt 그라데이션
│ (기리 96pt)  ┌ 말풍선 CardBackground ┐│ 아래 고정 영역: AppBackground 단색
│              └──────────────────────┘│
│ ┌──────────────────────────────────┐ │
│ │   주 버튼  (AccentColor)          │ │
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

- 꾸미기 행(목록 첫 행, reward-flow.md 4.1)이 지도 홈에 남으면 바탕은 `CardBackground`(고정)다.
- 장면 노드의 상태 표시(잠김, 할 차례, 완료)는 고정 토큰과 모양으로만 구분한다. "할 차례" 노드를 강조색으로 칠한다면, 강조색이 스킨마다 바뀌어도 모양(번호, 테두리 굵기)이 구분을 맡아야 한다.

### 4.3 S 장면 진입 (중)

```
┌──────────────────────────────────────┐
│ ‹ 니혼go       스시집                 │
│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│ ▒ = AppBackground + 무늬 0.5배
│▒┌──────────────────────────────────┐▒│ 목록 행: CardBackground (고정)
│▒│ 목표 단어 카드                    │▒│
│▒└──────────────────────────────────┘▒│
│▒ 세션                                 ▒│ 섹션 머리글: InkSecondary, 무늬 위
│▒┌──────────────────────────────────┐▒│
│▒│ (1) 배우기          할 차례     › │▒│ (1) 번호 원 = AccentColor
│▒│ (✓) …                            │▒│ (✓) = Correct (고정)
│▒└──────────────────────────────────┘▒│
├──────────────────────────────────────┤
│ 기리 + 말풍선, 주 버튼 (H와 같음)      │
└──────────────────────────────────────┘
```

### 4.4 L1 글자 소개, L2 따라 쓰기 (약)

```
┌──────────────────────────────────────┐
│ ✕   ━━━━━━━━━━━━──────────   2/6     │ 진행 막대: AccentColor (스킨)
│                                      │ 바탕 전체: AppBackgroundQuiet
│  す  su                       🔈     │ 글자 정보 줄: Ink / InkSecondary
│ (기리) ┌ 쓰기 포인트 말풍선 ┐          │ 말풍선: CardBackground (고정)
│        └──────────────────┘          │
│ ┌──────────────────────────────────┐ │
│ │                                  │ │ 캔버스: CardBackground (고정)
│ │   가이드 Ink 0.22, 완성 Ink,     │ │ 십자 점선, 번호 원, 고리 점선,
│ │   틀린 획 Wrong                  │ │ 틀린 획 모두 고정
│ │                                  │ │
│ └──────────────────────────────────┘ │
│ [다시 쓰기]  [        다음        ]  │ 보조·주 버튼: AccentColor (스킨)
└──────────────────────────────────────┘
```

- L1의 단어 카드에서 "지금 글자"는 `Ink`(1.2). 형광펜 바탕(`Highlight` 0.45)과 밑줄(`Ink`로 바꿈)이 구분을 맡는다.
- 캔버스 네 변은 `CardBackground`와 `AppBackgroundQuiet`의 차이로 보인다. 2.4의 조건 때문에 모든 스킨에서 기본 스킨보다 같거나 더 잘 보인다(1.07 → 1.09~1.11).

### 4.5 W 단어 읽기, QA·QD·QC 퀴즈 (약)

L1·L2와 같다. 선택지 칸은 `CardBackground` + `Outline` 2pt, 답한 뒤 `Correct`·`Wrong` 3pt로 고정이다. 스킨이 바꾸는 것은 바탕의 옅은 색조, 진행 막대, 주 버튼뿐이다. W의 단어 그림(확인 뒤)은 자기 바탕이 있는 그림이라 스킨과 상관없다.

### 4.6 QI 퀴즈 안내, C1 세션 완료 (중)

```
┌──────────────────────────────────────┐
│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│ AppBackground + 무늬 0.5배
│▒  (기리 120pt) ✓                    ▒│ 체크 배지: Correct, 바깥 고리는
│▒              ┌ 말풍선 ┐             ▒│   AppBackground 단색 3pt(무늬 없음)
│▒  배우기 완료                         ▒│
│▒  100엔을 받았어요 · 가진 엔 300엔     ▒│
├──────────────────────────────────────┤
│ [          다음 단계 시작          ]  │ 아래 고정 영역: 단색
│            여기까지 하기              │ 글자 버튼: AccentColor
└──────────────────────────────────────┘
```

### 4.7 C2 장면 완료 (강)

C1과 같은 구조에 무늬 × 1. 열린 아이템 썸네일 줄(reward-flow.md 6.2)에서 스킨 아이템은 5.2의 스킨 썸네일(44pt판)로 보인다. 스킨이 열려도 C2의 문구와 배치는 바꾸지 않는다(5.4).

### 4.8 K 기리 꾸미기 (강)

5번 절.

### 4.9 I 정보 화면 (중)

목록 화면이라 S와 같다: `AppBackground` + 무늬 0.5배, 행은 `CardBackground`. 크레딧 문구는 바뀌지 않는다. 스킨 그림이 이미지 모델로 만든 것이라는 표기는 지금 크레딧 방식(아이템 그림)과 같이 둔다.

## 5. 꾸미기 화면(K)에서의 표현

### 5.1 지도 쪽이 받아 쓸 것 (home-map.md와의 계약)

지도 화면은 아래 값만 스킨에서 읽는다. 다른 이름이 필요하면 이 표를 고친다.

| 받는 것 | 형식 | 쓰는 법 |
|---|---|---|
| `AppBackground` (라이트·다크) | 색 | 지도 바탕 |
| `pattern`, `PatternInk`, `patternOpacity` | 알파 타일 + 색 + 수치 | 지도 바탕 위. 지도와 함께 스크롤해도, 고정해도 된다(지도 쪽 결정) |
| `PathFill`, `PathEdge` | 색 | 장면을 잇는 길. 지도에 길이 없으면 쓰지 않는다 |
| `mapScenery` | 세로 그림 1장, 원본 1024×1536px(2:3), 불투명, 아래 25%가 그 스킨의 라이트 `AppBackground`로 녹아듦 | 지도의 한 자리(맨 위, 시작점 등)에 화면 폭으로 깐다. 화면 폭 375~440pt에서 높이 563~660pt. 위에 노드·길을 올려도 되게 가운데 세로 띠(폭의 40%)는 비워 그린다 |
| `sceneryScrimDark` | 수치 | 다크에서 그림 위에 `AppBackground`(다크)를 이 불투명도로 덮는다 |
| `AccentColor`, `AccentForeground` | 색 | 지도의 주 버튼, "할 차례" 표시를 강조색으로 한다면 |
| 고정 토큰 9개 | 색 | 노드의 상태(잠김·완료), 글자, 카드 |

지도가 스킨에서 **받지 않는** 것: 장면 노드의 모양과 크기, 노드 사이 간격, 길의 굵기, 스크롤 방식. 스킨마다 지도 구조가 달라지지 않는다.

### 5.2 탭과 칸

**탭 이름**: 네 번째 탭 "배경"의 이름을 바꾼다. 후보:

| 후보 | 판단 |
|---|---|
| **테마 (권장)** | 국내 앱(메신저 등)에서 "앱 전체 색이 바뀌는 것"을 부르는 익숙한 말. 2글자라 탭 폭(375pt에서 안쪽 약 56pt)에 엔 아이콘까지 들어간다 |
| 스킨 | 사용자가 쓴 말. 뜻은 같지만 게임·런처 쪽 말이라 조금 더 낯설 수 있다. 2글자 |
| 배경 | 지금 그대로. 기리 뒤 그림만 바뀐다고 오해하기 쉽다 |
| 분위기 | 3글자, 무엇이 바뀌는지 덜 분명하다 |

아래에서는 "테마"로 쓴다. 정해지면 문구만 바꾼다.

**칸 순서**: 기본 → のれん → えき → とりい → ゆ (장면 순서). 지금의 "없음" 칸은 **"기본" 칸**이 된다. 스킨은 비울 수 없고 늘 하나가 쓰이므로 "없음"이 뜻하는 것이 기본 스킨이기 때문이다. 저장값은 지금과 같다(키 없음 = 기본, 8.2).

**스킨 썸네일** (칸 60×60pt, C2 44×44pt). 파일 없이 화면에서 겹쳐 그린다:

```
┌────────────┐  60×60pt, 모서리 10pt
│            │  위 40pt: ItemThumb-{id} (기리 뒤 그림 썸네일),
│ (기리 뒤   │           scaledToFill, 위 정렬로 잘라 냄
│   그림)    │
├────────────┤
│▒▒ ▬▬▬▬ ▒▒▒│  아래 20pt: 그 스킨의 AppBackground + 무늬(강, 무늬 크기 0.5배)
└────────────┘           가운데에 AccentColor 캡슐 24×8pt
```

- 기본 칸: 위 40pt는 `CardBackground` 단색으로 비워 두고(기리 뒤 그림이 없는 지금 미리보기와 같다), 아래 띠는 기본 스킨의 색. 이름 줄 "기본".
- 다크 모드: 아래 띠는 다크 값으로 그려진다. 위 그림은 한 벌 그대로.
- 잠긴 칸: 지금 규칙(템플릿 렌더링, `InkSecondary` 0.3)을 썸네일 전체에 적용한다. 아래 띠도 같은 실루엣 색이 된다. 스킨 색을 미리 보여 주지 않는다(가나 이름을 숨기는 이유와 같다, reward-flow.md 3.5).
- C2 44pt판은 위 29pt, 아래 15pt, 캡슐 18×6pt.

### 5.3 미리보기: 고르면 화면 전체가 바뀐다

K는 강 단계 화면이고, **테마 탭에서 칸을 누르면 K 화면 전체가 그 스킨으로 바뀐다.** 미리보기 카드(기리 + 기리 뒤 그림)만 바뀌는 지금 방식에, K의 바탕·무늬·강조색(고른 탭, 체크 배지, 외곽선)이 함께 바뀌는 것을 더한다.

```
┌──────────────────────────────────────┐
│ ‹ 니혼go     기리 꾸미기  기본 차림으로│ 바 뒤로 스킨 바탕이 비침
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│ ▓ = 고른(미리 보는) 스킨의 바탕+무늬
│▓▓▓▓▓▓▓┌──────────────────────┐▓▓▓▓▓▓▓│
│▓▓▓▓▓▓▓│ giriBackdrop + 기리   │▓▓▓▓▓▓▓│ 미리보기 200~260pt (그대로)
│▓▓▓▓▓▓▓└──────────────────────┘▓▓▓▓▓▓▓│
│▓ のれん 노렌이 걸린 가게 앞    가진 엔 ▓│ 안내 줄
│▓ 미리 보는 중이에요 · 300엔  ¥ 300엔  ▓│
├ ─ ─ ─ ─ ─ ─ ─ 화면 절반 ─ ─ ─ ─ ─ ─ ┤
│ [머리] [속재료] [ 밥 ] [■테마¥]       │ 고른 탭: 미리 보는 스킨의 AccentColor
│ ┌──────┐ ┌──────┐ ┌┄┄┄┄┄┄┐            │
│ │기본  │ │✓ …   │ ┆のれん┆            │ ┄ = 미리 보는 중 점선 (AccentColor)
│ └──────┘ └──────┘ └┄┄┄┄┄┄┘            │
│ ┌──────┐ ┌──────┐                     │
│ │ 잠김 │ │ 잠김 │                     │
│ └──────┘ └──────┘                     │
└──────────────────────────────────────┘
```

동작 (reward-flow.md 3.7 표의 테마 탭 판):

| 누른 칸 | K 화면 | 저장 | 안내 줄 (1줄 / 2줄) |
|---|---|---|---|
| 쓰는 중 | 그대로 | 없음 | {이름} / 지금 쓰고 있어요 |
| 가짐 | 그 스킨으로 바뀜 (0.3초 교차 페이드) | `equipped.background` 갱신 → 앱 전체 적용 | {이름} / 앱 전체를 바꿨어요 |
| 기본 | 기본 스킨으로 바뀜 | `equipped.background` 키 삭제 | 기본 / 기본 테마로 돌아왔어요 |
| 살 수 있음 | **그 스킨으로 미리 바뀜** (임시) | 없음 | {이름} / 미리 보는 중이에요 · {값}엔. 확인 창이 뜬다 |
| 엔 부족 | 그 스킨으로 미리 바뀜 (임시) | 없음 | {이름} / {모자란 엔}엔이 더 있으면 살 수 있어요 |
| 잠김 | 그대로 | 없음 | {장면} 장면 아이템 / {장면} 장면을 끝내면 열려요 |
| 사기 성공 | 미리 본 모습 그대로 확정 | 사기 + 착용 | {이름} / 사서 앱 전체를 바꿨어요 |
| 사기 취소, 다른 탭으로, 화면을 나감 | 쓰던 스킨으로 되돌아감 (0.3초) | 없음 | 그 탭의 "처음" 문구 |

- 미리 보기는 **K 화면 안에서만**이다. 앱 전체 환경값은 저장된 스킨이고, K의 뿌리에만 `.environment(\.skin, previewSkin)`을 덮어씌운다. 뒤로 가면 저장된 스킨의 홈이 나온다.
- 처음 문구(테마 탭을 골랐을 때): 기본이면 "기본 / 기본 테마를 쓰고 있어요", 아니면 "{이름} / 앱 전체에 쓰고 있어요".
- 확인 창의 메시지 "산 아이템은 되돌릴 수 없어요"는 그대로 둔다. 스킨은 언제든 바꿀 수 있으니 "되돌릴 수 없는" 것은 엔이다.
- 미리보기 카드 아래에 "다른 화면은 이 색으로 바뀌어요" 같은 설명 줄을 더하지 않는다. K 화면 자체가 바뀌는 것으로 충분하고, 세로 계산(reward-flow.md 3.4)을 건드리지 않는다.
- 전환: 바탕·무늬·강조색이 0.3초 교차 페이드(`.easeInOut(duration: 0.3)`, visual-rules.md 6.2의 0.35초 이하). 미리보기 카드 안의 레이어 페이드(0.2초)와 함께 일어난다. "동작 줄이기"면 바로 바뀐다.
- VoiceOver: 미리보기 값의 "배경 {이름 또는 없음}"을 "테마 {이름 또는 기본}"으로. 칸을 눌러 스킨이 바뀌면 안내 줄 문구를 알림으로 읽는다(지금 규칙과 같다).

### 5.4 리워드를 받는 순간

스킨을 받는 순간은 둘이다. 둘 다 새 연출을 크게 더하지 않는다(visual-rules.md 6.2의 "산 뒤에 기리가 웃거나 커지는 연출은 없다"를 지킨다).

1. **C2에서 열림**: 열린 아이템 줄의 썸네일이 스킨 썸네일(5.2)이다. 문구와 배치는 그대로. 아직 사지 않았으므로 화면 색은 바뀌지 않는다.
2. **K에서 사기**: 미리 본 스킨이 그대로 확정된다. 미리 보는 동안 이미 화면이 바뀌어 있으므로 "산 순간"에 따로 바뀌는 것은 점선 → 쓰는 중 외곽선과 체크 배지, 가진 엔 숫자, `.success` 햅틱뿐이다(지금 사기와 같다).
3. **홈에 돌아온 첫 순간**(제안): 스킨을 바꾸고 처음 홈에 오면 기리 말풍선이 한 번 스킨을 알아본다. 예: "길도 쪽빛으로 바뀌었네요". 대사는 planner의 giri-lines.md 몫이라 여기서는 자리와 조건만 정한다: 조건 "저장된 스킨이 마지막으로 홈을 보였을 때와 다름", 한 번만, 그 자리의 기존 대사(오늘 갈 곳 권유) 대신.

### 5.5 "기본 차림으로" 버튼

지금은 네 슬롯을 모두 되돌린다(배경 = 비움). 스킨은 기리의 차림이 아니라 앱의 분위기라서, **"기본 차림으로"가 스킨은 건드리지 않는 것**을 권장한다(9.2의 2).

- 권장안: 버튼은 머리·속재료·밥만 되돌린다. 스킨을 기본으로 돌리려면 테마 탭의 "기본" 칸을 누른다. 버튼의 VoiceOver 힌트는 "머리를 요리사 모자로, 밥을 흰 밥으로 바꾸고 속재료를 비워요". `isDefaultOutfit`에서 배경 슬롯을 뺀다.
- 그대로 두는 안: 버튼 한 번에 앱 전체 색이 기본으로 돌아간다. 기리 모습을 정리하려던 사람이 산 스킨까지 풀리는 것이 놀라울 수 있다.

## 6. 그림 재료

### 6.1 스킨마다 필요한 그림

| 그림 | 수 | 원본 크기 | 앱 크기 | 만드는 법 | 단계 |
|---|---|---|---|---|---|
| 무늬 타일 | 4 | SVG(마스터) → PNG @2x·@3x | 4.3 표 | **스크립트**(`tools/make_skin_patterns.py`, 새로) | 2 |
| 기리 뒤 그림 | 4 (있음) | 1080×1080 PNG (지금 것) | K 미리보기 200~260pt | 지금 그림 그대로 | 이미 있음 |
| ゆ 기리 뒤 그림 다시 그리기 | 1 (권장) | 1024×1024 | 같음 | 이미지 모델 | 2 |
| 지도 장소 그림 | 4 | 1024×1536 생성 → 1320×1980으로 키워 저장 | 화면 폭 × 1.5 | 이미지 모델 + 바탕색 녹이기 스크립트 | 3 |
| 스킨 썸네일 | 0 | | 60pt, 44pt | 화면에서 겹쳐 그림(5.2) | 2 |
| 다크 전용 지도 그림 | 0 (필요하면 4) | 1024×1536 | | 이미지 모델 | 실기기 확인 뒤 |

### 6.2 무늬 타일 규격

기하 무늬는 이어 붙였을 때 이음매가 없어야 하고, 이미지 모델은 정확히 반복되는 타일을 만들지 못한다. 그래서 기리 몸·밥 그림(`tools/make_onigiri_svg.py`)처럼 **스크립트로 그린다**. 이 결정은 CLAUDE.md의 "그림 재료는 로컬 이미지 모델로"의 예외라 PM 확인이 필요하다(9.2의 4).

| 무늬 | 스킨 | 타일 (pt) | 선 굵기 (pt) | 모양 |
|---|---|---|---|---|
| 청해파 `seigaiha` | のれん | 40 × 20 | 1.5 | 반지름 20pt 동심 반원 4겹, 줄마다 반 칸 어긋남 |
| 점자 점 `tenji` | えき | 24 × 24 | 채움 | 지름 4pt 점 2개(0,0)·(12,12) 자리, 격자 |
| 삼잎 `asanoha` | とりい | 30 × 52 | 1.25 | 정육각형 별 무늬 한 주기. 높이 30√3 ≈ 51.96pt는 정수 px로 반올림해 0.1% 이하로 늘린다 |
| 다테와쿠 `tatewaku` | ゆ | 28 × 56 | 1.5 | 마주 보는 물결 세로선 2줄 한 주기 |

- 파일은 색 없는 알파 마스크(흰 선, 투명 바탕)다. 앱이 `PatternInk`로 칠하고 `patternOpacity`를 곱한다. 다크용 파일을 따로 두지 않는다.
- iOS: `Image("skin-pattern-{name}").renderingMode(.template).resizable(resizingMode: .tile)`. PNG @2x·@3x(예: 청해파 80×40, 120×60px).
- Android: 같은 PNG를 `drawable-xhdpi`·`drawable-xxhdpi`에. `ImageShader(…, TileMode.Repeated)`.
- 선이 아주 가늘어 보이는지, 이동 중 흔들릴 때 무늬가 "지글거리는지"(모아레)는 실기기에서 본다(9.3). 지글거리면 선을 굵게 하지 말고 불투명도를 낮춘다.

### 6.3 이미지 모델 프롬프트 초안

공통 문장은 item-art/brief.md 3.2의 배경 공통 문장을 세로 그림에 맞게 바꾼 것이다. 3.1의 Z-Image 주의(참고 이미지 없음, no animal/creature/mascot, 글자 금지)를 그대로 따른다. 생성은 `tools/gen_image.py`(`--width 1024 --height 1536`)로 한 번에 하나씩, 백그라운드로 돌린다.

**지도 장소 그림 공통 (세로, 불투명)**

```
Cute flat sticker illustration background in a simple sticker style: thick dark brown outlines (#4A2219), flat solid soft colors, rounded shapes, no gradients, no texture, no shading. No people, no characters, no animal, no creature, no mascots, no faces. Tall portrait 2:3 composition seen from slightly above. Keep a vertical band down the middle light and nearly empty; put buildings and objects near the left and right edges. The bottom quarter of the picture is one flat plain pale area with nothing in it. No text, no letters, no numbers, no signs with writing.
Subject: {subject}
```

| 그림 | `{subject}` |
|---|---|
| `skin-map-noren` | A quiet lane of small Japanese eatery fronts with wooden frames and light cream plaster walls, each doorway hung with a plain dark indigo split curtain, a few small potted plants. The curtains are plain with no letters. The flat pale area at the bottom is light blue-gray. |
| `skin-map-eki` | A small Japanese train platform under a pale blue sky with a few soft clouds, a simple canopy roof on thin posts at one side, a blank cream station name board, a yellow tactile strip along the platform edge, part of a cream and mauve train at the other side. Nobody on the platform. The flat pale area at the bottom is pale sky blue. |
| `skin-map-torii` | A gentle stone shrine approach rising into the distance through a row of vermilion torii gates, two stone lanterns, soft moss-grey shrubs at the edges, pale sky. The flat pale area at the bottom is pale peach. |
| `skin-map-yu` | An old hot spring town lane at dusk: wooden bathhouses with plain wisteria purple split curtains, soft white steam curls rising, wooden buckets by a door, a pale lavender sky. The curtains are plain with no letters. The flat pale area at the bottom is pale lavender. |

**ゆ 기리 뒤 그림 다시 그리기** (1024×1024, brief.md 3.2의 배경 공통 문장 그대로, 권장)

```
Subject: A simple outdoor hot spring bath: smooth grey rocks along the bottom edge, a low bamboo fence at the left and right edges, soft white steam curls, a small wooden hut at the top-left with a plain wisteria purple noren curtain. The center is a calm, very light, almost empty area. Leave the noren cloth plain with no letters.
```

`kanaBoxes`의 ゆ 자리(노렌 위, x 0~52, y 44~96)는 지금과 같게 노렌을 왼쪽 위에 둔다.

**넣는 단계** (developer, `tools/`):

1. 고른 지도 그림을 1320×1980으로 키우고(Lanczos), 아래 25%를 그 스킨의 라이트 `AppBackground`로 세로 그라데이션 섞기한다(`tools/fade_scenery.py`, 새로). 모델이 바탕색 HEX를 정확히 지키지 못하므로 색 맞추기는 스크립트가 한다.
2. 금지 색(초록 125°~160°, 분홍빨강 330°~359°)이 넓게 있는지 `place_item_art.py`와 같은 방식으로 비율을 출력한다. 도리이 주홍(`#E2533F` 근처)은 허용 범위다.
3. 가운데 세로 띠(폭 40%)의 평균 휘도가 바탕 조건(0.72 이상)을 넘는지 본다. 노드와 글자가 이 위에 올라갈 수 있기 때문이다.

### 6.4 장수와 시간

한 장 8~30분(1024×1536은 1024×1024보다 픽셀이 1.5배)으로 잡는다. 한 대상에 후보 4장을 뽑는다.

| 단계 | 그림 | 최종 장수 | 생성 횟수 | 시간 |
|---|---|---|---|---|
| 1 | 없음 | 0 | 0 | 0 |
| 2 | 무늬 타일 (스크립트) | 4 | 0 | 수 분 |
| 2 | ゆ 기리 뒤 그림 (권장) | 1 | 4 | 32분~2시간 |
| 3 | 지도 장소 그림 | 4 | 16 | 2시간 8분~8시간 |
| 실기기 뒤 | 다크 전용 지도 그림 (필요하면) | 4 | 16 | 2시간 8분~8시간 |
| 합계 (권장 범위) | | 9 (스크립트 4 + 모델 5) | 20 | 약 2.7~10시간 |

로컬 환경(ComfyUI `127.0.0.1:8188`, 모델 파일 3개)이 없으면 CLAUDE.md대로 그림 작업을 보류하고, 위 프롬프트를 `docs/schedule.md`의 보류 작업에 올린다. 1단계는 그림이 없어도 끝까지 갈 수 있다.

## 7. 안드로이드 대비

### 7.1 `skins.json`: 플랫폼 중립 정의

스킨의 정의는 코드나 에셋 카탈로그가 아니라 JSON 한 파일이다. iOS와 Android가 같은 파일을 읽는다. 지금 `rewards.json`과 같은 자리(`KanaTrip/Resources/skins.json`)에 두고, Android 빌드는 이 파일을 복사해 쓴다. 데이터 파일을 공용 폴더로 옮기는 일은 `rewards.json`과 함께 한 번에 정한다(9.2의 9).

```json
{
  "schemaVersion": 1,
  "_comment": "앱 스킨 (docs/design/app-skin.md). 색은 #RRGGBB, 라이트·다크 둘 다 필수. 그림은 확장자 없는 파일 이름.",
  "base": {
    "CardBackground": { "light": "#FFFDF7", "dark": "#2E2420" },
    "Ink":            { "light": "#4A2219", "dark": "#F7EEDF" },
    "InkSecondary":   { "light": "#7A5A4C", "dark": "#BCA697",
                        "highContrast": { "light": "#5C3D31", "dark": "#D9C7B8" } },
    "Outline":        { "light": "#4A2219", "dark": "#8C7366",
                        "highContrast": { "dark": "#BCA697" } },
    "Highlight":      { "light": "#F6B92B", "dark": "#F6B92B" },
    "HighlightStrong":{ "light": "#A86A00", "dark": "#F6B92B" },
    "OnHighlight":    { "light": "#4A2219", "dark": "#4A2219" },
    "Correct":        { "light": "#2E7D4A", "dark": "#6BC98A" },
    "Wrong":          { "light": "#B8233F", "dark": "#FF6B7A" }
  },
  "skins": [
    {
      "id": "default",
      "itemID": null,
      "nameKo": "기본",
      "colors": {
        "AppBackground":      { "light": "#FDF5E6", "dark": "#1F1714" },
        "AppBackgroundQuiet": { "light": "#FDF5E6", "dark": "#1F1714" },
        "AccentColor":        { "light": "#4A2219", "dark": "#F7EEDF" },
        "AccentForeground":   { "light": "#FFFDF7", "dark": "#1F1714" },
        "PatternInk":         null,
        "PathFill":           { "light": "#FFFDF7", "dark": "#2E2420" },
        "PathEdge":           { "light": "#E6D6BC", "dark": "#4A3A32" }
      },
      "patternOpacity": { "light": 0, "dark": 0 },
      "sceneryScrimDark": 0.45,
      "images": { "pattern": null, "mapScenery": null, "giriBackdrop": null }
    },
    {
      "id": "noren",
      "itemID": "noren",
      "nameKo": "노렌 · 쪽빛",
      "colors": {
        "AppBackground":      { "light": "#E3E9F4", "dark": "#151A24" },
        "AppBackgroundQuiet": { "light": "#EEF1F6", "dark": "#1A191C" },
        "AccentColor":        { "light": "#2F4A7A", "dark": "#B4C3E6" },
        "AccentForeground":   { "light": "#FFFDF7", "dark": "#151A24" },
        "PatternInk":         { "light": "#2F4A7A", "dark": "#B4C3E6" },
        "PathFill":           { "light": "#F7F9FC", "dark": "#232836" },
        "PathEdge":           { "light": "#B9C5DD", "dark": "#3A4560" }
      },
      "patternOpacity": { "light": 0.06, "dark": 0.05 },
      "sceneryScrimDark": 0.45,
      "images": {
        "pattern": "skin-pattern-seigaiha",
        "mapScenery": "skin-map-noren",
        "giriBackdrop": "Item-noren"
      }
    }
  ]
}
```

(えき·とりい·ゆ는 3.2·3.3 표의 값으로 같은 꼴을 채운다.)

- 스킨 id는 아이템 id와 같다(`noren` 등). 기본은 `default`. 저장 상태는 아이템 id만 갖고 있으므로(8.2) `itemID`로 스킨을 찾는다.
- 그림 이름은 확장자 없이 쓴다. iOS는 에셋 카탈로그 이름, Android는 `drawable` 리소스 이름(소문자와 밑줄만 허용이라 빌드가 `-`를 `_`로 바꾼다: `skin_pattern_seigaiha`).
- 고정 토큰(`base`)도 이 파일에 둔다. iOS는 지금처럼 에셋 카탈로그 Color Set도 유지하되(시스템 확인 창 등 환경값이 닿지 않는 곳의 대비용), 값이 이 파일과 같은지 단위 테스트가 비교한다.
- `schemaVersion`이 앱이 아는 것보다 크거나, 스킨 하나라도 필수 값이 빠졌으면 그 스킨을 버리고 기본 스킨으로 그린다(앱이 멈추지 않게).

### 7.2 그림 포맷과 해상도

| 그림 | 마스터 (저장소) | iOS | Android |
|---|---|---|---|
| 무늬 타일 | SVG (스크립트 출력) | PNG @2x·@3x, 템플릿 렌더링 | PNG xhdpi·xxhdpi (VectorDrawable은 타일 반복이 안 된다) |
| 지도 장소 그림 | PNG 1320×1980 | PNG @3x 한 장(시스템이 줄임) | WebP 무손실 xxhdpi 한 장 |
| 기리 뒤 그림 | PNG 1080×1080 (지금 것) | 지금 에셋 그대로 | WebP 무손실 |

- 마스터는 `docs/design/skins/`(새 폴더) 아래에 둔다: `patterns/*.svg`, `map/source/candidates/`(후보와 시드 json), `map/{id}.png`(고른 것). 앱 번들에는 넣는 단계의 출력만 들어간다.
- 그림 처리 스크립트는 CLAUDE.md대로 파이썬 + Pillow다. SVG를 PNG로 바꾸는 것도 스크립트가 직접 그리는 방식으로 하고(외부 렌더러 없이), 두 플랫폼 출력을 한 번에 만든다.

### 7.3 Material 3 색 역할 대응

Android는 Material 3 테마를 스킨마다 만들어 `MaterialTheme(colorScheme = …)`에 넣는다. 기기 배경화면 색을 따르는 동적 색(Material You)은 쓰지 않는다. 스킨이 색을 정하기 때문이다.

| KanaTrip 토큰 | Material 3 역할 | 비고 |
|---|---|---|
| `AppBackground` | `background`, `surface` | `surface`는 화면 바탕 쪽. 카드는 아래 `surfaceContainer*` |
| `AppBackgroundQuiet` | (확장 색) | 약 단계 화면은 `background`에 이 값을 넣은 하위 테마로 감싼다 |
| `CardBackground` | `surfaceContainerLowest` ~ `surfaceContainerHighest` 전부 | 카드, 시트, 대화 상자 |
| `Ink` | `onBackground`, `onSurface` | |
| `InkSecondary` | `onSurfaceVariant` | |
| `Outline` | `outline`, `outlineVariant` | |
| `AccentColor` | `primary` | 버튼, 진행 표시, 물결(ripple) |
| `AccentForeground` | `onPrimary` | |
| 바탕에 강조색 15% | `secondaryContainer` / `onSecondaryContainer` = `AccentColor` | 보조 버튼(iOS `.bordered`)에 맞춤 |
| `Wrong` | `error` | `onError`는 `CardBackground` |
| `Correct` | (확장 색) | M3에 "맞음" 역할이 없다 |
| `Highlight`, `HighlightStrong`, `OnHighlight` | `tertiaryContainer`, `tertiary`, `onTertiaryContainer` | 힌트 |
| `PatternInk`, `PathFill`, `PathEdge` | (확장 색) | `CompositionLocal`로 내려 준다 |

### 7.4 플랫폼마다 달라도 되는 것

| 달라도 되는 것 | 이유 |
|---|---|
| 상태 표시줄·내비게이션 바 모양, 뒤로 가기 동작 | 플랫폼 관습 |
| 시스템 대화 상자(iOS `confirmationDialog`, Android 하단 시트)의 버튼 색 | 시스템이 그린다. Android는 `primary`를 따르게 되어도 된다 |
| 버튼 눌림 표시(iOS 흐려짐, Android 물결) | 물결 색은 `primary`에서 나온다 |
| 글꼴(SF Pro Rounded / Roboto·Noto) | 가나 글꼴 규칙(고딕, 획 데이터 글자)은 같게 |
| 전환 곡선 | 시간(0.3초)과 "동작 줄이기면 없음"만 같게 |
| 무늬 타일의 픽셀 밀도 | 같은 pt 크기면 된다 |

같아야 하는 것: 토큰 값, 강도 단계 표(4.1), 고정 토큰, 대비 조건(2.4), 스킨 목록과 순서, 저장 키.

## 8. 데이터와 구현 영향

### 8.1 `rewards.json`의 `background` 슬롯

- 아이템 4개(`noren`, `eki`, `torii`, `yu`)의 id, 이름, 장면, 값은 그대로다. **슬롯 값 `"background"`도 그대로 둔다.** 뜻만 "기리 뒤 장소"에서 "앱 스킨"으로 바뀐다. 이름을 `"skin"`으로 바꾸면 저장 형식 이행(버전 3)과 Android 쪽 이름 맞추기가 생기는데 얻는 것이 없다.
- `_comment`와 `RewardSlot.background`의 주석만 고친다: "앱 스킨. 아이템 id로 skins.json의 스킨을 찾는다. 기본은 기본 스킨."
- 아이템과 스킨의 연결은 `skins.json`의 `itemID` 한 방향이다. `rewards.json`에 스킨 정보를 넣지 않는다(planner가 관리하는 파일에 색 값이 섞이지 않게).

### 8.2 저장 상태(`RewardState`) 이행

- **이행이 필요 없다.** `equipped["background"]`에 들어 있는 아이템 id가 그대로 "쓰는 스킨"이 된다. 키가 없으면 기본 스킨. `RewardState.currentVersion`은 2 그대로.
- 지금 배경을 쓰던 사용자는 업데이트 후 앱 전체가 그 스킨으로 바뀐다. 사용자가 아직 없으므로(PLAN.md 9번 2026-11-16) 안내 화면을 두지 않는다.
- 5.5의 권장안을 따르면 `RewardRules.resetOutfit`과 `RewardState.isDefaultOutfit`에서 배경 슬롯을 뺀다. 저장 형식은 그대로다.
- 읽는 쪽: `SkinStore`(새로)가 `RewardState`를 보고 지금 스킨을 낸다. 아이템 id에 맞는 스킨이 `skins.json`에 없으면 기본 스킨.

### 8.3 색을 쓰는 곳 (Grep으로 센 범위, 2026-11-17)

| 무엇 | 수 | 할 일 |
|---|---|---|
| `Color.{토큰}` 사용 전체 | 182곳, 23파일 | 고정 토큰(`ink`, `inkSecondary`, `cardBackground`, `outline`, `highlight*`, `correct`, `wrong`)은 **손대지 않는다**. 이것이 대부분이다 |
| `Color.appBackground`, `Color.accent`, `Color.accentForeground`, `.tint(` | 33곳, 14파일 | 스킨을 따라야 하는 곳. 아래 둘로 나뉜다 |
| ㄴ 화면 뿌리의 바탕 (`.background(Color.appBackground)`, `ZStack`의 `Color.appBackground`) | 약 13곳 (Home 2, SceneDetail 1, About 2, Session·Learn·Quiz·Word 4, SessionChrome 1, Completion 2, Customize 1) | `.skinBackground(.strong/.medium/.quiet)`로 바꾼다 |
| ㄴ 강조색 (`Color.accent`, `accentForeground`, `.tint`) | 약 20곳 | `SkinColor.accent` 등 환경값을 읽는 `ShapeStyle`로 바꾼다. 기계적인 이름 바꾸기다 |
| L1 "지금 글자"의 강조색 (`WordGlyphs.swift`) | 2곳 | `Color.ink`로 (1.2) |
| 체크 배지 바깥 고리 (`CompletionViews.swift`의 `Color.appBackground`) | 1곳 | 스킨 바탕 단색 |
| UIKit 쪽 `UIColor(named: "Ink")` | 3곳 | 고정 토큰이라 그대로 |
| 직접 쓴 색(`.white`, `.red`, `Color(red:)` 등) | 0곳 | 없음. 지난 개정에서 이미 토큰으로 바꿨다 |

구현 모양(개발 담당이 바꿔도 되는 제안):

- `Skin`(Decodable) + `SkinCatalog`(`skins.json` 읽기) + `SkinStore`(`@Observable`, 저장된 스킨) — 새 파일 1~2개.
- 환경값 `\.skin`, `\.skinLevel`. 앱 루트에서 `.environment(\.skin, store.current)`.
- `struct SkinColor: ShapeStyle { func resolve(in env: EnvironmentValues) -> Color }` — `env.skin`, `env.skinLevel`, `env.colorScheme`, `env.colorSchemeContrast`를 보고 색을 고른다. 뷰가 `@Environment`를 따로 읽지 않아도 된다(iOS 17+, 최소 iOS 18이라 쓸 수 있다).
- `.skinBackground(_ level:)` 수정자 하나가 바탕색, 무늬, 아래 고정 영역 처리, `skinLevel` 내려 주기를 맡는다.
- 내비게이션 바는 지금처럼 투명이라 손댈 것이 없다.

### 8.4 단계별 도입안

| 단계 | 들어가는 것 | 그림 | 끝난 상태의 기준 |
|---|---|---|---|
| **1. 색 토큰만** | `skins.json`(스킨 5개, 무늬·지도 그림 칸은 null), `SkinStore`·`SkinColor`·`.skinBackground`, 8.3의 33곳, 지금 글자 → `Ink`, K 테마 탭(이름, "기본" 칸, 화면 전체 미리 보기, 문구), 썸네일은 기리 뒤 그림 + 색 띠(무늬 없이), 대비 검사 스크립트와 단위 테스트 | 0장 | 기본 스킨에서 화면이 지금과 픽셀 단위로 같다(스크린샷 비교). 스킨 4개 × 라이트·다크로 H, S, L2, QA, C2, K의 시뮬레이터 스크린샷. 대비 검사 통과 |
| **2. 무늬와 기리 뒤 그림** | 무늬 타일 4개(스크립트), 강·중 화면의 무늬, 대비 증가에서 무늬 끄기, 썸네일 띠의 무늬, (권장) ゆ 기리 뒤 그림 다시 그리기 | 스크립트 4 + 모델 0~1 | 무늬가 있는 화면에서도 대비 검사 통과. 실기기에서 모아레·이음매 확인 |
| **3. 지도 연동** | 지도 장소 그림 4장, `fade_scenery.py`, home-map.md의 지도에 5.1 계약대로 연결, 홈 첫 방문 기리 대사(planner) | 모델 4 | 지도 홈이 스킨마다 바뀐다. 다크에서 덮개 확인 |

1단계만으로도 "스킨을 사면 앱 전체 색이 바뀐다"가 된다. 2·3단계는 그림 환경과 지도 홈 일정에 따라 늦어져도 된다.

### 8.5 작업량 추정

| 단계 | 코드 | 그림·도구 |
|---|---|---|
| 1 | 고칠 파일 약 15개(33곳 바꾸기 + K 테마 탭), 새 파일 2~3개(스킨 모델·저장소·스타일), 테스트 1개. 개발 1~2일 | 대비 검사 스크립트 1개 |
| 2 | 무늬 층과 대비 증가 처리, 썸네일. 0.5~1일 | 무늬 스크립트 1개, ゆ 그림 생성 0.5~2시간 |
| 3 | 지도 쪽 일정에 묶임 | 그림 생성 2~8시간, 녹이기 스크립트 1개 |

### 8.6 고치지 않은 파일에서 바꿀 곳 (담당에게 넘김)

| 파일 | 바꿀 곳 | 담당 |
|---|---|---|
| `docs/design/item-art/items.json` | 없음(그림·`kanaBoxes`는 그대로). ゆ를 다시 그리면 `yu`의 `prompt`를 6.3 문장으로 | developer (그림 넣을 때) |
| `docs/design/item-art/brief.md` | 2번 표의 배경 줄 "기리 뒤의 장소" → "앱 스킨의 기리 뒤 그림(K 미리보기 전용). 스킨 정의는 app-skin.md". 5번 표에 "스킨 색·무늬는 app-skin.md 3번" 한 줄. 지도 장소 그림은 item-art가 아니라 `docs/design/skins/`에서 다룬다고 적기 | designer (머리 아이템 작업이 끝난 뒤) |
| `docs/design/item-art/head-fit.md` | 없음 | |
| `tools/` | 새로: `check_skin_contrast.py`(2.4), `make_skin_patterns.py`(6.2), `fade_scenery.py`(6.3). 고침 없음: `gen_image.py`는 `--width 1024 --height 1536`로 그대로 쓴다 | developer |
| `KanaTrip/Resources/rewards.json` | `_comment`의 배경 설명만 | developer |
| `KanaTrip/Rewards/RewardModel.swift` | `RewardSlot.background` 주석. 5.5 권장안이면 `isDefaultOutfit` | developer |
| `KanaTrip/Rewards/RewardRules.swift` | 5.5 권장안이면 `resetOutfit`이 배경 키를 남김 | developer |
| `KanaTrip/App/Strings.swift` | 탭 이름, 테마 탭 문구 6개(5.3), VoiceOver 값 | developer |
| `KanaTrip/Rewards/CustomizeView.swift`, `GiriView.swift` | 테마 탭, 미리 보기 환경값 덮어쓰기, 스킨 썸네일 | developer |
| `docs/content/reward-system.md` | 1.2 표의 배경 줄("꾸미기 화면에서만 그린다" → 앱 스킨), 5번 304줄, 4.6의 가타카나 배경 후보를 스킨 후보로 | planner |
| `docs/content/giri-lines.md` | 5.4의 3 홈 첫 방문 대사 (스킨 4개 × 1줄) | planner |

## 9. 기존 문서와의 충돌, PM 결정 후보

### 9.1 충돌 목록

| 문서 · 자리 | 지금 | 이 안 |
|---|---|---|
| PLAN.md 3번 "시각 스타일" | "꾸미기 배경은 꾸미기 화면에만 그린다" | 기리 뒤 **그림**은 여전히 K에만. 스킨의 **색·무늬**는 모든 화면(강도별) |
| PLAN.md 3번 "기리 꾸미기" | 종류 "머리·속재료·밥·배경", "배경은 꾸미기 화면에서만 그린다" | 네 번째 종류가 "테마(앱 스킨)". 기본 차림으로 버튼의 범위(5.5) |
| visual-rules.md 1.1 | `AppBackground`, `AccentColor`, `AccentForeground`는 Color Set 하나의 라이트·다크 값 | 스킨마다 값이 다르고 `skins.json`에서 읽는다. 고정 토큰 9개는 그대로 |
| visual-rules.md 1.1 아래 설명 | "강조색을 따로 만들면 다섯 번째 색이 생긴다" | 스킨이 다섯 번째 색(강조색)을 일부러 들인다. 색상 금지 범위(2.4)로 판정·힌트 색과 떼어 놓는다. 기본 스킨은 지금 그대로 |
| visual-rules.md 1.3 | 시스템 색 대신 Color Set을 쓴다 | 스킨 토큰은 `SkinColor`(환경값)로. 시스템 색을 쓰지 않는 규칙은 그대로 |
| visual-rules.md 1.4 | 대비표 하나 | 스킨 × 모드마다. 자동 검사 결과를 이 문서 3.6에 |
| visual-rules.md 2.5 | 지금 글자 색 `AccentColor` | `Ink` (형광펜·밑줄 그대로, 밑줄도 `Ink`) |
| visual-rules.md 4.1 슬롯 탭 | "머리·속재료·밥·배경" | "머리·속재료·밥·테마" |
| visual-rules.md 6.1, 6.2 | "배경을 비웠어요", 스킨 전환 없음 | 5.3 문구, 스킨 교차 페이드 0.3초 |
| visual-rules.md 8.4 대비 증가 | 토큰 두 개의 진한 값 | + 무늬 끄기, 바탕 `Quiet` (2.5) |
| reward-flow.md 0, 3.0, 3.2, 3.5 | 배경 탭, "없음" 칸 | 테마 탭, "기본" 칸, 스킨 썸네일 |
| reward-flow.md 3.7, 3.8, 9.1, 10 | 배경 문구("배경으로 쓰고 있어요" 등), VoiceOver "배경 {이름}" | 5.3의 문구, "테마 {이름}" |
| reward-flow.md 3.7 "기본 차림으로" | 배경 = 비움 | 5.5 (권장: 스킨은 건드리지 않음) |
| reward-flow.md 7번 표 "배경" 열 | 작은 기리 자리에서 "안 그림" | 그대로(그림은 안 그림). 화면의 스킨 색은 별개 |
| reward-system.md 1.2, 5번 | "배경 = 기리 뒤의 장소, 꾸미기 화면에서만" | 앱 스킨 (8.6, planner) |
| giri-companion.md 9번 | 배경 아이템은 K에서만(PM 확인 중) | 그림은 K에서만으로 확정할 수 있다. 색은 이 문서 |
| art-direction.md(미커밋 초안) 0의 2 | 학습 화면에는 그림을 넣지 않는다 | 같다. 약 단계는 그림·무늬 없음 |
| CLAUDE.md "그림 생성" | 그림 재료는 로컬 이미지 모델로 | 무늬 타일은 스크립트로(6.2). 예외 확인 필요 |

reward-flow.md와 visual-rules.md에는 이 문서를 가리키는 줄만 넣었다. 위 표의 본문 수정은 9.2의 결정이 난 뒤 한다.

### 9.2 PM이 PLAN.md에 올릴 결정·미정 후보

| # | 정할 것 | 권장 | 다른 안 |
|---|---|---|---|
| 1 | 네 번째 탭 이름 | **테마** | 스킨(사용자 표현), 배경(그대로) |
| 2 | "기본 차림으로"가 스킨도 되돌리는지 | **되돌리지 않음**. 스킨은 테마 탭의 "기본" 칸으로 | 지금처럼 네 슬롯 모두 |
| 3 | 학습·퀴즈 화면의 스킨 강도 | **약**: 옅은 바탕색 + 버튼·진행 막대 강조색. 무늬·그림 없음 | 학습 화면은 기본 스킨 고정(스킨이 덜 느껴짐) / 중(무늬 0.5배, 집중 방해 우려) |
| 4 | 무늬 타일을 이미지 모델 대신 스크립트로 만드는 것 | **스크립트**. 이음매 없는 반복이 필요하고 밥 그림이 같은 선례다 | 이미지 모델로 생성 후 이음매 손질(결과가 들쭉날쭉) |
| 5 | とりい 스킨의 주홍: 무늬에 탁한 주홍 `#C9663F`, 강조색은 적갈 `#7A4422` | **그대로**. UI 강조색에는 빨강 계열을 쓰지 않는다 | 무늬도 주홍을 빼고 돌색 / 강조색을 남색 계열로 |
| 6 | ゆ 기리 뒤 그림이 のれん과 닮은 문제 | **다시 그림**(노천탕 + 등나무 보라 노렌, 1장) | 그대로 두고 팔레트·무늬로만 구분 |
| 7 | 다크 모드의 지도 그림 | **덮개 0.45로 시작**, 실기기에서 탁하면 다크 전용 4장 | 처음부터 다크 전용 |
| 8 | 스킨 수 | 히라가나 4개 + 기본으로 시작. 가타카나 배경 후보(コンビニ·カフェ·ホテル)를 스킨으로 확정할 때 함께 늘림 | 히라가나 장면의 배정을 다시 해 스킨을 늘림(planner) |
| 9 | 데이터 파일 자리 | `KanaTrip/Resources/skins.json`(rewards.json 옆), Android는 복사 | 공용 폴더(`shared/` 등)로 rewards.json과 함께 옮김. 안드로이드 착수 때 |
| 10 | 스킨별 대체 앱 아이콘 | **범위 밖** | 스킨을 쓰면 아이콘도 바꿈(iOS 대체 아이콘, 사용자 확인 창이 뜬다) |
| 11 | 저장 키 | **`background` 그대로** | `skin`으로 이름 바꾸고 저장 버전 3 |
| 12 | 스킨 값 | **300엔 그대로** | 스킨만 비싸게(값 표가 생김) |

PLAN.md 8번에 올릴 미정 항목 후보(결정 뒤 남는 것):

- 스킨의 실기기 확인: 무늬 모아레, とりい 강조색과 기본 스킨의 구분, えき 청록과 맞음 초록의 구분, 스킨 바탕 위 엔 아이콘(`HighlightStrong` 3.6:1), 다크의 지도 그림 덮개 (9.3)
- 지도 장소 그림 4장과 ゆ 기리 뒤 그림 생성(로컬 그림 환경 필요)
- 홈 첫 방문 스킨 대사(planner)

### 9.3 실기기에서 확인할 것

| 값 | 확인할 것 |
|---|---|
| 무늬 불투명도 0.06 / 0.05 | 흔들리는 환경에서 무늬가 지글거리지 않는지, 목록 글자(머리글)가 무늬 위에서 바로 읽히는지 |
| `AppBackgroundQuiet` | 학습 화면에서 "스킨 안에 있다"가 느껴지는 최소한인지, 반대로 캔버스 집중을 방해하지 않는지 |
| とりい 강조색 `#7A4422` | 기본 스킨 진갈색과 구분되는지, 빨강으로 읽히지 않는지 |
| えき 강조색 `#1D5E6E` | S의 번호 원과 완료 체크가 한눈에 갈리는지 |
| 스킨 썸네일 60·44pt | 아래 색 띠 20pt(44pt판 15pt)에서 스킨 색이 구분되는지 |
| K 화면 전체 미리 보기 0.3초 | 칸을 빠르게 넘겨 볼 때 번쩍거림이 거슬리지 않는지 |
| 다크의 지도 그림 덮개 0.45 | 그림이 탁하거나 노드가 묻히지 않는지 |

## 10. 변경 기록

- 2026-11-17: 처음 씀. 사용자 결정("배경 아이템은 전체 앱 스킨의 형태")에 따른 구상안. 스킨 정의, 토큰 12개, 스킨 5개의 라이트·다크 팔레트와 손 계산 대비, 강도 단계, K 테마 탭, 그림 재료와 프롬프트 초안, `skins.json`과 Material 3 대응, 데이터·구현 범위, 충돌 목록과 결정 후보.
