# 앱 스킨: 색상 고르기

- 작성일: 2026-11-17, **개정 2026-11-21 (색상 선택)**
- 상태: A(색상 스킨)는 **확정 사양**, B(배경 활용안)는 **사용자 선택 전**. 이 문서가 스킨 구현의 기준이다
- 근거: 사용자 결정 "배경 아이템은 전체 앱 스킨의 형태였으면 좋겠어"(PLAN.md 9번 2026-11-17), GitHub 이슈 #7의 답(0.2), 이슈 #7 추가 지시 "지금 스킨은 그냥 색상으로 선택하게 하고, 배경은 어떻게 사용할지 좀 생각해봐"(2026-11-21)
- 기준 문서: `PLAN.md` 3번("시각 스타일", "기리 꾸미기"), [visual-rules.md](visual-rules.md) 1·2.5·3·6·8번, [reward-flow.md](reward-flow.md) 3·6번, `docs/content/reward-system.md` 1.2·4.2·5번, `KanaTrip/Resources/skins.json`, `tools/check_skin_contrast.py`
- 함께 보는 문서: [home-map.md](home-map.md). 홈은 "2026-11-21 재구성안" A/B가 사용자 선택 전이다. 이 문서는 **홈에서 스킨이 바꾸는 것은 바탕색, `PathEdge`, 지도 밖 버튼의 강조색뿐**이라는 원칙만 정한다(4.2)

화면 기호는 scene-flow.md 1번과 reward-flow.md를 따른다: H 홈, S 장면 진입, L1 글자 소개, L2 따라 쓰기, W 단어 읽기, QI 퀴즈 안내, QA·QD·QC 퀴즈, C1 세션 완료, C2 장면 완료, K 기리 꾸미기, I 정보.

## 2026-11-21 개정: 색상 선택

### 무엇이 바뀌었나

| 항목 | 개정 전 | 개정 후 | 절 |
|---|---|---|---|
| 스킨의 정체 | 장소 테마("쪽빛 노렌", "주황 참배길" …): 바탕색 + 무늬 타일 + 강조색 + 기리 뒤 그림 | **색상 하나**: 바탕색 + 강조색. 무늬와 그림은 없다 | 1 |
| 스킨 이름 | 아이템 가나 이름(のれん 등), `nameKo`는 화면에 안 씀 | **한국어 색 이름 2글자**: 기본, 파랑, 청록, 주황, 보라. 화면에 쓴다 | 3.1 |
| K 스킨 탭 | 126pt 칸 3열, 썸네일(기리 뒤 그림 + 색 띠) | **색 견본 52pt 원 5열 한 줄** | 5.2 |
| 주황 (라이트) | 주 버튼 바탕 `#8A4208` + 흰 글자 → 갈색으로 보임 | 주 버튼 바탕 **밝은 주황 `#F57F20` + 진한 글자 `#4A2219`**. 글자·선은 `#8A4208` | 2.1, 3.3 |
| 강조색 토큰 | `AccentColor` 하나가 면과 글자를 다 맡음 | **`AccentColor`(면)와 `AccentText`(글자·선)로 나눔**. 주황 라이트만 값이 다르고 나머지는 같은 값 | 2.1 |
| 다크 모드 | 강조색이 옅은 파스텔(채도 C\* 약 20), 학습 화면 바탕이 거의 무채색 → 스킨 차이가 거의 없음 | 다크 강조색 채도를 C\* 32~69로 올림, 바탕과 `Quiet`에 그 색의 기운을 넣음 | 3.4 |
| 대비 예외 3곳 | 기본 라이트 1.065, えき 다크 1.137, のれん 다크 1.158 | **값을 고쳐 예외 0** (기본 라이트 `Quiet` `#FBF2E1` 1.09, 청록 다크 `#101A1B` 1.17, 파랑 다크 `#131824` 1.17) | 3.5 |
| 무늬 타일 4장 | 강·중 화면 바탕에 깔림 | **스킨에서 뺌.** 에셋과 스크립트는 B가 정해질 때까지 남긴다 | 6 |
| 기리 뒤 그림 4장 | 스킨을 고르면 K 미리보기에 깔림 | **스킨에서 뺌.** 어디에 쓸지는 B | 6, B |
| `skins.json` | schemaVersion 1 | **schemaVersion 2** (`AccentText` 추가, `PatternInk`·`patternOpacity`·`images` 삭제) | 7 |

바뀌지 않은 것: 스킨이 바꾸지 않는 고정 토큰과 자리(1.2), 화면별 강도의 뜻(약 단계 = 옅은 바탕), K 화면 전체 미리 보기와 0.3초 교차 페이드(5.3), 아이템 id·값 300엔·열리는 장면(8.1), 저장 키 `background`(8.2), "기본 차림으로"가 스킨을 건드리지 않는 권장안(5.5).

### 기존 저장 데이터의 이전 규칙

**저장 형식 이행은 없다.** 스킨과 아이템의 연결이 `skins.json`의 `itemID` 한 줄이라 아이템 id가 그대로 색을 가리킨다.

| 저장된 것 | 개정 후 |
|---|---|
| `owned`에 `noren` / `eki` / `torii` / `yu` | 파랑 / 청록 / 주황 / 보라를 가짐 |
| `equipped["background"]` = 아이템 id | 그 색을 쓰는 중. 앱을 업데이트하면 무늬와 기리 뒤 그림만 사라지고 색은 이어진다 |
| `equipped["background"]` 없음 | 기본 |
| `paid`(열린 아이템) | 그대로. 잠김·열림 판단 그대로 |
| `RewardState.currentVersion` | 그대로 |

- 스킨 `id`는 색 이름으로 바꾼다(`blue`, `teal`, `orange`, `purple`). 저장 상태는 스킨 id를 쓰지 않으므로 영향이 없다. `-skinDebug`는 스킨 id와 아이템 id를 둘 다 받는다(`-skinDebug orange`와 `-skinDebug torii`가 같다).
- 앱이 schemaVersion 1 파일을 읽을 일은 없다(번들 파일이 하나). 안드로이드는 아직 구현 전이라 맞출 판이 없다.
- 사용자가 아직 없으므로 "스킨이 바뀌었어요" 안내 화면은 두지 않는다.

### 기획 결정이 필요한 것 (직접 바꾸지 않았다)

| # | 무엇 | 이 문서의 처리 | 결정할 사람 |
|---|---|---|---|
| P1 | 스킨 아이템 4개(のれん·えき·とりい·ゆ)가 화면에서 **가나 이름 대신 색 이름**으로 보인다. 16개 아이템 중 4개가 가나 단어를 잃는다 | 화면은 색 이름으로 그렸다(사용자 지시 "그냥 색상으로"). 데이터의 가나 이름은 그대로 둔다. B의 안 1을 고르면 가나 이름은 "배경" 칸에서 다시 쓰인다 | 사용자 → planner |
| P2 | 색 수 | 4색 + 기본 유지(3.1). 색은 그림이 없어 늘리기 쉽지만 **늘린 색을 어떻게 여는지**(장면·값)가 기획이다 | 사용자 → planner (가타카나 아이템과 함께) |
| P3 | 값 300엔 | 그대로. 그림 없이 색만 바뀌는 아이템이 머리 토핑과 같은 값이 맞는지는 B와 묶여 있다(안 1이면 배경 그림이 함께 열려 지금 값이 자연스럽다) | 사용자 |

## 배경 활용안 (사용자 선택 전)

**이슈에 옮길 부분: B1 표와 B2 추천.** "배경"은 색상 스킨에서 떼어 낸 그림 재료다: 무늬 타일 4장(스크립트), 기리 뒤 그림 4장(`Item-noren`·`Item-eki`·`Item-torii`·`Item-yu`, 이미지 모델로 그린 기존 그림), 장면 그림 8장(홈·S에서 쓰는 중).

### B1. 비교

| | **안 1. 꾸미기 배경** (추천) | 안 2. 장면 띠 무늬 | 안 3. 홈 바탕 고르기 |
|---|---|---|---|
| 한 줄 | 기리 뒤 그림을 K에서 따로 고르는 "배경"으로 | 끝낸 장면의 띠에 그 장면 무늬가 깔림 | 장면마다 넓은 풍경을 모으고 하나를 홈 바탕으로 |
| 어디에 보이나 | K 미리보기 카드 안, 기리 뒤 (개정 전 자리 그대로) | 홈의 장면 띠 바탕(끝낸 장면만) | 홈 위쪽, 지도(또는 무대) 뒤 화면 폭 |
| 고르는 곳 | K 스킨 탭 안 "배경" 줄(없음 + 4칸). 탭 수는 4개 그대로 | 고르지 않음(자동) | K 또는 홈 메뉴에 새 자리 |
| 얻는 법 | 색 아이템을 사면 **그 장소 배경도 함께** 열림 (のれん을 사면 파랑 + のれん 배경). 값·열리는 장면 그대로 | 장면을 처음 끝내면 자동 | 장면을 처음 끝내면 그 장면 바탕이 모임. 값 없음 |
| 필요한 그림 | **새 그림 0.** 기존 4장 그대로 | 무늬 8장: 기존 4장 + **새 4장 스크립트**(돈카츠집·소바집·이자카야·료칸) | **로컬 이미지 모델 8장**(장면별 넓은 풍경). home-map.md 8.2의 "바탕 띠"와 합칠 수 있음 |
| 구현 규모 | **0.5~1일** (저장 키 `backdrop` 하나, K 줄 하나) | 약 1일 (무늬 스크립트 0.5 + 띠 층 0.5) | 그림 1~1.5일 + 코드 1.5~2일 |
| 장점 | 이미 그린 그림의 값이 살아남음. 가나 이름(のれん 등)이 배경 칸에 남아 P1이 풀림. 학습 화면·홈과 무관 | 매일 보는 홈에서 진행이 보임. 경제(엔)를 건드리지 않음 | 가장 눈에 띄는 보상. 장면 수집의 재미 |
| 단점 | K에서만 보여 존재감이 작음. 무늬 4장은 쓰지 않음 | 고르는 재미가 없음. 기리 뒤 그림 4장은 쓰지 않음. 띠 글자 위 무늬 대비를 다시 봐야 함 | 그림 부담이 큼. 지도 칸·점선의 가독성과 겨룸. 기획 결정(새 보상 종류) 필요 |
| 홈 재구성 안 A와 | 충돌 없음 | 띠(바탕·테 없음)에 무늬를 깐다. 띠 가나 17pt `InkSecondary`의 대비 재검사 필요 | 스크롤되는 칸 뒤 그림이라 덮개가 필요하고, 장면 띠 그림과 겹친다 |
| 홈 재구성 안 B와 | 충돌 없음 | 띠가 없어 무대 그림 테나 여정 도장으로 옮겨야 해 효과가 약함 | 무대에 이미 장면 그림이 있어 겹친다 |
| 기획 결정 | 없음 (얻는 법은 지금 아이템 그대로) | 없음 (보상 추가지만 값·엔 없음) — PM 확인 | 필요 (새 보상 종류) |

### B2. 추천: 안 1 (꾸미기 배경)

- 새 그림이 0장이고 홈 재구성(A/B)이 어느 쪽으로 가도 영향이 없다. 홈이 정해지기 전에 붙여도 되돌릴 일이 없다.
- 개정 전에 "배경"으로 정해 그린 그림 4장의 가치가 그대로 남는다. 사용자가 산 것은 "색 + 그 장소 그림"이 되어 300엔(P3)도 자연스럽다.
- 색은 앱 전체, 그림은 기리 뒤로 **자리가 나뉜다.** 개정 전 문제(장소 이름이 길고, 그림과 색이 묶여 고를 수 없음)가 없어진다.
- 안 2는 안 1과 함께 할 수 있다. 홈 재구성이 안 A로 정해진 뒤 띠가 비어 보이면 그때 더한다.

안 1을 고르면 이 문서에 붙일 것(구현 전 designer가 쓸 사양의 뼈대): 저장 `equipped["backdrop"]` = 아이템 id(키 없음 = 없음, 이행 없음) / K 스킨 탭의 견본 줄 아래 16pt에 섹션 머리 "배경"(`.footnote` `InkSecondary`) + reward-flow.md 3.5 칸 3열(없음, のれん, えき, とりい, ゆ, 썸네일 `ItemThumb-{id}`, 가나 이름) / 칸 상태는 그 색 아이템의 상태를 그대로 따름(색을 사면 배경도 "가짐") / 미리보기 카드 안 기리 뒤에만 그림(reward-flow.md 7번 그대로) / "기본 차림으로"는 배경을 건드리지 않음.

## 0. 요약

| 정한 것 | 값 | 절 |
|---|---|---|
| 스킨이 바꾸는 것 | 화면 바탕색, 강조색(면·글자), 홈 지도의 `PathEdge` | 1.1 |
| 바꾸지 않는 것 | 글자·획 색, 카드·캔버스 바탕, 외곽선, 맞음·틀림 색, 힌트 노랑, 글꼴·크기, 배치·간격, 햅틱, 모든 그림, 앱 아이콘 | 1.2 |
| 화면별 범위 | 바탕(H·K·C2·S·C1·QI·I) / 옅은 바탕(L1·L2·W·QA·QD·QC) + 모든 화면의 강조색 | 1.3, 4.1 |
| 토큰 | 스킨이 채우는 색 6개 × 라이트·다크. 고정 토큰 9개 | 2 |
| 색 목록 | 기본, 파랑, 청록, 주황, 보라 (5개, 장면 순서) | 3.1 |
| 이름 | 한국어 색 이름만. 일본어 색 이름은 붙이지 않는다 | 3.1 |
| K 탭 | 이름 **"스킨"** 그대로. 칸은 색 견본 52pt 원, 5열 | 5.2 |
| 데이터 | `KanaTrip/Resources/skins.json` schemaVersion 2 | 7 |
| 저장 | 키 `background` 그대로, 이행 없음 | 8.2 |
| 대비 예외 | 0개 | 3.5 |
| 새 그림 | 0장 | 6 |

### 0.1 개정 전 이슈 #7 결정의 현재 상태

| # | 질문 | 사용자 답 | 지금 |
|---|---|---|---|
| 1 | K 네 번째 탭 이름 | "스킨" | 그대로 |
| 2 | とりい 강조색 | "주황" | 주황 유지. 값은 이번 개정에서 밝은 주황 면 + 진한 주황 글자로 바꿈(3.3) |
| 3 | えき 청록과 맞음 초록 | 위임 | 청록 유지. 라이트 값 그대로, 다크는 채도를 올린 `#5CC8D6`(맞음 초록과 ΔE 42, 색상각 60°) |
| 4 | 무늬 타일을 스크립트로 | 위임 | 무늬는 스킨에서 빠짐. 쓸지 말지는 B |
| 5 | ゆ 기리 뒤 그림 다시 그리기 | "ㄴㄴ" | 그림은 스킨에서 빠짐. 쓸지 말지는 B |
| 6 | 스킨 데이터 파일 자리 | "추천" | 그대로 `KanaTrip/Resources/skins.json` |

## 1. 스킨의 정의

스킨은 앱이 입는 **색**이다. 기리의 차림(머리·속재료·밥)은 기리 몸에만 걸리고, 스킨은 앱 화면 전체의 바탕색과 강조색을 바꾼다. 한 번에 하나만 쓴다. 고르지 않은 상태가 기본(지금 앱 모습)이다.

### 1.1 스킨이 바꾸는 것

| 자리 | 바뀌는 것 | 토큰 (2번) |
|---|---|---|
| 화면 바탕 | 바탕색 | `AppBackground`, `AppBackgroundQuiet`(약 단계 화면) |
| 강조 **면** | 주 버튼 바탕(`.borderedProminent`), K의 고른 슬롯 탭 바탕 | `AccentColor`, 그 위 글자·아이콘 `AccentForeground` |
| 강조 **글자·선** | 보조 버튼(`.bordered`) 글자와 옅은 바탕, 글자 버튼, 링크, 진행 막대 채움, 할 차례 세션 번호 원, 홈 메뉴 아이콘, 꾸미기 입구 아이콘과 옅은 바탕, "지금 칸으로" 버튼, K 아이템 칸의 쓰는 중 외곽선·체크 배지·미리 보는 중 점선 | `AccentText` |
| 홈 지도 | 바탕(위와 같음), 앞길 선, 잠긴 칸 테 | `AppBackground`, `PathEdge` |
| 내비게이션 바 | 바 뒤에 비치는 바탕 | (바탕을 따름. 바는 투명, 제목 `Ink` 고정) |
| 앱 루트 `.tint` | 시스템 컨트롤의 강조 | `AccentText` |

면과 글자·선을 나눈 이유: 주황처럼 밝아야 제 색으로 보이는 색은 글자 대비(4.5:1)를 맞추려고 어둡게 하면 갈색이 된다. 넓은 면은 밝은 주황 + 진한 글자로, 얇은 선과 글자는 진한 주황으로 그린다. 파랑·청록·보라·기본은 어두워도 제 색이라 두 토큰이 같은 값이다.

### 1.2 바꾸지 않는 것

| 자리 | 고정하는 토큰·값 | 이유 |
|---|---|---|
| 글자, 제목, 판정 문구, 획 데이터 글자, 캔버스의 완성된 획·가이드 획·쓰는 중인 선 | `Ink`, `InkSecondary` | 획 모양과 대비가 학습 내용이다 |
| 카드·캔버스·선택지·말풍선·목록 행·시트 안 카드 바탕 | `CardBackground` | "종이"는 늘 같은 종이다. 가이드 획(`Ink` 0.22)의 보이는 정도도 같다 |
| 카드·선택지 외곽선 | `Outline` 2pt | |
| 맞음·틀림 | `Correct`, `Wrong`, 아이콘 모양, 문구, 햅틱 | 초록·빨강의 뜻이 바뀌면 안 된다 |
| 힌트 | `Highlight`, `HighlightStrong`, `OnHighlight` | 시작점 번호 원, 고리 점선, 엔 아이콘, 지도 지금 칸 |
| L1의 "지금 글자" | `Ink` 굵게 + 형광펜(`Highlight` 0.45) + 밑줄 `Ink` 2pt | 학습 글자의 색이 스킨마다 달라지지 않게 |
| K 색 견본의 고리 | `Ink` (5.2) | 견본 옆에 다른 강조색 고리가 붙으면 어느 색을 고른 것인지 흐려진다 |
| 홈 지도의 지난 길·완료 칸 테·자물쇠·체크·지금 칸·건물·스티커 | `InkSecondary`, `Correct`, `Highlight`, 그림 | home-map.md |
| 글꼴, 텍스트 스타일, 가나 크기, Dynamic Type, 배치, 간격, 버튼 크기, 모서리 | visual-rules.md 2~4번 | 스킨은 색만 바꾼다 |
| 모든 그림(기리, 아이템, 단어, 장면) | 그림 그대로 | |
| 시스템 확인 창의 버튼 색 | 따로 맞추지 않음 | iOS 26의 팝오버 확인 창은 K의 `tint`를 따른다(8.8의 5). 억지로 맞추지 않는다 |
| 앱 아이콘, 실행 화면 | 그대로 | 스킨별 대체 아이콘은 범위 밖 |

**범위 밖**: 무늬, 그림, 효과음, 스킨별 움직임, 스킨별 기리 대사, 스킨별 글꼴. 스킨이 바꾸는 움직임은 "스킨을 바꿀 때의 0.3초 교차 페이드" 하나다(5.3).

### 1.3 화면별 적용 범위

| 화면 | 바탕 | 강조 면 (`AccentColor`) | 강조 글자·선 (`AccentText`) | 고정으로 남는 것 |
|---|---|---|---|---|
| H 홈 | `AppBackground` | 시작 버튼 | 메뉴 아이콘, 꾸미기 입구, "지금 칸으로". 지도 영역 안에는 쓰지 않는다 | 지도 안의 모든 것(1.2), 말풍선, 기리 |
| H의 칸 카드 시트 | `AppBackground` | 시트 주 버튼 | 시트 안 아이콘·글자 버튼 | 카드, 글자 |
| S 장면 진입 | `AppBackground` | 주 버튼 | 할 차례 번호 원 | 목록 행, 완료 체크, 자물쇠, 목표 단어 |
| L1 글자 소개 | `AppBackgroundQuiet` | 주 버튼 | 진행 막대, 보조 버튼 | 획 데이터 글자, 번호 원, 단어 카드, 지금 글자 |
| L2 따라 쓰기 | `AppBackgroundQuiet` | 주 버튼 | 진행 막대, 보조 버튼 | 캔버스와 그 안의 모든 것, 판정 줄 |
| W 단어 읽기 | `AppBackgroundQuiet` | 주 버튼 | 진행 막대 | 단어 글자, 발음 표기, 단어 그림 |
| QI 퀴즈 안내 | `AppBackground` | 주 버튼 | 글자 버튼 | 기리, 말풍선 |
| QA·QD 퀴즈 | `AppBackgroundQuiet` | 주 버튼 | 진행 막대 | 묻는 글자, 선택지, 맞음·틀림 테두리와 아이콘 |
| QC 퀴즈 | `AppBackgroundQuiet` | 주 버튼 | 진행 막대, 보조 버튼 | L2와 같음 |
| C1 세션 완료 | `AppBackground` | 주 버튼 | 글자 버튼 | 체크 배지(`Correct`), 엔 아이콘. 배지 바깥 고리는 그 스킨의 `AppBackground` 3pt |
| C2 장면 완료 | `AppBackground` | 주 버튼 | 글자 버튼 | C1과 같음. 열린 색 아이템은 견본(5.4) |
| K 기리 꾸미기 | `AppBackground` (미리 보는 스킨의 값) | 고른 슬롯 탭 | 다른 탭 글자, 아이템 칸의 쓰는 중 외곽선·체크 배지·미리 보는 중 점선 | 미리보기 카드, 칸 바탕, 엔 아이콘, 색 견본의 고리(`Ink`) |
| I 정보 | `AppBackground` | – | 링크 글자 | 목록 행, 크레딧 |

- 화면 하나에는 바탕 단계 하나다.
- 개정 전의 "아래 고정 영역 단색 + 16pt 그라데이션"(`.skinFixedBottom()`)은 무늬를 가리려던 것이라 이제 아무것도 그리지 않는다. 수정자는 지워도 된다.

## 2. 토큰 구조

### 2.1 스킨이 채우는 토큰 (색 6개)

| 이름 | 역할 | 기본 스킨 값 (라이트 / 다크) |
|---|---|---|
| `AppBackground` | 바탕 단계 화면의 바탕 | `#FDF5E6` / `#1F1714` |
| `AppBackgroundQuiet` | 약 단계 화면(학습·퀴즈)의 바탕. 카드와의 경계가 기준(2.4) 이상 보이게 잡은 색 | `#FBF2E1` / `#1F1714` |
| `AccentColor` | 강조 **면** (1.1) | `#4A2219` / `#F7EEDF` |
| `AccentForeground` | 강조 면 위의 글자·아이콘 | `#FFFDF7` / `#1F1714` |
| `AccentText` (새로) | 강조 **글자·선** (1.1), 앱 루트 `tint` | `#4A2219` / `#F7EEDF` |
| `PathEdge` | 지도의 앞길 선과 잠긴 칸 테 | `#E6D6BC` / `#4A3A32` |

메타 값: `id`(색 id), `itemID`(이 색을 여는 리워드 아이템 id, 기본은 null), `nameKo`(**화면에 쓰는 색 이름**).

뺀 것: `PatternInk`, `patternOpacity`, `pattern`, `giriBackdrop` (2026-11-21 개정). 그 전에 `PathFill`(11-18), `mapScenery`·`sceneryScrimDark`(11-21)를 뺐다.

기본 스킨 라이트의 `AppBackgroundQuiet`가 `#FDF5E6` → `#FBF2E1`로 바뀌었다. 기본 스킨의 학습·퀴즈 화면 바탕이 아주 조금 진해진다(3.5의 대비 예외를 없애기 위해).

### 2.2 모든 스킨이 같이 쓰는 고정 토큰 (9개)

`CardBackground`, `Ink`, `InkSecondary`, `Outline`, `Highlight`, `HighlightStrong`, `OnHighlight`, `Correct`, `Wrong`. 값은 visual-rules.md 1.1 그대로이고 `skins.json`의 `base`에도 적는다(대비 증가 값 포함).

### 2.3 라이트·다크와의 관계

- 색마다 다크 값을 둔다. 시스템 설정이 다크면 다크 값을 쓴다.
- 다크의 `AccentForeground`는 그 색의 다크 `AppBackground`와 같은 값이다.
- 다크의 `AccentText`는 모든 색에서 `AccentColor`와 같다(밝은 강조색이 어두운 바탕 위 글자로도 충분히 읽힌다).
- **다크 바탕은 밝게 할 수 없다.** `AppBackground`는 `Outline`(다크 `#8C7366`)의 3:1 때문에 상대 휘도 0.029 이하, `AppBackgroundQuiet`는 카드 경계 1.16 때문에 0.0099 이하다. 그래서 다크에서 색의 차이는 **강조색의 채도**가 주로 맡고, 바탕은 같은 어둡기에서 색 기운만 넣는다(3.4).

### 2.4 접근성과 색 구분 기준

visual-rules.md 1.4(글자 4.5:1, 글자 아닌 표시 3:1)를 모든 색이 지킨다. 아래 "바탕"은 `AppBackground`, `AppBackgroundQuiet` 둘 다다(대비 증가에서는 `Quiet`만).

| # | 조건 | 기준 (라이트·다크 같음, 따로 적은 것 빼고) | 근거 |
|---|---|---|---|
| 1 | 바탕의 상대 휘도 | 라이트 **0.72 이상**, 다크 **0.029 이하** | 라이트: `InkSecondary` 4.5:1의 하한. 다크: `Outline` 3:1의 상한 |
| 2 | `CardBackground` / `AppBackgroundQuiet` | 라이트 **1.07 이상**, 다크 **1.16 이상** | 외곽선이 없는 캔버스의 네 변이 보여야 한다. 기본 스킨 자신도 넘는다(예외 없음) |
| 3 | `AccentForeground` / `AccentColor` | **4.5 이상** | 주 버튼 글자 |
| 4 | `AccentText` / 바탕, `CardBackground` | **4.5 이상** | 글자 버튼·링크 글자. 진행 막대·번호 원(3:1)도 이것으로 덮인다 |
| 5 | `AccentText` / 보조 버튼 바탕(바탕에 `AccentText` 15%를 sRGB로 섞은 색) | **4.5 이상** | 보조 버튼 글자 |
| 6 | `Ink`, `InkSecondary`(4.5), `Correct`, `Wrong`, `HighlightStrong`, `Outline`(3) / 바탕 | 괄호 안 값 | 고정 토큰이 스킨 바탕에서도 통과 |
| 7 | **강조색과 판정색의 거리**: `AccentColor`와 `AccentText` 각각, `Wrong`·`Correct`와 | CIELAB ΔE76 **30 이상**. 그 강조색의 채도 C\*ab가 30 이상이면 색상각 차도 **30° 이상** | 빨강 = 틀림, 초록 = 맞음(visual-rules.md 1.2). 채도가 낮은 색(기본 진갈색 C\* 23, 크림 C\* 9)은 무채색으로 읽혀 각을 보지 않는다 |
| 8 | **강조색과 힌트색의 거리**: `AccentColor`와 `AccentText` 각각, `HighlightStrong`·`Highlight`와 | ΔE76 **20 이상** | 노랑·호박 = 힌트 |
| 9 | 바탕의 HSV 색상 | 125°~160°(채도 25% 이상), 330°~359° **금지** | item-art 금지 범위와 같다 |

`AccentColor` / 바탕의 대비는 기준으로 두지 않는다. 주 버튼은 글자(3번)가 버튼임을 알리고, 면과 바탕의 대비는 WCAG 1.4.11에서 요구하지 않는다(글자가 있는 버튼). 주황 라이트의 주 버튼 면은 바탕과 약 2.2:1이다. 진행 막대·번호 원처럼 면 자체가 정보인 것은 `AccentText`로 그린다(1.1).

CIELAB 계산: sRGB → 선형 → XYZ(D65) → L\*a\*b\*(Xn 0.95047, Yn 1, Zn 1.08883). ΔE76 = √(ΔL\*² + Δa\*² + Δb\*²), 색상각 h = atan2(b\*, a\*), 채도 C\* = √(a\*² + b\*²). `tools/check_skin_contrast.py`와 `SkinContrastTests`에 이미 있는 식 그대로다.

**자동 검사**: `tools/check_skin_contrast.py`가 `skins.json`을 읽어 색 × 모드 × (보통 / 대비 증가)마다 위 표를 계산하고, 하나라도 못 넘으면 0이 아닌 값으로 끝난다. 같은 검사를 `SkinContrastTests`가 한다. **알려진 예외 목록(`KNOWN_EXCEPTIONS`, `Rule.knownExceptions`)은 비운다.** 스크립트 고칠 곳은 8.5.

`PathEdge`는 대비 조건이 없다(장식. 상태는 자물쇠·체크가 말한다). 바탕과 눈으로 구분되는지만 본다.

### 2.5 접근성 설정과의 관계

| 설정 | 스킨에서 일어나는 일 |
|---|---|
| 대비 증가 | 바탕은 모든 화면에서 `AppBackgroundQuiet`. 강조색은 그대로. 고정 토큰은 `base`의 `highContrast` 값 |
| 동작 줄이기 | 스킨을 바꿀 때의 교차 페이드 없이 바로 바꾼다 |
| 다크 모드 | 2.3 |
| 굵은 텍스트, Dynamic Type | 스킨과 상관없다. K 견본 격자만 접근성 크기에서 3열(5.2) |

## 3. 색 목록과 값

### 3.1 목록

| 순서 | 색 id | `nameKo` (화면 이름) | 여는 아이템 (장면) | 라이트 강조 | 다크 강조 |
|---|---|---|---|---|---|
| 0 | `default` | 기본 | 없음 | 진갈색 | 크림 |
| 1 | `blue` | 파랑 | `noren` (1 스시집) | 쪽빛 `#2F4A7A` | 맑은 파랑 `#6FB8FF` |
| 2 | `teal` | 청록 | `eki` (4 역) | 청록 `#1D5E6E` | 밝은 청록 `#5CC8D6` |
| 3 | `orange` | 주황 | `torii` (5 신사·축제) | 면 `#F57F20` / 글자 `#8A4208` | 주황 `#FF9A3D` |
| 4 | `purple` | 보라 | `yu` (7 온천) | 등나무 보라 `#5B4482` | 연보라 `#C49AF0` |

- **4색 + 기본을 유지한다.** 색을 여는 아이템이 4개뿐이고, 색을 늘리려면 여는 방법이 필요하다(P2). 늘릴 때 후보 색상 자리는 3.6.
- 순서는 장면 순서(= 열리는 순서)다.
- **이름은 한국어 색 이름만 쓴다.** 일본어 색 이름(あお, だいだい, むらさき)은 여행 장면 단어가 아니고 아직 안 배운 글자가 섞여 "배운 글자로 읽는다"는 원칙과 맞지 않으며, 사용자가 이름이 길다고 지적했다.
- "파랑"은 라이트(쪽빛)와 다크(맑은 파랑)를 함께 부를 수 있는 이름으로 골랐다.

### 3.2 팔레트: 라이트

| 토큰 | 0 기본 | 1 파랑 | 2 청록 | 3 주황 | 4 보라 |
|---|---|---|---|---|---|
| `AppBackground` | `#FDF5E6` | `#E3E9F4` | `#DCEFF4` | `#F8E6DA` | `#ECE6F2` |
| `AppBackgroundQuiet` | **`#FBF2E1`** | `#EEF1F6` | `#EBF5F7` | `#FBF0E8` | `#F3F0F6` |
| `AccentColor` | `#4A2219` | `#2F4A7A` | `#1D5E6E` | **`#F57F20`** | `#5B4482` |
| `AccentForeground` | `#FFFDF7` | `#FFFDF7` | `#FFFDF7` | **`#4A2219`** | `#FFFDF7` |
| `AccentText` | `#4A2219` | `#2F4A7A` | `#1D5E6E` | **`#8A4208`** | `#5B4482` |
| `PathEdge` | `#E6D6BC` | `#B9C5DD` | **`#A9CDD5`** | **`#EDC09A`** | **`#CDBFE0`** |

굵게 = 개정 전과 다른 값. 바탕·`Quiet`(기본 제외)와 파랑·청록·보라의 강조색은 개정 전 검사를 통과한 값 그대로다. `PathEdge`는 개정 전의 장소 색(나무색 등)을 버리고 그 색의 옅은 값으로 바꿨다.

### 3.3 주황을 갈색으로 보이지 않게 (라이트)

- **문제**: 개정 전 `#8A4208`은 흰 글자 4.5:1과 보조 버튼 글자 4.5:1을 맞추려고 상대 휘도 0.10까지 어둡게 한 주황이다. 주황은 어두워지면 갈색으로 읽힌다(파랑·보라는 어두워도 제 색). 넓은 주 버튼 면에서 이것이 두드러졌다.
- **해결**: 면과 글자를 나눴다(1.1).
  - 면 `AccentColor` **`#F57F20`**: 밝은 주황(CIELAB L\* 66, C\* 77, 색상각 59°). 위 글자는 **`#4A2219`**(= `Ink`), 대비 5.17.
  - 글자·선 `AccentText` **`#8A4208`**: 개정 전 값 그대로(검사 통과 값). 얇은 선과 글자에서는 진한 주황으로 읽힌다.
- **판정색·힌트색과의 거리** (CIELAB, 손 계산):
  - `#F57F20` / `Wrong` `#B8233F`: ΔE **53.3**, 색상각 차 **37.8°**(59° / 21°). 명도 차도 크다(L\* 66 / 41).
  - `#F57F20` / `HighlightStrong` `#A86A00`: ΔE **27.8**. / `Highlight` `#F6B92B`: ΔE **33.2**(색상각 59° / 82°).
  - `#8A4208` / `Wrong`: ΔE 38.2, 색상각 37.2°. / `HighlightStrong`: ΔE 21.3 (개정 전 검사 값).
  - 색상 자리: 빨강(21°)과 30° 이상, 노랑 힌트(82°)와 ΔE 20 이상인 좁은 띠(CIELAB 약 51°~63°) 안의 59°다. 더 노랑 쪽(68°, 예 `#F7931E`)은 `Highlight`와 ΔE 20.6으로 빠듯해 쓰지 않았다.
- 모양으로도 가른다: `Wrong`은 늘 `xmark`, 오답 칸 3pt 테두리, 틀린 획, "정답은 …예요" 문구와 함께 나온다. 강조 면은 주 버튼과 고른 탭에만 쓴다. 두 색이 같은 모양에 쓰이는 자리는 없다.

### 3.4 팔레트: 다크

| 토큰 | 0 기본 | 1 파랑 | 2 청록 | 3 주황 | 4 보라 |
|---|---|---|---|---|---|
| `AppBackground` | `#1F1714` | **`#121B2E`** | **`#0E2224`** | **`#2A170C`** | **`#1E1430`** |
| `AppBackgroundQuiet` | `#1F1714` | **`#131824`** | **`#101A1B`** | **`#22150A`** | **`#1A1522`** |
| `AccentColor` | `#F7EEDF` | **`#6FB8FF`** | **`#5CC8D6`** | **`#FF9A3D`** | **`#C49AF0`** |
| `AccentForeground` | `#1F1714` | **`#121B2E`** | **`#0E2224`** | **`#2A170C`** | **`#1E1430`** |
| `AccentText` | `#F7EEDF` | **`#6FB8FF`** | **`#5CC8D6`** | **`#FF9A3D`** | **`#C49AF0`** |
| `PathEdge` | `#4A3A32` | **`#34405C`** | **`#2B4B4F`** | **`#5A3A22`** | **`#43385A`** |

**다크에서 차이가 느껴지게 한 방법**:

1. 강조색 채도: 개정 전 파스텔(C\* 약 18~25, 주황만 50)을 C\* **32~69**로 올렸다. 상대 휘도는 0.40~0.48로 두어 어두운 바탕 위 글자 대비(6 이상)와 그 위 어두운 글자 대비(7.8 이상)를 함께 지킨다.
2. 강조색끼리의 거리: 파랑(색상각 266°)과 보라(310°)는 ΔE 34, 파랑과 청록(211°)은 ΔE 35. 개정 전 파랑 `#B4C3E6`과 보라 `#CDBDE8`은 둘 다 옅은 라벤더라 다크에서 거의 같아 보였다.
3. 바탕 색 기운: `AppBackground`는 같은 어둡기(휘도 0.010~0.014)에서 HSV 채도를 58~71%로 올렸다(개정 전 42~58%). `Quiet`는 개정 전 무채색에 가까웠던 것(`#1A191C`, `#191C1A`)을 그 색 쪽으로 돌렸다. `Quiet`는 휘도 0.0099 이하라는 한계(2.3) 때문에 차이가 작고, 학습 화면에서 다크 스킨의 차이는 주로 진행 막대와 주 버튼이 맡는다.

판정·힌트 색과의 거리 (다크, CIELAB 손 계산):

| 색 | L\* / C\* / 색상각 | ΔE·각 `Wrong` `#FF6B7A`(21°) | ΔE·각 `Correct` `#6BC98A`(151°) | ΔE `Highlight` `#F6B92B` |
|---|---|---|---|---|
| 파랑 `#6FB8FF` | 73 / 42 / 266° | 87 / 114° | 76 / 115° | 115 이상 |
| 청록 `#5CC8D6` | 75 / 32 / 211° | 92 / 169° | **42.1 / 60°** | 90 이상 |
| 주황 `#FF9A3D` | 73 / 69 / 64° | **49.8 / 43.7°** | 82 / 87° | **24.3** |
| 보라 `#C49AF0` | 71 / 48 / 310° | 64 / 70° | 100 이상 | 110 이상 |

- 가장 빠듯한 곳은 주황과 `Highlight`(24.3, 기준 20)다. 더 노랑 쪽으로 옮기지 않는다.
- 청록과 맞음 초록은 ΔE 42, 각 60°이고 노랑-파랑 축(b\*)의 부호가 반대다(청록 −16, 초록 +23). 적록 색각 이상에서도 갈린다. 둘이 한 화면에 만나는 곳은 S의 번호 원(숫자)과 완료 체크(체크 모양 + "완료")다.

### 3.5 손으로 계산한 대비

sRGB 상대 휘도로 계산했고 값은 내림했다. **최종 판정은 `check_skin_contrast.py`다.** 개발자는 `skins.json`을 7.2대로 바꾼 뒤 스크립트를 돌려 결과 표를 이 절 아래에 붙인다. 미달이 나오면 아래 "미달 시 조정 방향"대로 한 단계씩 고치고, 고친 값을 이 문서 3.2·3.4·7.2에 함께 반영한다.

라이트:

| 조합 | 기준 | 기본 | 파랑 | 청록 | 주황 | 보라 |
|---|---|---|---|---|---|---|
| `AppBackground` 휘도 | ≥ 0.72 | 0.92 | 0.81 | 0.83 | 0.81 | 0.81 |
| `CardBackground` / `Quiet` | ≥ 1.07 | **1.09** | 1.11 | 1.09 | 1.10 | 1.11 |
| `InkSecondary` / `Quiet` | ≥ 4.5 | 5.5 | 5.5 | 5.6 | 5.5 | 5.5 |
| `AccentForeground` / `AccentColor` | ≥ 4.5 | 13.5 | 8.6 | 7.2 | **5.1** | 8.0 |
| `AccentText` / 바탕 | ≥ 4.5 | 12.6 | 7.2 | 6.1 | 6.0 | 6.6 |
| `AccentText` / 보조 버튼 바탕 | ≥ 4.5 | 9.5 | 5.7 | 4.9 | 4.8 | 5.3 |
| `Correct` / 바탕 | ≥ 3 | 4.5 | 4.2 | 4.3 | 4.2 | 4.1 |
| `HighlightStrong` / 바탕 | ≥ 3 | 4.0 | 3.6 | 3.8 | 3.7 | 3.6 |

다크:

| 조합 | 기준 | 기본 | 파랑 | 청록 | 주황 | 보라 |
|---|---|---|---|---|---|---|
| `AppBackground` 휘도 | ≤ 0.029 | 0.0095 | 0.0110 | 0.0136 | 0.0113 | 0.0099 |
| `Quiet` 휘도 | ≤ 0.029 | 0.0095 | 0.0091 | 0.0092 | 0.0089 | 0.0087 |
| `CardBackground` / `Quiet` | ≥ 1.16 | 1.166 | **1.173** | **1.171** | 1.177 | 1.183 |
| `Outline` / `AppBackground` | ≥ 3 | 3.9 | 3.8 | 3.7 | 3.8 | 3.9 |
| `AccentForeground` / `AccentColor` | ≥ 4.5 | 15.3 | 8.1 | 8.3 | 8.1 | 7.8 |
| `AccentText` / `CardBackground` | ≥ 4.5 | 13 이상 | 7.1 | 7.6 | 7.1 | 6.7 |
| `AccentText` / 보조 버튼 바탕 | ≥ 4.5 | 10.0 | 6.0 | 6.1 | 6.0 | 5.9 |

**미달 시 조정 방향** (값마다):

| 값 | 미달이 날 수 있는 조합 | 조정 |
|---|---|---|
| 기본 라이트 `Quiet` `#FBF2E1` | 카드 경계 1.07 | `#FAF0DE`로 한 단계 진하게 |
| 주황 라이트 `AccentColor` `#F57F20` | 위 글자 4.5 / `Highlight`·`HighlightStrong` ΔE 20 / `Wrong` 각 30° | 글자 대비 미달: `AccentForeground`를 `#3A1600`로. ΔE 미달: 색상각을 55°쪽으로(`#F47A1F`). 각 미달: 60°쪽으로(`#F5821F`) |
| 주황 라이트 `AccentText` `#8A4208` | 보조 버튼 4.5(지금 4.85) | 바꾸지 않는다(개정 전 검사 값) |
| 파랑 다크 `#6FB8FF`, 청록 `#5CC8D6`, 보라 `#C49AF0` | 보조 버튼 4.5, 위 글자 4.5 | 휘도를 올린다(밝게, 같은 색상각): `#7DC0FF`, `#6CD0DC`, `#CBA6F2` |
| 주황 다크 `#FF9A3D` | `Highlight` ΔE 20(지금 24.3) / `Wrong` 각 30°(43.7°) | ΔE 미달: 색상각을 낮춘다(`#FF9238`). 둘 다 동시에 미달할 일은 없다 |
| 다크 `AppBackground` 4개 | 휘도 0.029, `Outline` 3 | 같은 색상에서 한 단계 어둡게(각 성분 −2) |
| 다크 `Quiet` 4개 | 카드 경계 1.16 | 각 성분 −1~2. 휘도 0.0095 이하가 목표 |
| 바탕 HSV 금지 범위 | 모두 밖(파랑 221°, 청록 185°, 주황 22~28°, 보라 261~263°) | – |

### 3.6 색을 늘릴 때 (참고, P2가 정해지면)

2.4의 7~9번 때문에 쓸 수 없는 자리: 초록(맞음과 가까움, 바탕 금지 범위), 빨강·분홍(틀림과 가까움, 330°~ 금지), 노랑·호박·금색(힌트). 남는 후보는 **먹색**(채도가 낮아 각 기준이 없고, 기본 진갈색과도 갈림)과 **남색**(파랑 266°와 보라 310° 사이, 다만 둘과 ΔE를 20 이상 벌리기 어렵다) 정도다. 하나 늘 때마다 라이트·다크 6토큰을 정하고 스크립트를 통과시키면 된다(그림 없음).

## 4. 화면별 모습

### 4.1 바탕 단계

| 단계 | 화면 | 바탕 |
|---|---|---|
| 바탕 (`strong`, `medium`) | H, K, C2 / S, C1, QI, I | `AppBackground` |
| 옅은 바탕 (`quiet`) | L1, L2, W, QA, QD, QC | `AppBackgroundQuiet` |
| 시트 (`sheet`) | H의 칸 카드 등 `.sheet` | `AppBackground` (`.presentationBackground`) |

- 무늬가 빠져 강과 중의 차이가 없어졌다. 코드의 `SkinLevel`은 그대로 두어도 되고(`strong`·`medium`이 같은 바탕), 합쳐도 된다. B의 안이 정해져 무늬를 다시 쓸 일이 생길 수 있으니 **그대로 두기를 권한다.**
- 약 단계는 글자, 캔버스, 선택지가 있는 화면이다. 획을 긋는 동안 눈에 들어오는 것(캔버스 바탕, 선 색)은 모든 색에서 같다.

### 4.2 H 홈

홈 배치는 home-map.md가 정한다(재구성안 A/B 선택 전). 이 문서는 원칙만 정한다.

- **지도 영역에서 스킨이 바꾸는 것은 바탕색과 `PathEdge` 둘뿐이다.** 지도의 그림 층(장면 띠, 무대 그림 등)은 모든 색이 같이 쓴다.
- 지도 밖 버튼: 시작 버튼은 `AccentColor` 면 + `AccentForeground` 글자, 꾸미기 입구·메뉴 아이콘·"지금 칸으로"는 `AccentText`(옅은 바탕은 `AccentText` 12%).
- 재구성안 A의 잠긴 칸 테·점선, B의 세션 줄 사이 선·여정 줄 선은 모두 `PathEdge`다. 두 안 모두 이 원칙과 충돌하지 않는다.
- 코드: `MapPalette`(`KanaTrip/Home/Map/MapStyle.swift`)의 스킨 줄(`ground`, `ahead`, `softAccent`)만 스킨 값을 읽는다. `softAccent`는 `AccentText`로 바꾼다.

### 4.3 S 장면 진입, I 정보

```
┌──────────────────────────────────────┐
│ ‹ 지도         스시집                 │
│                                      │ 바탕: AppBackground
│ ┌──────────────────────────────────┐ │ 목록 행: CardBackground (고정)
│ │ 목표 단어 카드                    │ │
│ └──────────────────────────────────┘ │
│  세션                                 │ 섹션 머리글: InkSecondary
│ ┌──────────────────────────────────┐ │
│ │ (1) 배우기          할 차례     › │ │ (1) 번호 원 = AccentText
│ │ (✓) …               완료         │ │ (✓) = Correct (고정)
│ └──────────────────────────────────┘ │
│ [            주 버튼                 ]│ AccentColor 면 + AccentForeground 글자
└──────────────────────────────────────┘
```

I는 같은 바탕, 링크 글자만 `AccentText`.

### 4.4 L1·L2·W·QA·QD·QC

```
┌──────────────────────────────────────┐
│ ✕   ━━━━━━━━━━━━──────────   2/6     │ 진행 막대 채움: AccentText
│                                      │ 바탕 전체: AppBackgroundQuiet
│  す  su                       🔈     │ 글자 정보 줄: Ink / InkSecondary
│ ┌──────────────────────────────────┐ │
│ │ 캔버스 CardBackground (고정)      │ │ 가이드 Ink 0.22, 완성 Ink,
│ │                                  │ │ 틀린 획 Wrong, 번호 원·고리 고정
│ └──────────────────────────────────┘ │
│ [다시 쓰기]  [        다음        ]  │ 보조: AccentText 글자 + 15% 바탕
└──────────────────────────────────────┘ 주: AccentColor 면 + AccentForeground
```

- 주황 라이트에서는 진행 막대·보조 버튼이 진한 주황(`#8A4208`), 주 버튼이 밝은 주황 면 + 진갈색 글자다. 다른 색에서는 셋이 같은 색이다.
- 캔버스 네 변은 `CardBackground`와 `Quiet`의 차이로 보인다. 모든 색에서 라이트 1.09 이상, 다크 1.16 이상이다.
- QA·QD 선택지와 판정 표시는 고정이다.

### 4.5 QI, C1, C2

```
┌──────────────────────────────────────┐
│                                      │ AppBackground
│   (기리 120pt) ✓                     │ 체크 배지 Correct, 바깥 고리 AppBackground 3pt
│               ┌ 말풍선 ┐              │
│   배우기 완료                         │
│   100엔을 받았어요 · 가진 엔 300엔    │
│ [          다음 단계 시작          ]  │ 주 버튼
│            여기까지 하기              │ 글자 버튼: AccentText
└──────────────────────────────────────┘
```

C2의 열린 아이템 줄에서 색 아이템은 견본(5.4)으로 보인다. 색이 열려도 C2의 문구와 배치는 바꾸지 않는다.

## 5. 꾸미기 화면(K)의 스킨 탭

### 5.1 홈과의 계약

| 받는 것 | 쓰는 법 |
|---|---|
| `AppBackground` (라이트·다크) | 지도 바탕 |
| `PathEdge` | 앞길 선, 잠긴 칸 테 (홈 안에 따른 자리) |
| `AccentColor`, `AccentForeground`, `AccentText` | 지도 밖 버튼만(4.2) |
| 고정 토큰 9개 | 그 밖의 모든 지도 요소 |

홈이 스킨에서 받지 않는 것: 노드 모양·크기·간격, 길 굵기, 지난 길 색, 스크롤, 그림.

### 5.2 탭과 견본

**탭**: 이름 **"스킨"**, 순서 머리 → 속재료 → 밥 → 스킨. 규격은 reward-flow.md 3.2 그대로(높이 44pt, 4개 같은 폭, 고른 탭 `.borderedProminent` = `AccentColor` 면 + `AccentForeground` 글자, 나머지 `.bordered` = `AccentText`, 살 수 있는 색이 있으면 `yensign.circle.fill` 13pt).

**견본 격자** (reward-flow.md 3.2 표 9번 "아이템 격자" 자리에 스킨 탭일 때만 들어간다):

```
 16 ┌────────── W − 32 ──────────┐ 16       위 여백 12pt
    ╭─╮   ╭─╮   ╭─╮   ╭─╮   ╭─╮
   ( ✓ ) (   ) (   ) ( 🔒) ( 🔒)          견본 원 52pt (고리 자리 64pt)
    ╰─╯   ╰─╯   ╰─╯   ╰─╯   ╰─╯
    기본  파랑  청록  주황  보라           이름 15pt
   쓰는중 가짐 ¥300엔 잠김  잠김           상태 12pt
```

| 요소 | 값 |
|---|---|
| 격자 | `LazyVGrid` **5열** `.flexible(spacing: 0)`, 행 사이 12pt, 좌우 여백 16pt, 위 여백 12pt, 아래 여백 8pt. 칸 폭 = (W − 32) ÷ 5 (375pt에서 68.6, 402pt에서 74). 스크롤은 격자 영역 안에서(색이 늘어 두 줄이 될 때) |
| 칸 | 폭 = 열 폭, 높이 **108pt**. 칸 전체가 누르는 영역(68.6×108 ≥ 44). 위에서 아래로: 고리 자리 64×64(가운데) → 6pt → 이름 줄 20pt → 2pt → 상태 줄 16pt |
| 견본 원 | 지름 **52pt**, 고리 자리 가운데. 채움 = 그 색의 `AccentColor`(지금 모드 값). 안쪽 테 1pt `Ink` 15%(밝은 색이 밝은 바탕에서, 크림이 다크 바탕에서 가장자리가 보이게) |
| 원 안 아이콘 | 20pt `.bold`, 색 = 그 색의 `AccentForeground`(원 위 대비 4.5 이상인 짝, 2.4의 3번). 쓰는 중 `checkmark`, 잠김 `lock.fill`, 그 밖은 없음 |
| 고리 (쓰는 중) | 지름 64pt(원 바깥 3pt 틈 + 3pt 선), **`Ink` 3pt 실선** |
| 고리 (미리 보는 중) | 지름 64pt, **`Ink` 2pt 점선**(dash 6, 4) |
| 이름 줄 | `nameKo`, `.subheadline.weight(.semibold)`(15pt), `Ink`, `lineLimit(1)`, 가운데 |
| 상태 줄 | `.caption`(12pt), 가운데. 쓰는 중 "쓰는 중"(`Ink`) / 가짐 "가짐"(`InkSecondary`) / 살 수 있음 `yensign.circle.fill`(`HighlightStrong`) + "{값}엔"(`Ink` 굵게) / 엔 부족 `yensign.circle`(`InkSecondary`) + "{값}엔"(`InkSecondary`) / 잠김 "잠김"(`InkSecondary`) / 기본 칸에서 쓰는 중이 아니면 비움 |
| 접근성 크기 (`accessibility1` 이상) | 3열, 칸 높이는 글자를 따라 늘어난다. 원 52pt 고정 |

- **색만으로 상태를 말하지 않는다.** 쓰는 중은 실선 고리 + 체크 + "쓰는 중", 미리 보는 중은 점선 고리, 잠김은 자물쇠 + "잠김", 살 수 있음은 채운 엔 아이콘 + 굵은 값이다.
- **잠긴 색도 색을 보여 준다**(개정 전에는 실루엣). 개정 전에 가린 이유는 아직 안 배운 글자가 든 가나 이름을 미리 보여 주지 않으려는 것이었는데, 색에는 글자가 없다. 갖고 싶은 색이 보이는 것이 장면을 끝낼 이유가 된다.
- 고리와 아이템 칸 외곽선의 차이: 다른 탭의 아이템 칸은 쓰는 중 외곽선이 `AccentText`다. 견본은 색 자체가 내용이라 고리를 `Ink`로 고정한다(1.2).
- 견본 원 사이 거리는 16pt 이상(375pt에서 68.6 − 52)이다. 고리가 둘(쓰는 중 + 미리 보는 중) 나란히 있어도 고리 사이 4.6pt가 남는다.
- 이웃 칸의 누르는 영역은 맞닿는다. 원 사이가 16pt라 visual-rules.md 3번의 "누르는 대상 사이 8pt"는 보이는 대상 기준으로 지킨다.
- 개정 전의 `SkinThumbnail`(기리 뒤 그림 + 색 띠)은 쓰지 않는다. `SkinSwatch(skin:, size:)`로 바꾼다(K 52pt, C2 30pt).

**미리보기 카드**: 스킨 탭에서도 카드 안 기리 뒤는 `CardBackground`다(기리 뒤 그림 없음, B가 정해지면 다시 본다).

### 5.3 누를 때: K 화면 전체가 그 색으로

K는 바탕 단계 화면이고, **스킨 탭에서 견본을 누르면 K 화면 전체(바탕, 고른 탭, 강조 글자·선)가 그 색으로 바뀐다.** 미리보기 카드 안은 바뀌지 않는다.

| 누른 칸 | K 화면 | 저장 | 안내 줄 (1줄 / 2줄) | 햅틱 |
|---|---|---|---|---|
| (스킨 탭을 고름, 처음) | 쓰는 색 | 없음 | {색 이름} / 앱 색으로 쓰고 있어요 | 없음 |
| 쓰는 중 | 그대로 | 없음 | {색 이름} / 지금 쓰고 있어요 | 없음 |
| 가짐 | 그 색으로 (0.3초 교차 페이드) | `equipped.background` = 아이템 id | {색 이름} / 앱 색을 바꿨어요 | `.impact(weight: .light)` |
| 기본 | 기본으로 (0.3초) | `equipped.background` 키 삭제 | 기본 / 기본 색으로 돌아왔어요 | `.impact(weight: .light)` |
| 살 수 있음 | **그 색으로 미리** (임시, 0.3초) | 없음 | {색 이름} / 미리 보는 중이에요 · {값}엔. 확인 창이 뜬다 | 없음 |
| 엔 부족 | 그 색으로 미리 (임시, 0.3초) | 없음 | {색 이름} / {모자란 엔}엔이 더 있으면 살 수 있어요 | 없음 |
| 잠김 | 그대로 (미리 보지 않음) | 없음 | {색 이름} / {장면} 장면을 끝내면 열려요 | 없음 |
| 사기 성공 | 미리 본 모습 그대로 확정 | 사기 + 착용 | {색 이름} / 사서 앱 색을 바꿨어요 | `.success` |
| 사기 취소, 다른 탭으로, 화면을 나감, 엔 부족 칸을 다시 누름 | 쓰던 색으로 (0.3초) | 없음 | 그 탭의 "처음" 문구 | 없음 |

- {색 이름}은 `nameKo`(파랑 등)다. 기본 칸의 "처음" 문구는 "기본 / 기본 색을 쓰고 있어요".
- 확인 창 문구: 제목 **"{색 이름} 색을 {값}엔에 살까요?"**("색을"로 받침 판별을 피한다), 메시지 "산 아이템은 되돌릴 수 없어요". 버튼은 지금 그대로.
- 미리 보기는 K 화면 안에서만이다. K의 뿌리에만 `.environment(\.skin, previewSkin ?? savedSkin)`.
- 전환: 바탕·강조색 0.3초 교차 페이드(`.easeInOut(duration: 0.3)`). "동작 줄이기"면 바로.
- VoiceOver: 견본 칸 하나가 한 요소. 레이블 "{색 이름}"(기본 칸은 "기본 색"), 값은 상태("쓰는 중", "가짐", "{값}엔, 살 수 있음", "{n}엔 모자람", "잠김, {장면} 장면을 끝내면 열려요", 미리 보는 중이면 앞에 "미리 보는 중, "). 고른 칸은 `.isSelected`. K 미리보기의 값 마지막 항목은 "스킨 {색 이름}". 안내 줄이 바뀌면 2줄 문구를 알림으로 읽는다.

### 5.4 리워드를 받는 순간

1. **C2에서 열림**: 열린 아이템 줄(reward-flow.md 6.4)의 색 아이템 묶음은 [44×44 칸(`CardBackground`, 모서리 10, `Outline` 2pt) 가운데에 견본 원 30pt / 간격 2 / 발음 표기 줄 비움 12 / 이름 "{색 이름} 색" 15pt]. VoiceOver는 "{색 이름} 색". 아직 사지 않았으므로 화면 색은 바뀌지 않는다.
2. **K에서 사기**: 미리 본 색이 그대로 확정된다. 바뀌는 것은 점선 고리 → 실선 고리 + 체크, 상태 줄, 가진 엔 숫자, `.success` 햅틱뿐이다.

### 5.5 "기본 차림으로" 버튼

스킨은 기리의 차림이 아니라 앱의 색이라서 **"기본 차림으로"는 스킨을 건드리지 않는다**(권장안, 사용자 확인 전, 9.2). 버튼은 머리·속재료·밥만 되돌리고, `disabled` 조건에서 스킨을 보지 않는다. 스킨 탭에서 미리 보는 중에 누르면 미리 보기를 끝내고 세 슬롯을 되돌린다.

## 6. 그림 재료

**스킨에 필요한 그림은 없다.** 새로 만들 그림도 없다.

스킨에서 뺀 그림 재료는 B가 정해질 때까지 **지우지 않고 둔다**:

| 재료 | 자리 | B에서 |
|---|---|---|
| 무늬 타일 4장 `skin-pattern-{seigaiha,tenji,asanoha,tatewaku}` | 에셋 카탈로그, `tools/make_skin_patterns.py`(규격은 스크립트와 이 문서의 git 기록 2026-11-21 이전 6.3) | 안 2에서 씀. 안 1·3이면 지운다 |
| 기리 뒤 그림 4장 `Item-{noren,eki,torii,yu}`, `ItemThumb-*` | 에셋 카탈로그 | 안 1에서 씀 |
| `docs/design/skins/patterns-preview.png` | 확인용 | 안 2에서 씀 |

`make_skin_patterns.py --check`는 에셋이 남아 있는 동안 그대로 통과해야 한다. CLAUDE.md "그림 생성"의 무늬 타일 예외는 B가 정해질 때까지 유효하다(PM이 정리).

## 7. 데이터 파일

### 7.1 자리

`KanaTrip/Resources/skins.json`. iOS는 번들에서, 안드로이드는 같은 파일을 `assets/`로 복사해 읽는다. 손으로 쓰는 파일이고, 고치면 `check_skin_contrast.py`와 `SkinContrastTests`가 검사한다.

### 7.2 스키마 (schemaVersion 2, 파일 전체)

이 블록을 그대로 `skins.json`에 쓴다.

```json
{
  "schemaVersion": 2,
  "_comment": "앱 스킨 = 색상 (docs/design/app-skin.md). 색은 #RRGGBB, 라이트·다크 둘 다 필수. 스킨 순서 = 꾸미기 화면 견본 순서. nameKo는 화면에 쓰는 색 이름. AccentColor는 면, AccentText는 글자·선.",
  "levels": {
    "strong": { "background": "AppBackground" },
    "medium": { "background": "AppBackground" },
    "quiet":  { "background": "AppBackgroundQuiet" },
    "sheet":  { "background": "AppBackground" }
  },
  "motion": { "skinCrossfade": 0.3 },
  "base": {
    "CardBackground":  { "light": "#FFFDF7", "dark": "#2E2420" },
    "Ink":             { "light": "#4A2219", "dark": "#F7EEDF" },
    "InkSecondary":    { "light": "#7A5A4C", "dark": "#BCA697",
                         "highContrast": { "light": "#5C3D31", "dark": "#D9C7B8" } },
    "Outline":         { "light": "#4A2219", "dark": "#8C7366",
                         "highContrast": { "light": "#4A2219", "dark": "#BCA697" } },
    "Highlight":       { "light": "#F6B92B", "dark": "#F6B92B" },
    "HighlightStrong": { "light": "#A86A00", "dark": "#F6B92B" },
    "OnHighlight":     { "light": "#4A2219", "dark": "#4A2219" },
    "Correct":         { "light": "#2E7D4A", "dark": "#6BC98A" },
    "Wrong":           { "light": "#B8233F", "dark": "#FF6B7A" }
  },
  "skins": [
    {
      "id": "default",
      "itemID": null,
      "nameKo": "기본",
      "colors": {
        "AppBackground":      { "light": "#FDF5E6", "dark": "#1F1714" },
        "AppBackgroundQuiet": { "light": "#FBF2E1", "dark": "#1F1714" },
        "AccentColor":        { "light": "#4A2219", "dark": "#F7EEDF" },
        "AccentForeground":   { "light": "#FFFDF7", "dark": "#1F1714" },
        "AccentText":         { "light": "#4A2219", "dark": "#F7EEDF" },
        "PathEdge":           { "light": "#E6D6BC", "dark": "#4A3A32" }
      }
    },
    {
      "id": "blue",
      "itemID": "noren",
      "nameKo": "파랑",
      "colors": {
        "AppBackground":      { "light": "#E3E9F4", "dark": "#121B2E" },
        "AppBackgroundQuiet": { "light": "#EEF1F6", "dark": "#131824" },
        "AccentColor":        { "light": "#2F4A7A", "dark": "#6FB8FF" },
        "AccentForeground":   { "light": "#FFFDF7", "dark": "#121B2E" },
        "AccentText":         { "light": "#2F4A7A", "dark": "#6FB8FF" },
        "PathEdge":           { "light": "#B9C5DD", "dark": "#34405C" }
      }
    },
    {
      "id": "teal",
      "itemID": "eki",
      "nameKo": "청록",
      "colors": {
        "AppBackground":      { "light": "#DCEFF4", "dark": "#0E2224" },
        "AppBackgroundQuiet": { "light": "#EBF5F7", "dark": "#101A1B" },
        "AccentColor":        { "light": "#1D5E6E", "dark": "#5CC8D6" },
        "AccentForeground":   { "light": "#FFFDF7", "dark": "#0E2224" },
        "AccentText":         { "light": "#1D5E6E", "dark": "#5CC8D6" },
        "PathEdge":           { "light": "#A9CDD5", "dark": "#2B4B4F" }
      }
    },
    {
      "id": "orange",
      "itemID": "torii",
      "nameKo": "주황",
      "colors": {
        "AppBackground":      { "light": "#F8E6DA", "dark": "#2A170C" },
        "AppBackgroundQuiet": { "light": "#FBF0E8", "dark": "#22150A" },
        "AccentColor":        { "light": "#F57F20", "dark": "#FF9A3D" },
        "AccentForeground":   { "light": "#4A2219", "dark": "#2A170C" },
        "AccentText":         { "light": "#8A4208", "dark": "#FF9A3D" },
        "PathEdge":           { "light": "#EDC09A", "dark": "#5A3A22" }
      }
    },
    {
      "id": "purple",
      "itemID": "yu",
      "nameKo": "보라",
      "colors": {
        "AppBackground":      { "light": "#ECE6F2", "dark": "#1E1430" },
        "AppBackgroundQuiet": { "light": "#F3F0F6", "dark": "#1A1522" },
        "AccentColor":        { "light": "#5B4482", "dark": "#C49AF0" },
        "AccentForeground":   { "light": "#FFFDF7", "dark": "#1E1430" },
        "AccentText":         { "light": "#5B4482", "dark": "#C49AF0" },
        "PathEdge":           { "light": "#CDBFE0", "dark": "#43385A" }
      }
    }
  ]
}
```

### 7.3 읽기 규칙

- 앱이 아는 버전은 **2**. 2보다 크면 파일 전체를 버리고 기본(에셋 카탈로그 값)으로 그린다. 1 이하도 버린다(번들 파일이 하나라 읽을 일이 없다).
- 스킨 `id`는 색 id다. 기본은 `default`이고 꼭 첫 번째에 있어야 한다. 저장 상태는 아이템 id만 가지므로 `itemID`로 스킨을 찾는다. 없으면 기본.
- 필수 값: `id`, `nameKo`, `colors`의 여섯 키(모두 `light`·`dark`). 하나라도 빠진 스킨은 버린다. 기본 스킨이 빠졌거나 파일을 못 읽으면 DEBUG `assertionFailure`, 릴리스는 에셋 카탈로그 값.
- 모르는 키는 무시한다. B로 그림 키를 더할 때는 없는 앱이 무시해도 화면이 깨지지 않는 키만 더하고, 아니면 버전을 올린다.
- 에셋 카탈로그 Color Set: `AppBackground`·`AccentColor`·`AccentForeground`·`PathEdge`에 **`AppBackgroundQuiet`·`AccentText`를 더한다**(기본 스킨 값). `SkinContrastTests`가 `skins.json` 기본 스킨과 같은지 비교한다.

### 7.4 Material 3 색 역할 대응 (안드로이드)

| KanaTrip 토큰 | Material 3 역할 |
|---|---|
| `AppBackground` | `background`, `surface` |
| `AppBackgroundQuiet` | (확장 색) 약 단계 화면의 하위 테마 `background` |
| `CardBackground` | `surfaceContainerLowest` ~ `Highest` |
| `Ink` / `InkSecondary` / `Outline` | `onSurface` / `onSurfaceVariant` / `outline` |
| `AccentColor` / `AccentForeground` | `primary` / `onPrimary` |
| `AccentText` | (확장 색) 진행 표시, 글자 버튼, 링크. `secondaryContainer` = 바탕에 `AccentText` 15%, `onSecondaryContainer` = `AccentText` |
| `Wrong` / `Correct` | `error` / (확장 색) |
| `Highlight`, `HighlightStrong`, `OnHighlight` | `tertiaryContainer`, `tertiary`, `onTertiaryContainer` |
| `PathEdge` | (확장 색) |

Material 3의 진행 표시는 기본이 `primary`다. 주황 라이트에서 밝은 면이 진행 막대가 되지 않게 `LinearProgressIndicator(color = AccentText)`로 준다.

## 8. 데이터와 구현

### 8.1 `rewards.json`

아이템 4개(`noren`, `eki`, `torii`, `yu`)의 id, 가나 이름, 장면, 값, 슬롯 `"background"`는 그대로다. `_comment`와 `RewardSlot.background` 주석만 "앱 색. 아이템 id로 skins.json의 색을 찾는다. 키가 없으면 기본 색."으로 고친다. 화면은 이 아이템들의 가나 이름 대신 `skins.json`의 `nameKo`를 쓴다(P1).

### 8.2 저장 상태

이행 없음(맨 위 "이전 규칙"). `equipped["background"]` = 아이템 id, 키 없음 = 기본. `RewardRules.resetOutfit`은 배경 키를 남기고 `isDefaultOutfit`은 그 슬롯을 보지 않는다(5.5).

### 8.3 고칠 곳

| 파일 | 할 일 |
|---|---|
| `KanaTrip/Resources/skins.json` | 7.2 그대로 |
| `KanaTrip/Skin/SkinModel.swift` | `SkinToken`에 `accentText` 추가, `patternInk` 삭제. `Skin`에서 `pattern`·`giriBackdrop`·`patternOpacity*` 삭제. `supportedSchemaVersion = 2`. `fallbackDefault`에 `AppBackgroundQuiet` `#FBF2E1`, `AccentText` |
| `KanaTrip/Skin/SkinStyle.swift` | 무늬 층(`SkinBackdrop`의 타일), `.skinFixedBottom()`의 단색·그라데이션 삭제(또는 빈 수정자). `SkinColor.accentText` 추가. 루트 `.tint`는 `accentText` |
| `KanaTrip/Skin/SkinThumbnail.swift` | `SkinSwatch`(5.2)로 바꿈 |
| `Session/SessionChrome.swift` | 진행 막대 채움 → `accentText`. `SecondaryButton`의 `.tint` → `accentText`. `PrimaryButton`은 그대로(`accent` + `accentForeground`) |
| `Session/CompletionViews.swift` | 글자 버튼 2곳 → `accentText` |
| `Home/SceneDetailView.swift` | 번호 원 → `accentText` |
| `Home/Map/NodeCardSheet.swift` | 아이콘·글자 2곳 → `accentText` (시트의 주 버튼은 `PrimaryButton` 규칙) |
| `Home/Map/MapDock.swift` | 꾸미기 입구 글자·12% 바탕 → `accentText` |
| `Home/Map/MapStyle.swift` | `softAccent` → `accentText` |
| `Rewards/CustomizeView.swift` | 고른 탭은 `accent`, 다른 탭 `.tint`와 칸 외곽선·점선·체크 배지 → `accentText`. 스킨 탭 격자 → 견본 격자(5.2), 안내 줄·확인 창 문구(5.3), 미리보기 카드 안 기리 뒤 그림 삭제 |
| `Session/C2` 열린 아이템 줄 | 색 아이템은 견본(5.4) |
| `App/Strings.swift` | 5.3 문구, VoiceOver |
| `Assets.xcassets` | Color Set `AppBackgroundQuiet`, `AccentText` 추가(7.3) |
| `tools/check_skin_contrast.py`, `SkinContrastTests` | 8.5 |
| DEBUG `-skinDebug` | 스킨 id와 아이템 id 둘 다 받음 |

`AccentColor`를 그대로 쓰는 곳은 **주 버튼 면과 K의 고른 슬롯 탭 면, 견본 원** 셋뿐이다. 나머지 강조는 모두 `AccentText`다. 헷갈리면 "그 색 위에 글자가 올라가면 `AccentColor`, 그 색이 글자나 선이면 `AccentText`".

### 8.4 구현 순서

| 순서 | 할 일 | 끝난 상태의 기준 |
|---|---|---|
| 1 | `skins.json` v2, 스크립트·테스트 개정 | 검사 실패 0, **예외 0**. 결과를 3.5 아래에 붙임 |
| 2 | 모델·스타일: `AccentText`, 무늬·그림 삭제, 스키마 2, Color Set | 기본 스킨에서 바탕 단계 화면이 개정 전과 픽셀 단위로 같음 |
| 3 | 8.3 표의 `accentText` 교체 | 주황 라이트에서 주 버튼만 밝은 주황, 진행 막대·보조 버튼은 진한 주황 |
| 4 | K 견본 격자, 문구, VoiceOver, C2 견본 | 5.3 표의 모든 갈래가 동작 |
| 5 | 8.6 스크린샷 | 목록이 다 있음 |

규모: **약 1~1.5일.** 대부분 토큰 이름 바꾸기와 삭제다. 새 화면 요소는 견본 격자 하나다.

### 8.5 `check_skin_contrast.py` 고칠 곳

- `KNOWN_EXCEPTIONS`를 빈 딕셔너리로(구조는 남김).
- 무늬 픽셀 계산(`screen_bgs`의 "무늬 픽셀"), `PatternInk` HSV 검사, `images` 읽기 삭제.
- `AccentColor / 바탕·카드 ≥ 3` → **`AccentText / 바탕·Quiet·카드 ≥ 4.5`**.
- 보조 버튼 바탕은 `mix(바탕, AccentText, 0.15)`, 검사는 `AccentText / 그 색 ≥ 4.5`.
- `AccentForeground / AccentColor ≥ 4.5`는 그대로.
- 판정색·힌트색 거리(ΔE, 색상각)를 `AccentColor`와 `AccentText` **둘 다**에 대해(값이 같으면 한 번).
- HSV 금지 범위는 `AppBackground`, `AppBackgroundQuiet`만.
- `--markdown` 출력은 그대로.

### 8.6 확인 방법 (스크린샷 목록)

시뮬레이터 iPhone 17 Pro. `xcrun simctl ui <기기> appearance light|dark`, 대비 증가 `increase_contrast enabled`, 색 `-skinDebug <id>`. 파일은 `build/skin-shots/{색}-{light|dark}[-hc]-{번호}-{화면}.png`.

| 번호 | 화면 | 상태 |
|---|---|---|
| 01 | H 홈 | 지금 칸이 보임 |
| 02 | S | 할 차례 번호 원과 완료 체크가 한 화면에 |
| 04 | L2 | 가이드와 시작점 번호 원, 보조·주 버튼 |
| 06 | QA | 오답을 고른 직후(오답 `Wrong` 3pt, 정답 `Correct` 3pt, 진행 막대, 주 버튼) |
| 08 | C2 | 열린 아이템에 색 견본 |
| 09 | K 스킨 탭 | 그 색을 쓰는 중 |
| 10 | K 스킨 탭 | 다른 색을 미리 보는 중, 확인 창 |

| 묶음 | 색 | 모드 | 화면 | 보는 것 |
|---|---|---|---|---|
| A 기본 회귀 | default | light, dark | 01, 02, 06, 09 | 01·02·09는 개정 전과 같음. 06은 라이트 바탕만 `#FBF2E1`로 조금 진함 |
| B 주황 | orange | light, dark | 01, 02, 04, 06, 09, 10 | **라이트 주 버튼이 갈색이 아니라 주황으로 보임.** 06에서 주황과 오답 빨강이 섞이지 않음 |
| C 다크 차이 | 다섯 색 모두 | dark | 01, 04, 09 | 다섯 장을 나란히 놓고 색이 서로 다르게 보임 |
| D 나머지 라이트 | blue, teal, purple | light | 01, 02, 06 | 바탕·강조색이 색마다 다름. teal 02에서 번호 원과 체크가 갈림 |
| E 대비 증가 | orange, teal | light, dark (`-hc`) | 01, 06 | 바탕 단계 화면도 `Quiet` |

자동 검사: `python3 tools/check_skin_contrast.py`(실패 0, 예외 0), `xcodebuild test`(`SkinContrastTests`), `python3 tools/make_skin_patterns.py --check`(에셋이 남아 있는 동안).

### 8.7 다른 담당에게 넘기는 곳

| 문서 | 바꿀 곳 | 담당 |
|---|---|---|
| `docs/content/reward-system.md` | 1.2 표의 스킨 줄("바탕색·바탕 무늬·강조색", "무늬 타일은 스크립트", "기리 뒤 그림은 꾸미기 화면") → "앱 색(바탕색·강조색). 화면 이름은 색 이름". 4.2 표의 스킨 4개 "모습" 열, 9번 그림 목록의 무늬·기리 뒤 그림 줄. P1~P3가 정해진 뒤 | planner (PM 경유) |
| `docs/design/reward-flow.md` | 3.5 표의 "스킨 아이템" 줄(썸네일·가나 이름) → 이 문서 5.2, 3.8 안내 줄 문구, 6.4 C2 묶음, 9.1 VoiceOver, 10 문구 목록 | designer (다음 reward-flow 작업 때. 지금은 머리 줄에 이 문서가 앞선다고 적었다) |
| `docs/design/visual-rules.md` | 1.1 `AccentColor` 쓰임 나누기와 `AccentText` 줄, `AppBackground` 줄의 "기본 스킨에서는 같은 값" 삭제, 8.4의 "무늬를 끄고" 삭제 | designer (같음) |
| `docs/design/item-art/brief.md` | 2번 표의 배경 줄 — B가 정해진 뒤 | designer |
| `PLAN.md` 3번 "시각 스타일"·"기리 꾸미기", 8번 스킨 항목, 9번 기록 | 무늬·기리 뒤 그림 문구, P1~P3, B | PM |
| `CLAUDE.md` "그림 생성"의 무늬 타일 예외 | B가 안 2가 아니면 삭제 | PM |

### 8.8 구현 메모 (2026-11-21, developer, 개정 전 구현)

개정 전 구현에서 남은 메모 가운데 지금도 맞는 것만 남긴다.

1. ~~대비 기준 미달 3곳~~: 이번 개정에서 값을 고쳐 없앴다(3.5).
2. **기본 스킨은 에셋 카탈로그 Color Set으로 칠한다.** sRGB 성분으로 만든 Color를 툴바 안에 쓰면 합성 결과가 1~10 단위 달랐다. 새 Color Set 두 개(7.3)도 같은 방식으로 칠한다.
3. **홈 지도 바탕 층.** `MapView`의 `.background(MapPalette.groundLayer)`는 무늬가 없어졌으니 단색이면 된다. 홈은 저장된 스킨이라 `MapPalette`는 `SkinStore.shared`를 읽는다.
4. **K의 저장된 스킨.** 미리 보는 색이 없을 때 `SkinStore.shared.current`를 바로 읽는다(사기 중 페이드 중간 프레임 문제). 그대로.
5. **시스템 확인 창 색.** iOS 26 팝오버 확인 창 버튼 글자는 K의 `tint`(이제 `AccentText`)를 따른다. 그대로.
6. ~~무늬 층 구현~~, 7. ~~아래 고정 영역~~: 무늬가 빠져 해당 없음.
8. **`SkinPolicy`**: 권장안 값 모음 그대로.
9. **`-skinDebug <id>`**: 아이템 id도 받게 한다(8.3).

## 9. 남은 결정과 확인

### 9.1 다른 문서에 반영한 것 (2026-11-21 개정)

| 문서 | 반영 |
|---|---|
| reward-flow.md, visual-rules.md | 머리 참고 줄에 "2026-11-21 색상 선택 개정: 스킨 탭과 강조색 토큰은 app-skin.md가 앞선다" 한 줄. 본문은 8.7대로 다음 작업 때 고친다 |
| home-map.md | 고치지 않았다(재구성 선택 전). 재구성안 A·B의 `PathEdge`·`AccentColor` 쓰임은 4.2와 맞는다. B의 "지금 줄 번호 원 `AccentColor`"는 구현 때 `AccentText` |

PLAN.md, CLAUDE.md, `docs/content/`는 고치지 않았다.

### 9.2 사용자 확인 전 (본문은 권장안대로)

| # | 정할 것 | 본문의 값 (권장) | 다른 안 |
|---|---|---|---|
| 1 | "기본 차림으로"가 스킨도 되돌리는지 | 되돌리지 않음(5.5) | 네 슬롯 모두 |
| 2 | 학습·퀴즈 화면의 스킨 | 옅은 바탕 + 강조색(4.1) | 학습 화면은 기본 색 고정 |
| 3 | 색 수 | 4 + 기본 (P2) | 늘림(여는 방법 필요) |
| 4 | 스킨별 대체 앱 아이콘 | 범위 밖 | 색을 쓰면 아이콘도 |
| 5 | 저장 키 | `background` 그대로 | `skin`으로 바꾸고 저장 버전 올림 |
| 6 | 값 | 300엔 그대로 (P3) | 색만 싸게 / 비싸게 |
| 7 | 탭 이름 | "스킨" 그대로(이슈 #7 답) | "색" (스킨이 색만 바꾸게 되어 더 정확하다) |
| 8 | 배경 활용 | B의 안 1 (추천) | 안 2, 안 3, 쓰지 않음 |

### 9.3 실기기에서 확인할 것

| 값 | 확인할 것 |
|---|---|
| 주황 라이트 주 버튼 `#F57F20` + `#4A2219` | 주황으로 읽히는지, 진갈색 글자가 밝은 햇빛 아래에서 읽히는지 |
| 주황 라이트의 두 주황(면 `#F57F20`, 글자 `#8A4208`) | 한 화면에 함께 있을 때 다른 색 둘로 보이지 않고 한 색의 진하기로 보이는지 |
| 다크 강조색 4개 | 서로 다른 색으로 바로 구분되는지(특히 파랑과 보라), 어두운 곳에서 눈부시지 않은지 |
| 다크 `Quiet` | 학습 화면에서 "그 색 안에 있다"가 조금이라도 느껴지는지 |
| 청록 `#1D5E6E` / `#5CC8D6` | S의 번호 원과 완료 체크가 한눈에 갈리는지 |
| 견본 52pt, 5열 | 375pt에서 엄지로 틀리지 않고 누르는지, `Ink` 고리가 바로 보이는지 |
| K 화면 전체 미리 보기 0.3초 | 견본을 빠르게 넘겨 볼 때 번쩍거림이 거슬리지 않는지 |

## 10. 변경 기록

- 2026-11-17: 처음 씀. 사용자 결정("배경 아이템은 전체 앱 스킨의 형태")에 따른 구상안.
- 2026-11-18 (designer): 지도 홈 시각 정리안에 맞춰 `PathFill`을 빼고 지도 계약을 고쳤다.
- 2026-11-21 (designer): 이슈 #7의 답으로 확정본(탭 이름 "스킨", とりい 주황, えき 청록 유지, 무늬 스크립트, ゆ 그림 그대로, `skins.json` 자리, 홈은 원칙만).
- 2026-11-21 (designer, **색상 선택 개정**): 이슈 #7 추가 지시("스킨은 그냥 색상으로 선택하게, 배경은 어떻게 사용할지 생각해봐")로 다시 썼다. ① 스킨 = 색상(바탕색 + 강조색), 무늬·기리 뒤 그림을 스킨에서 뺌. ② 이름을 한국어 색 이름(기본·파랑·청록·주황·보라)으로, 스킨 id를 색 id로. ③ 강조색을 면 `AccentColor`와 글자·선 `AccentText`로 나눔, 주황 라이트 면을 밝은 주황 `#F57F20` + 진한 글자로. ④ 다크 강조색 채도를 올리고 다크 바탕·`Quiet`에 색 기운을 넣음. ⑤ 대비 예외 3곳의 값을 고쳐 예외 0(기본 라이트 `Quiet` `#FBF2E1`, 파랑 다크 `Quiet` `#131824`, 청록 다크 `Quiet` `#101A1B`). ⑥ K 스킨 탭을 색 견본 52pt 5열로, 잠긴 색도 색을 보여 줌. ⑦ `skins.json` schemaVersion 2 전체, 검사 스크립트 고칠 곳. ⑧ 배경 활용안 3개와 추천(안 1 꾸미기 배경), 기획 결정 필요 P1~P3. 무늬 규격(옛 6.2~6.4), 무늬 대비 계산, のれん·ゆ 그림 비교(옛 3.8)는 지웠다(git 기록에 있음).
