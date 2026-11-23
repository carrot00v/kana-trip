# 홈 바탕 고르기 (배경 안 3)

- 작성일: 2026-11-21 (designer)
- 상태: **확정 사양** (화면·그림·데이터). 기획 결정이 필요한 곳은 0.2에 모았고, 결정 전에는 0.2의 "결정 전 임시 동작"으로 구현한다
- 근거: 이슈 #7 사용자 답 "3안으로, 스킨, 그냥 다 열리게"(2026-11-21). PM 해석: 배경은 안 3(장면마다 넓은 풍경을 모아 홈 바탕으로 고름), 탭 이름은 "스킨" 그대로, 색 5개는 처음부터 모두 열림
- 기준 문서: [app-skin.md](app-skin.md)(색 스킨, 2.4 대비 기준, 5번 K 스킨 탭), [home-map.md](home-map.md) "2026-11-21 재구성안" 안 A와 끝의 "구현 메모", [visual-rules.md](visual-rules.md) 1.4·6.2·8.4, [scene-art/brief.md](scene-art/brief.md) 3·4·6번, [reward-flow.md](reward-flow.md) 3.2·3.5·6.2, `docs/content/reward-system.md` 2.3·7번, `PLAN.md` 3·4번, CLAUDE.md "그림 생성"
- 이 문서만 보고 (1) 풍경 8장 생성과 선별, (2) 홈 바탕 구현, (3) K에서 고르기를 할 수 있게 썼다. 색 전부 열기는 app-skin.md "2026-11-21 개정 2"

수치는 pt다(안드로이드는 같은 숫자를 dp로). 기준 화면은 402×874pt(iPhone 17), 함께 360·375·393·440pt 폭을 센다. 화면 기호는 app-skin.md와 같다(H 홈, K 기리 꾸미기, C2 장면 완료).

## 0. 요약

| 정한 것 | 값 | 절 |
|---|---|---|
| 무엇 | 장면마다 그 장소의 **바깥 풍경** 한 장(가로 2:1 띠). 끝낸 장면의 풍경 가운데 하나를 홈 바탕으로 고른다. 처음은 "없음"(지금 단색 바탕) | 1, 4 |
| 어디에 | H의 지도 뷰포트 **위 끝에 붙은 화면 폭 × 폭의 절반** 띠 하나. **스크롤해도 움직이지 않는다** | 2.1, 2.2 |
| 세기 | 라이트: 바탕색 위에 **곱하기**(multiply), 불투명도 약 0.28. 다크: **스크린**(screen), 불투명도 약 0.18(2026-11-23에 0.13에서 올림). 값은 도구가 그림마다 계산해 `backdrops.json`에 적는다. 흐림 없음 | 2.3 |
| 대비 | 풍경 위에 **글자를 바로 놓지 않는다.** 칸·말풍선은 제 면이, 면이 없는 것(띠 글자, 점선 점, 띠 그림, 표지 글자)은 2pt 바탕색 테가 풍경과 떼어 놓는다. 풍경 자체는 라이트 휘도 ≥ 0.55, 다크 ≤ 0.06 | 2.4 |
| 장면 그림과의 겹침 | 자리(위 띠 vs 스크롤되는 72pt), 세기(씻긴 판화 vs 원래 색), 테(띠 그림 밑 4pt 받침), 내용(바깥 장소 vs 대표 물건, 같은 대상 금지)으로 가른다 | 2.5 |
| 색 스킨과 | 바탕색은 그대로 보이고 풍경이 그 위에 찍힌다(곱하기·스크린이라 풍경이 없는 곳은 정확히 그 색). 한 그림이 5색 × 2모드에 맞게 불투명도를 정한다 | 2.6 |
| 다크 | **따로 그리지 않는다.** 같은 그림을 스크린으로 옅게 | 2.7 |
| 고르는 곳 | K "스킨" 탭 안, 색 줄 아래 "홈 바탕" 줄(없음 + 8칸, 3열, 아이템 칸 규격) | 4 |
| 얻는 법 (추천, 기획 결정) | 장면을 처음 끝내면 그 장면 풍경이 열린다. 값 없음, 자동으로 바꾸지 않음 | 3 |
| 저장 | `RewardState.backdrop` = 장면 id (없으면 없음) | 6.2 |
| 그림 | 히라가나 8장, 1280×640 생성, 장면당 후보 4장 | 7 |
| 연출 | 새로 더하지 않는다 | 5 |
| 규모 | 그림 약 3~4시간(생성 2시간 남짓 + 고르기), 코드 약 2~2.5일 | 9 |

### 0.1 장면 그림과 겹친다는 문제를 어떻게 풀었나

app-skin.md B1은 안 3을 "스크롤되는 칸 뒤 그림이라 덮개가 필요하고, 장면 띠 그림과 겹친다"고 적었다. 겹침은 두 가지였다.

| 겹침 | 해법 | 절 |
|---|---|---|
| **눈에 겹침**: 72pt 장면 그림(굵은 외곽선, 원래 색) 밑에 같은 화풍의 그림이 깔리면 그림 위 그림이 되고, 홈이 다시 "난잡"해진다(2026-11-18 피드백) | ① 풍경은 뷰포트 위쪽 띠(높이의 30~35%)에만 있고 가운데·아래는 비어 있다. ② 풍경은 씻긴 판화처럼 옅게(라이트 가장 진한 곳도 휘도 0.55 이상) 찍혀 원래 색의 장면 그림과 위계가 갈린다. ③ 장면 그림 밑에 바탕색 받침 4pt를 깔아 그림 가장자리가 풍경에 닿지 않는다(스티커의 크림 테와 같은 생각) | 2.2, 2.3, 2.4 |
| **뜻이 겹침**: 바탕이 스시집 풍경인데 띠는 돈카츠집이면 "지금 어디인가"가 흐려진다. 같은 물건(초밥, 도리이)이 두 번 나오면 같은 그림이 되풀이된다 | ④ 풍경은 그 장면의 **바깥 장소**(항구, 상점가, 신사 숲)이고, 장면 그림은 **대표 물건**(초밥, 가츠동, 도리이)이다. 풍경에 그 장면 그림의 대상을 넣지 않는다(7.4 검사 B4). ⑤ 바탕은 사용자가 고른 벽지라 지금 장면을 따라 바뀌지 않는다. "지금 어디"는 바 제목과 노랑 칸이 말한다 | 1.2, 7.3 |

home-map.md 6.2·6.3의 "장면 바탕 띠"(구간마다 한 장씩 스크롤되는 풍경, 2단계 계획)는 이 문서로 **대신한다.** 구간마다 풍경이 바뀌면 띠 그림과 뜻이 겹치고 장수도 10장이 든다.

### 0.2 기획 결정이 필요한 것 (직접 정하지 않았다)

| # | 무엇 | 선택지 | 추천 | 결정 전 임시 동작 |
|---|---|---|---|---|
| D1 | 풍경을 얻는 법 | **가.** 장면을 처음 끝내면 그 장면 풍경이 열림, 값 없음 / 나. 처음부터 8장 모두 열림("다 열리게"를 풍경에도 적용) / 다. 아이템처럼 300엔에 삼 | **가.** 장면을 끝낼 때마다 하나씩 모이는 것이 안 3의 재미이고(B1 "장면 수집"), 엔 경제(reward-system.md 2.2)를 건드리지 않는다. 사용자 답의 "다 열리게"를 PM은 색에 대한 것으로 읽었다. 풍경에도 해당하는 말이었다면 나 | 가 |
| D2 | 풍경이 열릴 때 바로 바꿀지 | **가.** 바꾸지 않음(지금 바탕 유지) / 나. 처음 열린 풍경만 자동으로 씀 / 다. 열릴 때마다 새 풍경으로 | **가.** 아이템도 "자동 착용 없음"(reward-system.md 2.4)이다. 사용자가 고른 바탕을 앱이 바꾸지 않는다 | 가 |
| D3 | C2에서 열린 풍경을 알릴지 | **가.** 열린 아이템 줄에 "홈 바탕" 묶음을 하나 더함 / 나. 알리지 않음(K에서만 보임) | **가.** 알리지 않으면 거의 찾지 못한다. 자리는 reward-flow.md 6.3의 "묶음 3개까지 한 줄" 안이라 세로 비용이 없다(5.2) | 가 |

색 아이템 4개와 300엔은 app-skin.md "2026-11-21 개정 2"의 Q1·Q2다.

## 1. 풍경이 무엇인가

### 1.1 정의

- 장면 하나에 풍경 하나. 그 장면에 가면 보이는 **바깥 장소의 넓은 모습**을 기리 화풍으로 그린 가로 띠다.
- 홈 바탕으로 한 번에 하나만 쓴다. 고르지 않으면(처음) 지금처럼 단색 바탕이다.
- 홈(H)에만 깔린다. K, S, 학습·퀴즈, 완료 화면에는 깔리지 않는다. 이름이 "홈 바탕"인 이유다.
- 대비 증가가 켜져 있으면 그리지 않는다(2.8).

### 1.2 장면 그림과 나눠 맡는 것

| | 장면 그림 (지금) | 풍경 (새로) |
|---|---|---|
| 보여 주는 것 | 그 장면의 **대표 물건** 하나 (초밥, 가츠동, 자루소바, 전철 정면, 도리이, 야키토리, 목욕통, 찻주전자) | 그 장면의 **바깥 장소** (항구, 상점가, 메밀밭 마을, 철길과 육교, 신사 숲, 식당 골목, 온천 마을, 료칸 정원) |
| 자리 | 장면 띠 왼쪽 72pt, 스크롤됨 | 뷰포트 위쪽 띠, 고정 |
| 세기 | 원래 색, 지금 장면은 `Outline` 2pt | 씻긴 판화(라이트 곱하기 약 0.28, 가장 진한 곳도 휘도 0.55 이상) |
| 바뀌는 때 | 장면 상태(잠김 흑백, 열림 컬러) | 사용자가 고를 때만 |
| 같은 대상 | – | **장면 그림의 대상을 넣지 않는다** (7.4 B4) |

## 2. 홈에 까는 방법

### 2.1 층 순서 (H, 아래에서 위)

| 층 | 무엇 | 스크롤 | 새로/지금 |
|---|---|---|---|
| 1 | 화면 바탕 `AppBackground` (스킨, `.skinBackground(.strong)`) | – | 지금 |
| 2 | **풍경 띠** (2.2) | **고정** | 새로 |
| 3 | **위 씻김**: 뷰포트 위 끝부터 16pt, `ground` 불투명 1 → 0 세로 그라데이션 | 고정 | 새로 |
| 4 | 지도 구간: 점선(+점 테), 세션 칸(+칸 테), 장면 띠(띠 그림 + 받침, 글자 + 글자 테, 스티커), 출발·끝 표지(+글자 테) | 스크롤 | 지금 + 테(2.4) |
| 5 | 기리 덮개 층: 기리, 말풍선(+말풍선 테) | 스크롤 | 지금 + 테 |
| 6 | 아래 씻김 16pt(`ground` 0 → 1)과 "지금 칸으로" 44pt 버튼 | 고정 | 지금 |
| 바깥 | 내비게이션 바(불투명 `ground`), 아래 고정 영역 72pt(불투명 `ground`) | – | 지금 그대로 |

`ground` = `MapPalette.ground`(저장된 스킨의 `AppBackground`, 다크 값 포함).

- 바와 아래 고정 영역은 지금처럼 불투명하게 둔다. 바 뒤로 풍경을 비치게 하면 제목 두 줄이 풍경 위 글자가 된다.
- 위 씻김(층 3)은 풍경이 바 아래 끝에서 칼로 자른 듯 끊기지 않게 한다. 아래 씻김(층 6)과 같은 값이다. 풍경을 쓰지 않을 때도 그려도 된다(바탕과 같은 색이라 보이지 않는다).

### 2.2 풍경 띠의 자리와 크기

- **틀**: 지도 뷰포트(바 아래 끝 ~ 아래 고정 영역 위 끝, `MapView`의 `GeometryReader` 크기)의 위 끝에 붙인다. 폭 = 뷰포트 폭 W, 높이 = **W × 0.5**(그림 비율 2:1 그대로). 가로로 자르지 않고, 세로로 늘이지 않는다(`resizable().aspectRatio(2, contentMode: .fit)`, 위 정렬).
- **스크롤**: 고정. 지도가 스크롤돼도 풍경은 같은 자리에 있고 칸·띠가 그 위로 지나간다.
  - 고정으로 한 이유: 지도는 9,000pt가 넘어 한 장으로 덮을 수 없고, 구간마다 그리면 장면 그림과 뜻이 겹친다(0.1). 시차 스크롤은 스크롤에 붙은 움직임이 하나 더 생기고(visual-rules.md 6.2 "반복 움직임 하나") 동작 줄이기 대응이 따로 든다.
- **뷰포트 아래 나머지**: 풍경이 없다. 바탕색 그대로다. 지금 칸이 쉬는 자리(뷰포트 70%)와 기리·말풍선은 늘 이 빈 곳에 있다.

| 화면 (pt) | 바 아래 끝 y | 아래 고정 위 끝 y | 뷰포트 높이 | 풍경 띠 (W × W/2) | 띠 / 뷰포트 | 쉼 자리 y (70%) |
|---|---|---|---|---|---|---|
| 402×874 | 106 | 768 | 662 | 402 × 201 (y 106~307) | 30% | 569 |
| 393×852 | 103 | 746 | 643 | 393 × 196.5 | 31% | 553 |
| 440×956 | 106 | 850 | 744 | 440 × 220 | 30% | 627 |
| 375×667 | 64 | 595 | 531 | 375 × 187.5 (y 64~251.5) | 35% | 436 |
| 360dp 폭 | (기기마다) | | | 360 × 180 | | |

- 띠 아래쪽 30%(402에서 y 247~307)는 도구가 미리 알파를 1 → 0으로 줄여 구워 두었다(7.5). 그래서 풍경은 아래로 부드럽게 사라지고 뷰포트 가운데로 선이 생기지 않는다.
- 띠 위쪽 8%(402에서 16pt)는 그림에서 비어 있다(하늘 자리, 7.3 구도). 위 씻김 16pt와 겹쳐 바 아래가 깨끗하다.
- 큰 글자 크기(`accessibility1` 이상)에서도 같다. 말풍선이 아래 고정 영역 카드로 옮겨 가는 것과 상관없다.

### 2.3 씻김(스크림)과 흐림

| 값 | 라이트 | 다크 |
|---|---|---|
| 섞는 법 | **곱하기** (`.blendMode(.multiply)`) | **스크린** (`.blendMode(.screen)`) |
| 식 (sRGB 부호화 값 0~1, 채널마다. B = 바탕색, A = 그림 색, a = 그림 알파, o = 불투명도) | C = B × (1 − o·a·(1 − A)) | C = B + o·a·A·(1 − B) |
| 불투명도 o | `backdrops.json`의 `opacity.light` (도구가 계산, 예상 0.25~0.40) | `opacity.dark` (도구가 계산, 지금 0.17~0.19) |
| 계산 조건 (5색 모두) | 합성 결과의 상대 휘도 **0.1백분위 ≥ 0.55** | 합성 결과의 상대 휘도 **99.9백분위 ≤ 0.06** (2026-11-23, 0.045에서 올림. 2.7) |
| 상한 (조용함) | o ≤ 0.40 | o ≤ 0.25 |
| 하한 (합격 조건, 7.4 N7) | o ≥ 0.20. 밑이면 그 후보를 버린다(너무 진하거나 외곽선이 굵다) | o ≥ 0.06 |
| 흐림 | 없음 (단색 면 그림이라 흐리면 탁해진다) | 없음 |
| 띠 아래 30% 알파 줄임 | 그림에 구움 (7.5) | 같음 |
| 위 씻김 / 아래 씻김 | 16pt / 16pt (2.1) | 같음 |

- 곱하기와 스크린을 고른 이유: 그림의 투명한 곳(하늘, 뷰포트 아래)은 **바탕색이 정확히 그대로** 남는다. 보통 섞기(opacity)로 하면 그림의 색이 화면 전체 바탕을 물들여 색 스킨이 탁해진다. 라이트는 곱하기라 풍경이 바탕색 종이에 찍힌 판화처럼 보이고, 다크는 스크린이라 어두운 바탕 위에 풍경의 밝은 면만 은은하게 떠오른다(외곽선은 거의 보이지 않는다).
- 구현: `ZStack { 바탕색; 풍경 Image.blendMode(…).opacity(o) }.compositingGroup()`으로 묶어 이 둘끼리만 섞이게 한다. 지도 내용은 보통으로 위에 얹는다.
- **식 맞추기**: 개발자는 기본 색 라이트·다크에서 시뮬레이터 화면의 풍경 픽셀 몇 개를 위 식과 비교한다(차이 3/255 이하). 다르면(합성이 선형 공간에서 일어나는 등) 검사 도구의 식을 앱에 맞추고 불투명도를 다시 계산한다.
- 0.55의 뜻: 가장 진한 풍경 선도 회색으로 치면 `#C4C4C4` 정도다. 색 스킨의 점선 색 `PathEdge`(휘도 0.55~0.69)보다 진해지지 않게 잡았다. 점선보다 풍경이 눈에 먼저 들어오면 위계가 뒤집힌다(home-map.md 2026-11-18 진단).
- 0.06의 뜻: 다크 바탕(휘도 0.009~0.014)보다 조금 밝고, 다크 `PathEdge`(0.047~0.061) 언저리다. 2.4대로 지도 요소가 풍경에 직접 닿지 않으므로 대비 기준이 아니라 눈부심·조용함의 기준이다. 처음 값 0.045에서는 다크에서 풍경이 거의 보이지 않아(구현 메모) 2.7의 상한 0.06까지 올렸다.
- 예상 값은 손 계산이다. 라이트: 그림의 가장 진한 픽셀을 휘도 0.18로 들어 올린 뒤(7.5) 기본 색에서 o ≈ 0.37, 가장 어두운 바탕인 보라에서 o ≈ 0.28이라 한 값은 약 0.28이다. 다크: 흰 면이 가장 밝은 바탕인 청록을 묶어 o ≈ 0.13. 최종 값은 도구가 낸다.

### 2.4 대비: 풍경 위에 글자를 바로 놓지 않는다

**규칙**: 지도 요소는 풍경에 직접 닿지 않는다. 면이 있는 요소는 그 면이, 면이 없는 요소는 바탕색(`ground`) 테가 풍경과 떼어 놓는다. 그래서 모든 글자와 상태 표시의 대비는 **지금 바탕 위의 대비 그대로**다(visual-rules.md 1.4: 글자 4.5:1, 글자 아닌 표시 3:1, app-skin.md 2.4).

| 요소 | 지금 | 풍경 위에서 떼어 놓는 것 | 값 |
|---|---|---|---|
| 세션 칸 (지금·완료·잠김) | 면 있음(`Highlight` / `CardBackground` / `ground`) | 면 + **칸 테** | 칸 모양을 사방 2pt 키운 캡슐(402에서 156×56, 모서리 28)을 `ground`로 칠해 칸 밑에 깐다. 완료 칸 테(`InkSecondary` 1.5pt)와 잠김 칸 테(`PathEdge`)가 바탕색과 맞닿는다 |
| 말풍선 (몸통 + 꼬리) | `CardBackground` + `Outline` 2pt | 면 + **말풍선 테** | 같은 모양을 바깥으로 2pt 넓혀 `ground`로 밑에 깐다(같은 Path를 `stroke(ground, lineWidth: 외곽선 2 + 4)`) |
| 장면 띠 그림 72pt | 그림 자체 바탕(SKY·SAND), 지금 장면만 `Outline` 2pt | **받침** | 그림 밑에 80×80pt `ground` 둥근 사각(모서리 16, 그림과 가운데 맞춤). 그림 둘레 4pt |
| 장면 띠 글자 2줄 (이름 `.headline`, 가나 17pt `InkSecondary`), 상태 아이콘 | 면 없음 | **글자 테** | 같은 글자를 `ground` 색으로 8방향(가로·세로 ±2pt, 대각 ±1.4pt)에 밀어 그린 뒤 그 위에 원래 글자. 아이콘(`checkmark.circle.fill`, `lock.fill`)도 같게 |
| 출발·끝 표지 글자 (`.footnote` 굵게 `InkSecondary`) | 면 없음 | 글자 테 | 위와 같음 |
| 점선 점 (지름 4, `PathEdge`) | 면 없음 | **점 테** | 점 밑에 지름 8 `ground` 원 |
| 스티커 48pt | 크림 테 3pt + 25% 선 | 없음 (이미 테가 있음) | – |
| 기리 72pt | 흰 몸 + 진갈색 외곽선 | 없음 | 외곽선 `#4A2219`(휘도 0.025)와 풍경(≥ 0.55)의 대비 7 이상. 다크는 흰 몸이 스스로 떼어 놓는다 |
| "지금 칸으로" 44pt | `ground` 원 위 12% 강조색 | 없음 (이미 바탕색 면) | – |
| 바, 아래 고정 영역 | 불투명 `ground` | 없음 | – |

- 테는 **풍경을 쓰는 동안에만** 그린다(권장). 풍경이 없으면 테가 바탕과 같은 색이라 보이지 않지만, 그리지 않으면 지금 화면과 픽셀 단위로 같음을 보장할 수 있다.
- 테는 굵은 외곽선이 아니다. 바탕색이라 테두리로 보이지 않고 풍경 쪽에서 "비켜 난 자리"로 보인다. 한 화면 예산(home-map.md R2.3: 요소 종류 11, `Outline` 2pt 2개, 노랑 면 1, 진한 면 1)은 바뀌지 않는다.
- 연출 중 기리가 띠 위를 지나갈 때(0.3초)와 말풍선이 점선 몇 개를 덮는 것(home-map.md 구현 메모)은 지금과 같다.
- 나중에 지도에 요소를 더할 때도 이 규칙을 따른다: 면이 없는 글자·선을 풍경 자리에 놓으려면 글자 테를 준다.

**대비 계산 확인** (기준 수치):

| 조합 | 값 | 기준 | 비고 |
|---|---|---|---|
| 글자·아이콘 / `ground` (테 안) | 지금과 같음 (`InkSecondary` / 바탕 5.4 이상, app-skin.md 3.5) | 4.5 / 3 | 테가 글자 둘레를 바탕으로 만든다 |
| 기리 외곽선 `#4A2219` / 풍경 최저 0.55 | (0.55 + 0.05) / (0.025 + 0.05) = 8.0 | 3 | 라이트 |
| 다크 `Outline` `#8C7366`(0.188) / 풍경 최고 0.06 | 2.2 | (적용 안 함) | 말풍선은 테가 있어 풍경에 닿지 않는다. 테 없이 닿는 다크 `Outline`은 없다 |
| 풍경 최저 / 최고 (라이트 / 다크) | ≥ 0.55 / ≤ 0.06 | 2.3 | 도구가 5색 × 2모드로 검사 (6.4) |

### 2.5 장면 띠 그림과 겹쳐 보이지 않게 (0.1의 해법을 구현으로)

1. 자리: 풍경은 뷰포트 위 30~35%에만 있다. 장면 띠가 위쪽에 올 때(A-1, A-3 상태, home-map.md R2.2)만 띠 그림과 풍경이 같은 높이에 온다.
2. 받침: 그때 띠 그림 둘레 4pt가 바탕색이라 그림 가장자리가 풍경 선과 이어지지 않는다(2.4).
3. 세기: 풍경 선은 휘도 0.55 이상(옅은 회갈색), 장면 그림 외곽선은 `#4A2219` 원래 굵기와 색이다. 크기도 풍경 선이 가늘다(그림 폭의 약 0.5%, 7.2 → 402pt에서 약 2pt, 씻겨서 더 가늘게 보임).
4. 내용: 풍경에 장면 그림의 대상(1.2 표)을 넣지 않는다. 고를 때 검사한다(7.4 B4).
5. 잠긴 장면 띠의 그림은 흑백이다. 풍경은 늘 바탕색 판화라 흑백 그림과 섞여 "잠긴 그림"처럼 보이지 않는지 7.4 N8 스크린샷에서 본다.

### 2.6 색 스킨과 함께 쓸 때

- 풍경이 없는 곳은 그 색의 `AppBackground` 그대로다(곱하기의 흰색, 스크린의 검정은 바탕을 바꾸지 않는다. 그림의 투명한 곳도 같다).
- 풍경은 그 색 위에 찍혀 색을 띤다. 라이트 파랑이면 풍경이 푸른 종이에 찍힌 판화, 주황이면 주황 종이에 찍힌 판화가 된다. 풍경마다 따로 그리지 않는다.
- 불투명도는 그림 하나에 모드마다 한 값이고, **5색 모두에서** 2.3의 조건을 넘는 값 가운데 가장 큰 값이다(가장 어두운 라이트 바탕인 보라 `#ECE6F2`·파랑 `#E3E9F4`, 가장 밝은 다크 바탕인 청록 `#0E2224`가 값을 정한다).
- 색을 바꿀 때 K의 0.3초 교차 페이드는 K 화면에서만 일어난다. 홈은 K에서 돌아올 때 이미 새 색이다(지금과 같음).
- 대비 증가에서는 풍경을 그리지 않는다(2.8). 색을 늘리면(app-skin.md 3.6) 그 색으로 도구를 다시 돌려 불투명도를 다시 계산한다.

### 2.7 다크 모드: 따로 그리지 않는다

- 같은 그림 한 장을 다크에서는 스크린 섞기, 낮은 불투명도로 쓴다(2.3).
- 따로 그리지 않는 이유: 다크 바탕은 휘도 0.029 아래로 묶여 있어(app-skin.md 2.3) 밤 풍경을 따로 그려도 휘도 0.06 안에서는 거의 같은 모습이 된다. 장수가 두 배가 되고 낮·밤 두 장의 구도를 맞추는 일이 생긴다. 그림 속 밝은 면(하늘색 물, 흰 벽, 김)만 은은하게 떠오르는 모습이 밤 느낌을 낸다.
- 스크린 섞기에서 진갈색 외곽선은 거의 더해지지 않아 보이지 않는다. 면이 외곽선 자리에서 끊겨 보이는 것은 의도한 모습이다.
- 다크 상한은 2026-11-23에 0.045에서 0.06으로 올렸다(이슈 #7 저장소 주인 결정 "다크 바탕을 더 진하게"). 0.06이 이 절에서 허용한 끝이다. 더 올리려면 다크 `PathEdge`(0.047~0.061)보다 풍경이 밝아져 점선과 위계가 뒤집히므로 designer 판단이 필요하다. 근거와 결과는 구현 메모 "다크 바탕 진하게".

### 2.8 접근성 설정

| 설정 | 홈 바탕 |
|---|---|
| 대비 증가 | **그리지 않는다.** 바탕은 `AppBackgroundQuiet`(app-skin.md 2.5), 테도 그리지 않는다. K의 고르기는 그대로 되고, 안내 줄이 알린다(4.4) |
| 동작 줄이기 | 바꿀 것 없음 (풍경은 움직이지 않는다) |
| 투명도 줄이기 | 바꿀 것 없음 (반투명 판·흐림이 없다) |
| 다크 | 2.7 |
| VoiceOver | 풍경은 읽지 않는다(`accessibilityHidden(true)`). 지도 레이블은 지금 그대로 |
| 큰 글자 크기 | 바꿀 것 없음 |

## 3. 얻는 방법 (D1·D2 추천안 기준)

| 항목 | 규칙 |
|---|---|
| 열림 | 장면 X의 풍경은 X의 종합 퀴즈를 처음 통과하면 열린다. 판단은 `rewards.paid`에 `"{X}-quiz"`가 있는지(저장하지 않고 계산). `paid`는 진도 초기화에도 남는다(reward-system.md 6.3) |
| 값 | 없음. 엔을 쓰지 않는다 |
| 처음 상태 | "없음" = 지금의 단색 바탕. 앱을 새로 깐 사람, 아무 장면도 끝내지 않은 사람 모두 |
| 열릴 때 | 바탕을 바꾸지 않는다(D2 가). C2가 알린다(D3 가, 5.2) |
| 되돌리기 | K에서 다른 풍경이나 "없음"을 누르면 바로 바뀐다. 확인 창 없음(되돌릴 수 있는 조작, reward-flow.md 3.7의 "바꾸기"와 같음) |
| "기본 차림으로" | 건드리지 않는다(스킨과 같은 이유, app-skin.md 5.5) |
| 가타카나 | 장면이 정해지면 같은 규칙으로 8장 더. K 칸이 3행 늘어난다 |

## 4. 고르는 곳: K "스킨" 탭의 "홈 바탕" 줄

### 4.1 탭 안의 배치 (위에서 아래, 격자 영역 안, 함께 스크롤)

reward-flow.md 3.2 표의 9번 "아이템 격자" 자리에 스킨 탭일 때 아래가 들어간다. 미리보기 카드, 안내 줄, 슬롯 탭은 그대로다.

```
 ┌───────────────── W ─────────────────┐
 │ 앱 색                                │  섹션 머리 18 (+ 아래 8)
 │  ╭─╮    ╭─╮    ╭─╮    ╭─╮    ╭─╮     │
 │ ( ✓ )  (   )  (   )  (   )  (   )    │  색 견본 52pt, 칸 높이 90 (app-skin.md 5.2)
 │  기본   파랑   청록   주황   보라     │
 │                                      │  간격 20
 │ 홈 바탕                              │  섹션 머리 18 (+ 아래 8)
 │ ┌────────┐ ┌────────┐ ┌────────┐     │
 │ │   ⊘    │ │▁▂▃▂▁▂▃│ │▁▃▂▁▂▃▁│     │  칸 126 (reward-flow.md 3.5 규격)
 │ │  없음  │ │ 스시집 │ │돈카츠집│     │  썸네일 100×50
 │ │✓쓰는 중│ │        │ │🔒 잠김 │     │
 │ └────────┘ └────────┘ └────────┘     │
 │ ┌────────┐ ┌────────┐ ┌────────┐     │  (스크롤)
 │   … 소바·우동집, 역, 신사·축제 …     │
 │   … 이자카야, 온천, 료칸 …           │
 └──────────────────────────────────────┘
```

| 순서 | 요소 | 값 |
|---|---|---|
| 1 | 위 여백 | 12 |
| 2 | 섹션 머리 "앱 색" | `.footnote.weight(.semibold)`, `InkSecondary`, 왼쪽 여백 16, 높이 18, `.isHeader` |
| 3 | 간격 | 8 |
| 4 | 색 견본 줄 | app-skin.md 5.2 (5열, 칸 높이 90) |
| 5 | 간격 | 20 |
| 6 | 섹션 머리 "홈 바탕" | 2와 같음 |
| 7 | 간격 | 8 |
| 8 | 홈 바탕 격자 | `LazyVGrid` **3열** `.flexible()`, 열·행 사이 8, 좌우 여백 16. 칸 순서: 없음, 장면 순서대로 8칸. 칸은 4.2 |
| 9 | 아래 여백 | 8 |

세로 계산 (스크롤 내용 전체 = 12 + 26 + 90 + 20 + 26 + (126 × 3 + 8 × 2) + 8 = **576pt**):

| 화면 | 격자 영역 높이 (reward-flow.md 3.4) | 처음에 보이는 것 |
|---|---|---|
| 402×874 | 340 (y 492~832) | 색 줄 전부 + "홈 바탕" 첫 행(없음, 스시집, 돈카츠집) 전부 + 둘째 행 위 32pt |
| 375×667 | 269 | 색 줄 전부 + 첫 행 위 95pt (칸 이름 줄까지 보임) |

- 스킨 탭을 고르면 스크롤은 맨 위에서 시작한다.
- 접근성 크기(`accessibility1` 이상): 색 견본 3열(app-skin.md 5.2), 홈 바탕 2열(reward-flow.md의 접근성 격자와 같음).
- 탭을 하나 더 만들지 않은 이유: 꾸미기 탭은 4개로 정해져 있고(PLAN.md 3번), 색과 바탕은 둘 다 "앱이 입는 것"이라 "스킨" 한 탭에 묶인다. 색 줄이 한 줄이라 바탕 줄이 첫 화면 안에 들어온다.

### 4.2 홈 바탕 칸

규격은 reward-flow.md 3.5의 아이템 칸(폭 = 열 폭, 높이 126, `CardBackground`, 모서리 12, `Outline` 2pt, 칸 전체가 `Button(.plain)`)을 그대로 쓰고, 썸네일과 이름 줄만 다르다.

| 위에서 아래 | 높이 | 내용 |
|---|---|---|
| 위 안쪽 여백 | 6 | |
| 썸네일 자리 | 60 | 가운데에 **썸네일 100×50** (`BackdropThumb-{id}`, 풍경 띠 전체를 줄인 것, 모서리 8, 안쪽 테 1pt `Ink` 15%). 칸 바탕 위에 바로(그림의 투명한 하늘은 `CardBackground`로 보임). 칸 폭 375에서 109, 402에서 118이라 들어간다 |
| 간격 | 4 | |
| 발음 표기 줄 | 12 | 비움 (가나 이름이 없다) |
| 이름 줄 | 20 | 장면 이름 한국어(`scene.name`: 스시집, 돈카츠집, 소바·우동집, 역, 신사·축제, 이자카야, 온천, 료칸), `.subheadline`(15pt), `lineLimit(1)`, `minimumScaleFactor(0.8)` |
| 간격 | 2 | |
| 상태 줄 | 16 | 아래 표 |
| 아래 안쪽 여백 | 6 | |

| 상태 | 조건 | 썸네일 | 이름 | 상태 줄 | 외곽선·표시 | 색 밖의 표시 |
|---|---|---|---|---|---|---|
| 쓰는 중 | `rewards.backdrop` = 이 장면 | 원래 색 | `Ink` | `checkmark` + "쓰는 중" (`Ink`) | `AccentText` 3pt + 오른쪽 위 `checkmark.circle.fill` 20pt 배지(reward-flow.md 3.5 쓰는 중과 같음) | 굵은 외곽선, 체크 배지, "쓰는 중" |
| 열림 | 그 장면을 끝냄, 쓰지 않음 | 원래 색 | `Ink` | 비움 | `Outline` 2pt | (상태 줄이 빔) |
| 잠김 | 그 장면을 아직 끝내지 않음 | **채도 0**(`.saturation(0)`, 홈의 잠긴 띠 그림과 같음). 불투명도는 낮추지 않는다 | `InkSecondary` | `lock.fill` + "잠김" (`InkSecondary`) | `Outline` 2pt | 흑백, 자물쇠, "잠김" |
| 없음 칸 | 늘 | `circle.slash` 28pt `InkSecondary` | "없음" | `rewards.backdrop`이 없으면 "쓰는 중" 모양(외곽선 3pt, 배지 포함), 아니면 비움 | | |

- 잠긴 풍경도 그림을 보여 준다. 풍경에는 글자가 없고, 장면 이름은 홈 지도에 이미 다 보인다. 갖고 싶은 풍경이 보이는 것이 장면을 끝낼 이유가 된다(app-skin.md 5.2의 잠긴 색과 같은 이유).
- 엔 표시, 확인 창, 미리 보는 중 점선은 없다(값이 없다).

### 4.3 누를 때

| 누른 칸 | 저장 | K 화면 | 안내 줄 (1줄 / 2줄) | 햅틱 |
|---|---|---|---|---|
| 열림 | `rewards.backdrop` = 장면 id | 칸 표시만 바뀜(외곽선·배지 0.15초). K 바탕은 바뀌지 않는다 | {장면} 바탕 / 홈 바탕을 바꿨어요 | `.impact(weight: .light)` |
| 쓰는 중 | 없음 | 그대로 | {장면} 바탕 / 홈 바탕으로 쓰고 있어요 | 없음 |
| 없음 (쓰는 풍경이 있을 때) | `rewards.backdrop` 삭제 | 칸 표시만 | 없음 / 홈 바탕을 비웠어요 | `.impact(weight: .light)` |
| 없음 (이미 없음) | 없음 | 그대로 | 없음 / 홈 바탕을 쓰지 않고 있어요 | 없음 |
| 잠김 | 없음 | 그대로 | {장면} 바탕 / {장면} 장면을 끝내면 열려요 | 없음 |
| 열림 + 대비 증가가 켜져 있음 | 위 "열림"과 같음 | 같음 | {장면} 바탕 / 대비 증가를 켜 두면 홈 바탕이 보이지 않아요 | `.impact(weight: .light)` |

- **K 화면에는 풍경을 깔지 않는다.** K는 미리보기 카드, 안내 줄, 탭, 격자가 화면을 다 쓰고, 격자 칸 사이로 풍경이 비치면 칸이 읽히지 않는다. 미리 보기는 썸네일이 맡고, 바로 적용되며 언제든 되돌릴 수 있다. 홈에 돌아가면 보인다.
- 색 견본과 홈 바탕은 서로 따로다. 색을 누르면 K 전체가 그 색으로 바뀌고(app-skin.md 5.3) 홈 바탕 썸네일은 바뀌지 않는다(썸네일은 `CardBackground` 위 그림이다).
- 안내 줄의 "처음" 문구(스킨 탭을 처음 고를 때)는 색 기준 그대로다(app-skin.md 5.3).

### 4.4 VoiceOver

- 섹션 머리 "앱 색", "홈 바탕"은 `.isHeader`.
- 홈 바탕 칸 하나가 한 요소. 레이블 "{장면} 바탕"(없음 칸은 "홈 바탕 없음"). 값: "쓰는 중" / 없음 / "잠김, {장면} 장면을 끝내면 열려요". 쓰는 중 칸은 `.isSelected`.
- 안내 줄이 바뀌면 2줄 문구를 알림으로 읽는다(지금 규칙).
- 썸네일은 읽지 않는다.

## 5. 완료 순간과 연출

### 5.1 연출

새로 더하는 움직임은 없다(visual-rules.md 6.2: C2의 리워드 줄에는 움직임이 없다). 풍경은 열려도 바탕이 바뀌지 않으므로(D2) 홈에서도 일어나는 일이 없다. K에서 고른 뒤 홈으로 돌아오면 내비게이션 뒤로 가기 전환 안에서 이미 새 바탕이다.

### 5.2 C2 열린 아이템 줄 (D3 가)

reward-flow.md 6.2의 6 "열린 아이템 줄"에 묶음 하나를 **맨 끝에** 더한다.

| 요소 | 값 |
|---|---|
| 줄 머리 | "새 아이템 {n}개와 홈 바탕이 열렸어요" (`.subheadline`, `InkSecondary`). 아이템이 0개면 "홈 바탕이 열렸어요" |
| 묶음 | [썸네일 칸 **88×44** (`CardBackground`, 모서리 10, `Outline` 2pt, 안에 `BackdropThumb-{id}` 84×42) / 간격 2 / 발음 표기 줄 12 비움 / 이름 "홈 바탕" 15pt 20]. 높이는 다른 묶음과 같은 78 |
| 폭 확인 | 아이템 2 + 바탕 1: 약 64 + 16 + 64 + 16 + 88 = 248pt (375pt 내용 폭 343 안). reward-flow.md 6.3의 "3개까지 한 줄" 안 |
| 세로 | 줄 수가 같아 6.4의 세로 계산은 바뀌지 않는다 |
| 누름 | 없음 (지금 묶음과 같음) |
| VoiceOver | "{장면} 홈 바탕" |
| "기리 꾸미기" 글자 버튼 | 지금 조건(살 것이 있거나 이번에 받음)에 **"홈 바탕이 열림"을 더한다** |

## 6. 데이터와 구현

### 6.1 데이터 파일 `KanaTrip/Resources/backdrops.json`

iOS는 번들에서, 안드로이드는 같은 파일을 `assets/`로 복사해 읽는다. `opacity`는 도구가 쓴다(7.5). 손으로 쓰는 값은 `layout`과 `limits`뿐이다.

```json
{
  "schemaVersion": 1,
  "_comment": "홈 바탕 (docs/design/home-backdrop.md). 순서 = 장면 순서 = K 칸 순서. 에셋은 Backdrop-{id}, BackdropThumb-{id}. opacity는 tools/make_backdrop_art.py가 계산해 쓴다.",
  "layout": {
    "stripAspect": 2.0,
    "fadeTop": 16,
    "haloWidth": 2,
    "artMatInset": 4,
    "artMatCorner": 16,
    "dotHaloDiameter": 8
  },
  "blend": { "light": "multiply", "dark": "screen" },
  "limits": {
    "lightMinLuminance": 0.55, "lightPercentile": 0.1,
    "darkMaxLuminance": 0.06, "darkPercentile": 99.9,
    "lightOpacity": { "min": 0.20, "max": 0.40 },
    "darkOpacity":  { "min": 0.06, "max": 0.25 }
  },
  "backdrops": [
    { "id": "sushi",    "sceneID": "sushi",    "opacity": { "light": 0.0, "dark": 0.0 } },
    { "id": "tonkatsu", "sceneID": "tonkatsu", "opacity": { "light": 0.0, "dark": 0.0 } },
    { "id": "soba",     "sceneID": "soba",     "opacity": { "light": 0.0, "dark": 0.0 } },
    { "id": "station",  "sceneID": "station",  "opacity": { "light": 0.0, "dark": 0.0 } },
    { "id": "shrine",   "sceneID": "shrine",   "opacity": { "light": 0.0, "dark": 0.0 } },
    { "id": "izakaya",  "sceneID": "izakaya",  "opacity": { "light": 0.0, "dark": 0.0 } },
    { "id": "onsen",    "sceneID": "onsen",    "opacity": { "light": 0.0, "dark": 0.0 } },
    { "id": "ryokan",   "sceneID": "ryokan",   "opacity": { "light": 0.0, "dark": 0.0 } }
  ]
}
```

읽기 규칙:

- 버전 1만 읽는다. 다르면 파일 전체를 버리고 풍경 없음으로 그린다.
- `opacity`가 0이거나 에셋이 없는 항목은 **칸을 만들지 않는다**(그림이 아직 없는 장면). 그래서 그림이 한 장씩 들어와도 코드를 고치지 않는다. 그림이 하나도 없으면 "홈 바탕" 섹션 머리와 격자를 숨긴다.
- 이름은 장면 데이터의 `name`을 쓴다(파일에 이름을 두지 않는다).
- 모르는 키는 무시한다.

### 6.2 저장

| 키 | 값 | 없을 때 |
|---|---|---|
| `RewardState.backdrop` (JSON `"backdrop"`) | 풍경 id(= 장면 id) | 없음 |

- `decodeIfPresent`로 읽는다(reward-system.md 7번의 호환 규칙). 저장 버전은 올리지 않는다.
- `equipped`에 두지 않는 이유: `equipped`는 리워드 아이템의 슬롯이고 `RewardRules.sanitized`가 아이템 목록에 없는 id를 지운다. 풍경은 아이템이 아니다. 색도 같은 이유로 `RewardState.skin`으로 옮긴다(app-skin.md 개정 2의 저장).
- 읽은 값이 `backdrops.json`에 없거나 아직 열리지 않은 장면이면 **지우지 않고** 없음으로 그린다(데이터가 다시 들어오면 살아난다).
- "기본 차림으로"(`RewardRules.resetOutfit`)는 건드리지 않는다.
- 홈은 저장된 값만 읽는다(K에 미리 보기가 없어 환경값이 필요 없다). 색처럼 `SkinStore`에 `backdrop`을 두어 홈이 `Observation`으로 다시 그려지게 하면 된다.

### 6.3 고칠 곳

| 파일 | 할 일 |
|---|---|
| `KanaTrip/Resources/backdrops.json` | 6.1 (새) |
| `KanaTrip/Rewards/RewardModel.swift` | `RewardState.backdrop: String?` (`decodeIfPresent`) |
| `KanaTrip/Skin/` 새 파일 `BackdropModel.swift` | `backdrops.json` 읽기, 열림 판단(`paid`), 지금 풍경(`SkinStore`에 `backdrop` 계산 속성) |
| `KanaTrip/Home/Map/MapView.swift` | `.background(MapPalette.groundLayer)` 자리에 바탕색 + 풍경 띠(2.2, 2.3) + 위 씻김(2.1)을 `compositingGroup`으로. 대비 증가면 풍경 없음 |
| `KanaTrip/Home/Map/MapSectionView.swift` | 칸 테, 띠 그림 받침, 띠 글자 테, 점 테, 표지 글자 테 (2.4). 풍경이 있을 때만 |
| `KanaTrip/Home/Map/MapGiriLayer.swift` | 말풍선 테 (2.4) |
| `KanaTrip/Home/Map/MapStyle.swift` | `MapPalette`에 `backdrop`(지금 풍경 또는 nil), `MapShape`에 테 값(`layout`에서 읽어도 됨) |
| `KanaTrip/Rewards/CustomizeView.swift` | 스킨 탭 격자를 두 섹션으로(4.1), 홈 바탕 칸(4.2), 누름(4.3), VoiceOver(4.4) |
| `KanaTrip/Session/CompletionViews.swift` | C2 열린 아이템 줄의 홈 바탕 묶음, 줄 머리 문구, 글자 버튼 조건 (5.2) |
| `KanaTrip/App/Strings.swift` | 4.3, 4.4, 5.2 문구 |
| `Assets.xcassets` | Image Set `Backdrop-{id}`(@2x 880×440, @3x 1320×660), `BackdropThumb-{id}`(@2x 200×100, @3x 300×150). Render As Original |
| `tools/make_backdrop_art.py` (새, 파이썬 + Pillow) | 7.5 |
| DEBUG | `-backdropDebug <id>`: 저장과 상관없이 그 풍경을 홈에 깐다(열림 판단 무시). `-mapDebugCompleted`와 함께 쓴다 |

### 6.4 검사

`tools/make_backdrop_art.py verify`가 `backdrops.json`, `skins.json`, 에셋의 띠 PNG(@3x)를 읽어 풍경 × 5색 × {라이트, 다크}마다 2.3의 식으로 합성하고 아래를 검사한다. 하나라도 못 넘으면 0이 아닌 값으로 끝난다.

| # | 검사 | 기준 |
|---|---|---|
| V1 | 라이트 합성 휘도의 0.1백분위 (알파 > 0인 픽셀) | ≥ 0.55 |
| V2 | 다크 합성 휘도의 99.9백분위 | ≤ 0.06 |
| V3 | `opacity`가 `limits` 안 | 2.3 표 |
| V4 | 합성 색의 HSV 색상 125°~160°(채도 25% 이상) 또는 330°~359° 픽셀 비율 (app-skin.md 2.4의 9번을 바탕 픽셀에) | 각각 1% 이하 |
| V5 | 띠 PNG 크기 1320×660, 아래 30%의 알파가 줄어들어 맨 아래 줄 알파 0 | |
| V6 | 썸네일 PNG가 있음 | |

`make_backdrop_art.py --markdown`은 결과 표를 낸다. 개발자는 구현 뒤 이 문서 맨 끝에 붙인다.

### 6.5 구현 순서

| 순서 | 할 일 | 끝난 상태의 기준 |
|---|---|---|
| 1 | 그림 8장 생성·선별(7번, designer) | `docs/design/backdrop-art/source/backdrop-{id}.png`·`.json` 8쌍 |
| 2 | `make_backdrop_art.py build` + `verify` | `backdrops.json`의 `opacity` 채움, verify 실패 0 |
| 3 | 저장·모델·홈 층 | 기본 색 라이트·다크에서 2.3 식과 화면 픽셀 차이 3/255 이하. **풍경이 없을 때 홈이 지금과 픽셀 단위로 같음** |
| 4 | 테(2.4) | 6.6 스크린샷에서 글자·점선이 풍경에 닿는 곳이 없음 |
| 5 | K 두 섹션, C2 묶음 | 4.3 표의 모든 갈래 동작 |
| 6 | 6.6 스크린샷 | 목록이 다 있음 |

그림이 늦으면 2~6은 그림 1장(아무 후보)으로 먼저 해도 된다. 그림이 하나도 없으면 홈 바탕 섹션이 숨겨져(6.1) 지금 화면과 같다.

### 6.6 확인할 화면 (스크린샷)

시뮬레이터 iPhone 17 Pro(없으면 iPhone 17). `-mapDebugCompleted`, `-skinDebug`, `-backdropDebug`. 파일은 `docs/review/backdrop-{풍경}-{색}-{light|dark}-{번호}.png`.

| 번호 | 화면 | 상태 |
|---|---|---|
| 01 | H | A-1 상태(지금 장면 띠가 풍경 띠 안에 옴) |
| 02 | H | A-2 상태(띠가 풍경 띠 아래) |
| 03 | H | 완료 칸이 풍경 띠 안에 오도록 위로 스크롤 |
| 04 | K 스킨 탭 | 홈 바탕 첫 행이 보임, 하나는 쓰는 중, 하나는 잠김 |
| 05 | C2 | 홈 바탕 묶음 |

| 묶음 | 풍경 | 색 | 모드 | 화면 | 보는 것 |
|---|---|---|---|---|---|
| A | 8장 모두 | 기본 | light | 01 | 세트로 밝기·선 굵기가 맞는지, 장면 띠 그림이 풍경보다 먼저 보이는지 |
| B | 2장(가장 진한 것, 가장 옅은 것) | 5색 | light, dark | 01 | 색마다 풍경이 그 색 종이에 찍힌 것처럼 보이는지, 다크에서 보이기는 하는지(N8) |
| C | 1장 | 기본, 보라 | light, dark | 02, 03 | 칸 테·글자 테가 풍경과 떼어 놓는지, 테가 "흰 테두리"로 튀지 않는지 |
| D | 1장 | 기본 | light | 04, 05 | 썸네일이 알아보이는지 |
| E | – | 기본 | light, dark | 01 | 풍경 없음 = 지금 화면과 같음 (회귀) |

## 7. 그림 주문서 (Z-Image Turbo, 로컬)

### 7.0 그리기 전에

- CLAUDE.md "그림 생성"대로: `curl -s -m 2 http://127.0.0.1:8188/system_stats` 응답과 모델 파일 세 개를 먼저 본다. 하나라도 없으면 생성하지 않고 이 절의 장면 목록과 7.3 프롬프트를 `docs/schedule.md` 보류 작업에 올린다. 다른 방법(SVG, 외부 서비스)으로 대신 그리지 않는다.
- 화풍은 기리다. `visual-rules.md`, `item-art/brief.md` 1번(공통 규격·색)을 읽는다. 같은 폴더의 `art-direction.md`(초안)는 따르지 않는다.
- 한 번에 한 장씩, 오래 걸리면 백그라운드로.

### 7.1 무엇을 그리나

| 순서 | id | 장면 | 풍경 (바깥 장소) | 넣지 않는 것 (장면 그림의 대상 등) | 주된 색 |
|---|---|---|---|---|---|
| 1 | `sushi` | 스시집 | 고요한 어항: 나무 창고, 작은 방파제와 등대, 고깃배 두 척, 옅은 물띠, 먼 낮은 언덕 | 초밥, 생선 모양, 접시, 게타, 노렌 | 옅은 하늘색 물, 남색 배, 나무색 |
| 2 | `tonkatsu` | 돈카츠집 | 옛 상점가: 2층 나무 가게집들, 회색 기와, 무지 노랑 차양, 화분, 가운데 먼 지붕과 둥근 나무 하나 | 그릇, 음식, 젓가락, 글자 있는 간판·노렌 | 나무색, 회색, 노랑 조금 |
| 3 | `soba` | 소바·우동집 | 산골 마을: 둥근 올리브 언덕, 초가집과 물레방아, 소나무, 가운데 작은 흰 꽃이 핀 메밀밭 | 면, 대발, 그릇, 잔 | 올리브, 흰 꽃, 나무색 |
| 4 | `station` | 역 | 작은 마을 철길(옆에서 봄): 가는 기둥 위 긴 승강장 지붕, 전신주와 전선, 왼쪽 육교, 오른쪽 먼 둥근 나무와 낮은 집 | **전철**, 시계, 행선지판, 글자 | 회색, 남색 조금, 올리브 |
| 5 | `shrine` | 신사·축제 | 축제 날 신사 숲: 양끝 키 큰 삼나무, 가운데 낮은 신사 본전 지붕, 가로로 걸린 둥근 종이 초롱 줄, 작은 돌등 둘 | **도리이**(문 이름을 프롬프트에 쓰지 않는다), 가면, 노점 음식 | 올리브, 나무색, 주황빨강 조금 |
| 6 | `izakaya` | 이자카야 | 작은 식당 골목(낮 색): 양쪽 낮은 나무 건물, 처마 밑 둥근 종이 초롱 몇 개, 나무 걸상, 쌓은 나무 상자, 무지 흰 문 천 | 꼬치, 화로, 음식, 맥주잔, 초롱 글자 | 나무색, 회색, 주황빨강 조금 |
| 7 | `onsen` | 온천 | 언덕 온천 마을: 둥근 올리브 언덕과 작은 소나무, 왼쪽 나무 목욕탕 건물, 오른쪽 작은 나무 다리와 개울, 가운데 땅에서 오르는 김 몇 줄기 | **목욕통**, 사람, 노렌의 ゆ | 올리브, 흰 김, 나무색 |
| 8 | `ryokan` | 료칸 | 료칸 정원: 왼쪽 긴 나무 여관 건물과 툇마루, 오른쪽 둥글게 다듬은 소나무와 돌등, 가운데 작은 연못과 징검돌, 낮은 생울타리 | **찻주전자·찻잔**, 이불, 다다미 방 안 | 하늘색 연못, 나무색, 올리브 |

- 이웃 장면끼리 가장 크게 보이는 것을 다르게 했다: 물(1), 거리(2), 밭(3), 구조물과 선(4), 숲과 초롱 줄(5), 골목(6), 언덕과 김(7), 정원과 연못(8).
- 넓은 면에 쓰지 않는 색: 초록(색상 125°~160°, 채도 25% 이상)과 분홍빨강(330°~359°). scene-art/brief.md 3.1과 같다. 언덕과 나무는 **muted olive**(색상 약 75°)로 그린다.

### 7.2 규격

| 항목 | 값 |
|---|---|
| 생성 크기 | **1280×640** (2:1, 약 0.82MP. 64의 배수). `--width 1280 --height 640` |
| 앱 에셋 | 띠 @3x 1320×660, @2x 880×440 (LANCZOS. 1280 → 1320은 1.03배). 썸네일 @3x 300×150, @2x 200×100 |
| 형식 | 생성은 불투명 PNG(단색 바탕). 도구가 바탕을 지워 RGBA로 |
| 외곽선 굵기 | 그림 폭의 약 0.5% (1280에서 약 6px → 402pt 화면에서 약 2pt). 장면 그림(72pt에 약 2pt)과 화면에서 같은 굵기 |
| 시점 | 정면 눈높이, 무대 배경처럼 원근이 거의 없음 |
| 구도 | 7.3의 LAYOUT. 위 1/8 비움(하늘 자리), 양끝이 높고 가운데 1/3이 낮고 성김, 맨 아래 땅 띠 |
| 기리, 사람, 동물, 얼굴, 글자 | 넣지 않는다 |

**왜 세로 화면용인데 가로 띠로 그리나**: 세로 그림(예 768×1280)에 "아래 3분의 2는 비워라"고 하면 모델이 빈 곳을 채우려 하고(home-map.md 8.2의 "가운데를 비우라는 지시를 모델이 어기기 쉽다"), 비운 곳이 바탕 지우기의 가장자리와 이어지지 않으면 지워지지 않는다. 보통의 넓은 풍경을 그리게 하고 도구가 뷰포트 위에 놓으면 빈 곳은 구도가 아니라 배치로 생긴다. 화면 폭이 360~440pt 어디든 띠를 자르지 않고 폭에 맞춰 줄이기만 하면 된다.

### 7.3 프롬프트

조립: `{BACKDROP_STYLE} {PALETTE} Subject: {대상} {BACKDROP_LAYOUT}`

**BACKDROP_STYLE**: scene-art/brief.md 4.2의 STYLE을 그대로 쓰되 **선 굵기 세 곳만** 바꿨다(굵은 글씨). STYLE의 "약 3%"는 72pt 물건 하나 기준이라 화면 폭 풍경에서는 선이 12pt가 된다.

```
Flat cartoon illustration with **clean** outlines. Every shape is outlined with one **thin**, uniform, dark chocolate brown line (#4A2219), **about half of one percent of the image width**, with rounded line ends and rounded joins, and every outline is fully closed. Flat solid color fills only: no gradients, no texture, no shading, no highlights, no shine, no reflections, no drop shadow. Soft, rounded, chunky shapes, simple and friendly.
```

(위 블록의 `**`는 바뀐 곳 표시다. 프롬프트에는 넣지 않는다. 원문: "bold clean outlines" → "clean outlines", "thick" → "thin", "about three percent of the image width" → "about half of one percent of the image width".)

**PALETTE**: scene-art/brief.md 4.2 그대로.

```
Colors: warm off-white, pale cream, dark indigo blue, pale sky blue, warm wood brown, warm yellow, soft orange red, soft pink, muted olive, and the dark chocolate brown of the outlines. No bright green, no emerald, no crimson, no magenta, no pure red, no neon colors.
```

**BACKDROP_LAYOUT**

```
A wide, calm landscape panorama seen straight from the front at eye level, like a flat stage backdrop, with almost no perspective and no road leading into the distance. Taller shapes stand near the left and right ends of the image; the middle third is lower, simpler and more open, with only small, distant shapes. The top eighth of the image is completely empty. The scenery stands on one simple flat ground strip that runs along the whole bottom of the image. Behind the scenery there is no sky: everything that is not scenery is one flat solid pale sand beige color, with no clouds, no sun, no birds, no gradient. No people, no animals, no characters, no faces. No text, no letters, no numbers, no logos, no symbols on any surface; every sign, curtain, lantern, awning and panel is completely plain. No border, no frame, no vignette.
```

**대상 문장** (`{대상}`):

| id | 대상 문장 |
|---|---|
| `sushi` | `A quiet small fishing harbor. On the left, a low wooden harbor shed with a gently sloped gray tiled roof. On the right, a short stone breakwater with a small round off-white lighthouse. In the middle, two small wooden fishing boats with dark indigo hulls float on a calm flat strip of pale sky blue water, and low rounded hills lie far behind the water. The ground strip is a pale gray stone quay.` |
| `tonkatsu` | `A small old shopping street. On the left and on the right, low two-story wooden shop houses with dark gray tiled roofs, plain off-white walls and plain warm yellow fabric awnings, with a few potted plants by the doors. In the middle, the street opens to a few small distant roofs and one round tree. The ground strip is a pale gray paved street.` |
| `soba` | `A gentle mountain village. Rounded muted olive hills lie behind. On the left, a small thatched farmhouse with a wooden water wheel. On the right, a few tall pine trees in muted olive. In the middle, a low field of buckwheat with many tiny off-white flowers on muted olive stems. The ground strip is a warm wood brown dirt path.` |
| `station` | `A small town railway seen from the side. A long low platform roof on thin gray posts runs across the middle, with a row of thin overhead wire poles behind it. On the left, a pedestrian footbridge with a plain off-white railing. On the right, a row of rounded muted olive trees and low houses far behind. The ground strip is a pale gray gravel track bed with one straight rail.` |
| `shrine` | `A shrine forest on a festival day. Tall rounded cedar trees in muted olive stand at both ends. Between them, the low roof of a small wooden shrine hall with gently upturned eaves. A string of round soft orange red paper lanterns hangs across the middle. Two small gray stone lanterns stand on the ground. The ground strip is pale gray gravel.` |
| `izakaya` | `A narrow lane of small eateries in daytime colors. Low wooden buildings with gray tiled roofs stand on the left and on the right, with a few round soft orange red paper lanterns hanging under the eaves, plain off-white cloth hanging in the doorways, a wooden bench and stacked wooden crates by a door. In the middle, small distant rooftops. The ground strip is pale gray stone paving.` |
| `onsen` | `A hot spring town in the hills. Rounded muted olive hills with a few small pine trees lie behind. On the left, a wooden bathhouse with a gray tiled roof. On the right, a small arched wooden footbridge over a narrow pale sky blue stream. In the middle, several soft wavy pale off-white steam wisps rise from the ground. The ground strip is rounded gray rocks.` |
| `ryokan` | `A traditional inn garden. On the left, a long low wooden inn building with a dark gray tiled roof and a wooden veranda. On the right, a round trimmed pine tree in muted olive and a gray stone lantern. In the middle, a small calm pale sky blue pond with stepping stones and a low trimmed hedge. The ground strip is pale raked gravel.` |

- 장면 그림의 대상(초밥, 그릇, 전철, 도리이, 꼬치, 목욕통, 찻주전자)은 **이름을 쓰지 않는다.** 금지어로 적어도 모델이 그려 넣는다(scene-art/brief.md 5.2의 표, "이름을 적으면 오히려 그려 넣으므로").
- 바탕을 "pale sand beige"로 둔 이유: 지난 지도 띠 초안(home-map.md 6.4)과 장면 그림의 SAND와 같아 모델이 잘 따르고, `remove_bg.py`가 가장자리부터 지운다. 하늘을 하늘색으로 그리게 하면 물(하늘색)과 하늘 사이에 외곽선이 없을 때 물까지 지워진다.

**명령** (예: `sushi`, 저장소 루트에서):

```bash
.venv/bin/python tools/gen_image.py "{BACKDROP_STYLE} {PALETTE} Subject: {sushi 대상 문장} {BACKDROP_LAYOUT}" \
  --name backdrop-sushi --out docs/design/backdrop-art/source/candidates \
  --width 1280 --height 640 --seed 301 --count 4
```

`--steps 8 --shift 3.0`(기본값)은 바꾸지 않는다. 다른 장면은 대상 문장과 `--name backdrop-{id}`만 바꾼다. `{…}` 자리에는 위 블록의 문장을 그대로 넣는다(`**` 표시 없이).

### 7.4 후보 수와 합격 검사

- **장면마다 후보 4장**(시드 301~304). 합격이 없으면 7.6.
- 먼저 `tools/make_backdrop_art.py check {후보.png}…`로 바탕을 지우고 수치(N)를 낸 뒤, 눈 검사(B)를 한다. 하나라도 걸리면 버린다.

**수치 검사** (바탕을 지운 1280×640 RGBA에서. "불투명" = 알파 ≥ 128):

| # | 무엇 | 기준 | 뜻 |
|---|---|---|---|
| N1 | 지운 바탕 비율 | 30% ~ 70% | 풍경이 너무 비거나 벽처럼 꽉 차지 않음 |
| N2 | 위 1/8(80줄)의 불투명 비율 | ≤ 2% | 바 아래 16pt가 비어 있음 |
| N3 | 가운데 1/3 열(x 427~853)의 불투명 비율 ÷ 양옆 1/3 평균 | ≤ 0.85 | 가운데가 낮고 성김. 다가오는 칸이 지나가는 자리 |
| N4 | 진한 픽셀(상대 휘도 < 0.05, 불투명) 비율 | ≤ 6% | 외곽선이 가늘고 그림이 조용함 |
| N5 | 불투명 픽셀 가운데 색상 125°~160°(채도 ≥ 25%) / 330°~359°(채도 ≥ 25%) | ≤ 3% / ≤ 1% | 판정 색과 섞이지 않음 (화면 폭 그림이라 장면 그림의 10%보다 엄하게) |
| N6 | 지운 뒤 풍경 안에 생긴 투명 구멍(투명 영역 가운데 가장자리와 이어지지 않은 것) | 0 | 바탕 지우기가 풍경을 먹지 않음 |
| N7 | `build` 뒤 계산된 불투명도 | 라이트 ≥ 0.20, 다크 ≥ 0.06 | 씻긴 뒤에도 보임 (2.3 하한) |
| N8 | (참고) 라이트 기본 색 합성의 띠 영역 휘도 표준편차, 다크 기본 색 합성의 최대 휘도 | 낮을수록 조용함 / 0.025 이상이면 다크에서 보임 | 여러 장이 통과하면 고르는 순서에 쓴다. 고른 8장의 값을 이 문서에 적는다 |

**눈 검사** (1280×640 원본을 100%로, 그리고 402×201pt 크기로 줄여 본다):

| # | 확인 | 탈락 조건 |
|---|---|---|
| B1 | 틀 | 테두리, 둥근 사각 틀, 비네트 |
| B2 | 글자 | 확대했을 때 글자, 숫자, 글자처럼 보이는 낙서. 간판·차양·초롱·문 천을 특히 본다 |
| B3 | 생물 | 사람, 동물, 새, 얼굴(창문 두 개 + 문이 얼굴처럼 보이는 집 포함) |
| B4 | **장면 그림의 대상** | 7.1 "넣지 않는 것"이 알아볼 만한 크기로 있다 (전철, 도리이, 초밥, 그릇, 꼬치, 목욕통, 찻주전자) |
| B5 | 하늘 | 구름, 해, 그라데이션 하늘. 지워지지 않고 남는다 |
| B6 | 원근 | 가운데로 빨려 들어가는 길, 소실점 |
| B7 | 선 | 외곽선이 그림 폭의 1%(13px)보다 굵거나, 끊기거나, 스케치처럼 여러 겹 |
| B8 | 바탕 지우기 | 지운 결과(체크무늬 위)에서 풍경 가장자리에 베이지 테, 지워진 지붕·물 |
| B9 | 세트 | 이미 고른 풍경 옆에 놓았을 때 선 굵기, 밝기, 물건 크기가 다른 계열 |
| B10 | 고증 | 기와, 신사 지붕, 승강장, 료칸이 다른 나라 모양과 섞임 |

- 통과한 후보가 여럿이면: B4에서 가장 먼 것(장면 그림 대상의 흔적이 없음) → N3이 작은 것(가운데가 조용함) → N8 표준편차가 작은 것 순.
- 고른 뒤 사용자에게 8장 비교 시트(`build/backdrop/sheet.png`, 기본 색 라이트·다크 합성)를 보여 확인받는다(장면 그림 때와 같음).

### 7.5 넣는 방법 (`tools/make_backdrop_art.py`)

파이썬 + Pillow. 이름과 인자는 developer가 정해도 되고, 아래 단계를 한다.

| 하위 명령 | 하는 일 |
|---|---|
| `check 후보.png…` | `remove_bg.py`의 `remove_bg()`(허용차 40)로 바탕을 지우고 N1~N6을 출력 |
| `build` | `docs/design/backdrop-art/source/backdrop-{id}.png`마다: ① 바탕 지우기 ② **어두운 끝 들어올리기**: 상대 휘도 0.18 미만인 불투명 픽셀을 선형 RGB에서 흰색 쪽으로 섞어 휘도 0.18로 맞춤(색상은 유지). 외곽선이 묶는 불투명도를 풀어 면이 더 보이게 한다 ③ 1320×660으로 LANCZOS ④ **아래 30% 알파 줄임**: 행 y가 0.70H → H로 갈 때 알파 × (1 − smoothstep(t)) ⑤ 썸네일 300×150 ⑥ `skins.json`의 5색 × 2모드에서 2.3 조건을 만족하는 가장 큰 o를 0.01 단위 내림으로 찾고 `limits`로 자름 ⑦ `build/backdrop/`에 쓰고 에셋 카탈로그로 복사, `backdrops.json`의 `opacity`를 씀 ⑧ 비교 시트 |
| `verify` | 6.4 V1~V6 |

- 입력은 고른 원본(불투명)이고, 지우기·들어올리기·씻김은 모두 도구가 한다. 원본을 손으로 고치지 않는다.
- 고른 그림: `docs/design/backdrop-art/source/backdrop-{id}.png`와 같은 이름의 `.json`(프롬프트, 시드). 후보 폴더 `docs/design/backdrop-art/source/candidates/`는 커밋하지 않는다(`.gitignore`에 더해 두었다).

### 7.6 안 될 때

- 4장 중 3장 이상이 같은 이유로 걸리면 시드가 아니라 문장 탓이다. STYLE·PALETTE·LAYOUT은 그대로 두고 대상 문장만 고쳐 4장을 더 뽑는다(`--seed 305 --count 4`).
  - N3(가운데가 꽉 참): 대상 문장의 "In the middle, …"를 "In the middle, only …, small and far away."로.
  - N2(위가 참): 키 큰 것(삼나무, 등대)에 "short"를 붙인다.
  - B4(대상이 나옴): 그 물건을 부르는 단어(예: shrine → "shrine hall"만 남기고 "festival" 빼기)를 줄인다.
  - B7(선이 굵음): BACKDROP_STYLE의 "about half of one percent"를 그대로 두고 대상 문장 끝에 "All lines are thin."을 더한다. 그래도 굵으면 "about one percent"(화면에서 약 4pt)로 올려 전체를 다시 맞춘다(8장 모두 같은 값).
- 같은 이유로 두 번 실패하면 PM에게 알린다.

### 7.7 장수와 시간

| 그림 | 생성 | 시간 (기준 Mac, 0.82MP 한 장 약 3~4분) |
|---|---|---|
| 8장면 × 후보 4 | 32 | 약 1.6~2.2시간 |
| 다시 뽑기 (예상 2~3장면) | 8~12 | 약 0.5~0.8시간 |
| 고르기, 비교 시트, 확인 | | 약 0.5~1시간 |
| 합계 | 40~44 | **약 3~4시간** |

## 8. 다른 문서와의 관계

| 문서 | 이 문서가 바꾸는 것 | 처리 |
|---|---|---|
| app-skin.md | B 절을 "안 3 채택"으로, K 스킨 탭에 두 섹션 | 함께 고쳤다 |
| home-map.md | 6.2·6.3·6.4·8.2의 "장면 바탕 띠"(2단계)를 이 문서가 대신함. 지도 요소의 테(2.4) | 고치지 않았다. PM이 6.2 표에 "home-backdrop.md로 대신함" 한 줄을 넣기를 권한다 |
| reward-flow.md | 6.2의 열린 아이템 줄에 홈 바탕 묶음(5.2) | 고치지 않았다(다음 reward-flow 작업 때) |
| visual-rules.md | 머리말 "그림은 …만 쓴다"에 홈 바탕 그림 | 고치지 않았다 |
| `docs/content/reward-system.md` | 3.2(C2에 드러나는 것), 7번(`backdrop` 필드) | planner (D1~D3 결정 뒤, PM 경유) |
| `PLAN.md` 3번 "기리 꾸미기", 8번 배경 항목 | | PM |

## 9. 규모

| 일 | 담당 | 추정 |
|---|---|---|
| 풍경 8장 생성·선별 | designer | 약 3~4시간 (7.7) |
| `make_backdrop_art.py` (check, build, verify, 시트) | developer | 0.5일 |
| 저장·모델·`backdrops.json` | developer | 0.25일 |
| 홈 층(풍경 띠, 씻김, 섞기 확인) | developer | 0.5일 |
| 테 6종(칸, 말풍선, 띠 그림 받침, 글자, 점, 표지) | developer | 0.5일 |
| K 두 섹션, 칸, 문구, VoiceOver | developer | 0.5일 |
| C2 묶음 | developer | 0.25일 |
| 스크린샷 6.6 | developer | 0.25일 |
| 합계 | | 그림 약 0.5일 + 코드 **약 2.5~2.75일** |

색 전부 열기(app-skin.md 개정 2)는 따로 약 0.5일이다.

## 10. 실기기에서 확인할 것

| 값 | 확인할 것 |
|---|---|
| 라이트 최저 휘도 0.55, 불투명도 0.25~0.40 | 풍경이 "보상"으로 보일 만큼 보이는지, 다시 "난잡"해지지 않는지. 햇빛 아래에서 사라지지 않는지 |
| 다크 최고 휘도 0.06 | 어두운 곳에서 보이기는 하는지, 눈부시지 않은지 |
| 바탕색 테 2pt | 테가 흰 테두리처럼 튀지 않고 "비켜 난 자리"로 보이는지 |
| 고정된 풍경 띠 | 스크롤할 때 칸이 풍경 위로 지나가는 것이 어지럽지 않은지 |
| 썸네일 100×50 | 375pt에서 무슨 풍경인지 알아보이는지 |
| 풍경과 장면 띠 그림 | 같은 화면에 있을 때 띠 그림이 먼저 보이는지, 다른 장면 풍경이 "지금 어디"를 흐리지 않는지 |

## 구현 메모 (2026-11-22, developer)

문서에 없어 정한 것과 문서와 다르게 나온 것. 기획 결정은 바꾸지 않았다.

**결정 전 기본값이 있는 곳** (답이 오면 이 값만 고친다)

| 결정 | 지금 값 | 바꾸는 곳 |
|---|---|---|
| D1 풍경 얻는 법 | 가(장면 완료로 열림) | `KanaTrip/Resources/backdrops.json`의 `"unlock": "sceneComplete"` → `"all"`이면 처음부터 모두 열림. 그때 C2 알림은 자동으로 사라진다(`BackdropCatalog.newlyUnlocked`) |
| D2 자동으로 바꿀지 | 가(바꾸지 않음) | 코드에 갈래가 없다(열려도 `rewards.backdrop`을 건드리지 않음) |
| D3 C2 알림 | 가(묶음 추가) | `KanaTrip/Session/CompletionViews.swift` `SceneDoneView`의 `backdrop` |
| Q1 색 아이템 4개 | 가(팔지 않음, 목록에서 뺌) | `KanaTrip/Skin/SkinModel.swift` `SkinPolicy.sellsColorItems = false`. `RewardCatalog.retiredSlots`가 열림·살 수 있음·C2·16장면 지급·K 격자에서 뺀다. `owned`는 지우지 않는다 |

**구현에서 정한 것**

- 열림 판단은 `paid`의 `scene/{장면 id}`로 했다(3번 표의 `"{X}-quiz"` 대신). 장면의 세션을 모두 끝낸 첫 저장에서 들어가는 키라 같은 때 생기고, 진도 초기화에도 남는다.
- 홈의 풍경은 `MapView`의 `.background`에 둔다(`MapBackdropLayer`). 풍경이 없거나 대비 증가면 이전과 같은 `MapPalette.groundLayer` 한 장을 그리고 테도 그리지 않는다. 이전 빌드와 픽셀을 직접 비교하지는 않았다(코드 경로가 같다).
- 식 맞추기(2.3): 시뮬레이터(iPhone 17, 기본 색)에서 풍경 픽셀과 도구의 식을 비교해 라이트·다크 모두 채널 차이 중앙값 0~1/255, 90백분위 1/255였다. 합성은 sRGB 부호화 값에서 일어난다. 이때 뷰포트 위 끝은 402×874에서 y = 116pt였다(2.2 표의 106pt는 추정값).
- 글자 테(2.4)는 같은 글자를 바탕색으로 칠한 사본(`ground.mask(content)`)을 8방향으로 밀어 깔았다(`MapHalo`, 대각은 ±0.7 × 2pt).
- DEBUG 인자: `-backdropDebug <id>`(저장·열림 무시, `-mapDebugCompleted`와 쓰면 저장 상태에도 씀), `-backdropUnlockAll`(열림 규칙만 "모두 열림"), `-debugSceneDone <장면 id>`(그 장면을 방금 끝낸 C2).
- 스킨 탭: 홈 바탕 그림이 하나도 없으면 두 섹션 머리를 숨기고 색 견본 줄만 둔다(app-skin.md 5.2).

**검사 도구(`tools/make_backdrop_art.py`)에서 정한 것**

- 바탕 지우기: `remove_bg()`(허용차 40)에 바탕색을 직접 준다. 위 변 세 줄의 중앙값이다. 네 변 중앙값은 땅 띠가 아래 변을 다 차지하면 땅 색이 되어 하늘 대신 땅을 지웠다(돈카츠집 302). `remove_bg.py`에는 기본값 그대로인 `bg` 인자만 더했다.
- N4는 **전체 픽셀에 대한 비율**로 셌다(N1과 같은 분모). 불투명 픽셀 대비 값도 함께 적는다. 불투명 대비로 세면 선 굵기 약 6px인 그림도 10% 안팎이라 기준 6%를 넘는다.
- N5는 진한 픽셀(휘도 0.05 미만, N4의 외곽선)을 빼고 센다. 모델이 그린 진갈색 선이 `(35, 4, 6)`처럼 색상 350° 언저리로 나와 외곽선만으로 분홍빨강 5%가 나왔다(스시집 301).
- N6은 알파 128 미만 영역 가운데 가장자리에 닿지 않는 20픽셀 이상 덩어리 수다.
- V4 예외: **청록 다크**(`#0E2224`, 색상 186°) 위에 스크린으로 올리브·하늘색이 더해지면 색상이 125°~160° 안으로 들어온다(역 9.1%, 이자카야 2.5%, 온천 1.4%). 휘도 0.045 이하의 아주 어두운 청록이라 판정 초록과 헷갈릴 밝기는 아니라고 보고 `V4_EXCEPTIONS`에 명시해 표에 따로 적었다. **designer 확인 필요.**
- 생성: `gen_image.py`는 기본 1800초 기다림이 지나면 실패로 끝난다. 큐를 함께 쓰는 동안 한 장에 13~28분 걸려 돈카츠집 304가 한 번 걸렸고, ComfyUI 기록(`/history`)에서 그림을 받아 같은 이름으로 두었다.

**고른 그림과 결과** (후보 44장 = 8장면 × 4 + 다시 뽑기 3장면 × 4. 판정은 `docs/design/backdrop-art/verdicts.json`, 시트는 `docs/review/backdrop-candidates-*.png`)

| 장면 | 고름 | 라이트 / 다크 o | N8 표준편차 / 다크 최대 | 비고 |
|---|---|---|---|---|
| 스시집 | 302 | 0.28 / 0.13 | 0.070 / 0.038 | 301은 배 창이 눈처럼 보임(B3), 303 지붕 무늬가 글자처럼(B2), 304 땅이 지워짐 |
| 돈카츠집 | **309 (3차, 2026-11-23)** | 0.27 / 0.18 | 0.086 / 0.055 | 1차 301~304, 2차 305~308은 모두 선이 굵다(N4 6.3~9.1%). 3차 309~312는 대상 문장을 고침(아래 "돈카츠집·료칸 다시 그리기"). 309만 통과(N4 5.3%) |
| 소바·우동집 | 301 | 0.27 / 0.14 | 0.093 / 0.039 | 302~304는 언덕이 가로로 다 차서 N3 탈락 |
| 역 | 306 (2차) | 0.27 / 0.13 | 0.073 / 0.037 | 1차 4장 모두 전철(B4)과 가운데 승강장(N3). 2차 문장: "railway"를 빼고 "In the middle, only a short low platform roof …, small and far away", 끝에 "All lines are thin." 306은 육교가 없다 |
| 신사·축제 | 305 (2차) | 0.26 / 0.13 | 0.097 / 0.038 | 1차 4장 모두 도리이(B4). 2차 문장: "festival day" 빼고 "only the low roof of a small wooden shrine hall … solid wooden walls, small and far away". 풍경이 그림 양끝까지 닿지 않는다 |
| 이자카야 | 304 | 0.27 / 0.13 | 0.086 / 0.037 | 건물이 가운데로 작아져 깊이감이 조금 있다(B6 경계, 통과로 봄) |
| 온천 | 303 | 0.28 / 0.13 | 0.084 / 0.037 | N3 0.84로 기준에 가깝다 |
| 료칸 | **없음** | – | – | 1차 301~304: 4장 모두 선 굵기(B7)·초록 덤불(N5), 3장은 창-문-창 얼굴(B3). 2차 305~308(2026-11-23): 초록과 얼굴은 대체로 피했으나 3장이 다시 선 굵기(N4 6.3~8.4%), 308은 땅 띠 없음(N1 76%). 같은 이유로 두 번 실패(7.6) |

`make_backdrop_art.py verify --markdown` (2026-11-22):

| 풍경 | 불투명도 라이트/다크 | V1 라이트 0.1%ile (최저) | V2 다크 99.9%ile (최고) | V3 | V4 초록/분홍 (최대) | V5, V6 | 결과 |
|---|---|---|---|---|---|---|---|
| sushi | 0.28 / 0.13 | 0.551 | 0.0445 | 통과 | 0.00% / 0.00% (예외 teal dark 0.14%) | 통과, 통과 | 통과 |
| tonkatsu | 0.27 / 0.18 | 0.551 | 0.0600 | 통과 | 0.00% / 0.00% (예외 teal dark 6.83%) | 통과, 통과 | 통과 |
| soba | 0.27 / 0.14 | 0.557 | 0.0436 | 통과 | 0.00% / 0.00% (예외 teal dark 0.01%) | 통과, 통과 | 통과 |
| station | 0.27 / 0.13 | 0.556 | 0.0430 | 통과 | 0.00% / 0.00% (예외 teal dark 9.08%) | 통과, 통과 | 통과 |
| shrine | 0.26 / 0.13 | 0.557 | 0.0430 | 통과 | 0.00% / 0.00% (예외 teal dark 0.34%) | 통과, 통과 | 통과 |
| izakaya | 0.27 / 0.13 | 0.553 | 0.0428 | 통과 | 0.00% / 0.00% (예외 teal dark 2.47%) | 통과, 통과 | 통과 |
| onsen | 0.28 / 0.13 | 0.554 | 0.0436 | 통과 | 0.00% / 0.00% (예외 teal dark 1.36%) | 통과, 통과 | 통과 |
| ryokan | 그림 없음(칸 없음) |  |  |  |  |  | – |

**화면에서 본 것** (`docs/review/backdrop-home-all.png`, `-all-dark`, `-skins`, `-scroll`, `backdrop-skin-tab.png`, `backdrop-c2.png`)

- 모델은 풍경을 그림 **아래 40~50%**에만 그렸다(위 절반은 빈 베이지). 여기에 아래 30% 알파 줄임이 겹쳐, 홈에서 보이는 풍경은 띠 201pt 가운데 y 약 90~170pt의 가는 띠가 된다. 땅 띠와 물가는 거의 사라진다. 조용하다는 목표에는 맞지만 "넓은 풍경"보다 "얇은 지평선"에 가깝다. 구도 문장(LAYOUT)이나 알파 줄임 범위를 다시 볼지는 designer 판단이 필요하다.
- 라이트: 글자·칸·말풍선은 테 덕분에 풍경 위에서도 그대로 읽힌다. 장면 띠 그림(원래 색, 외곽선)이 풍경(씻긴 판화)보다 먼저 보인다. 띠 그림 받침 4pt는 풍경이 있는 높이에서만 "비켜 난 자리"로 보이고 흰 테두리처럼 튀지는 않는다.
- 다크: 보이기는 하지만 아주 옅다. 스시집은 거의 보이지 않고, 소바·역·온천은 밝은 면(하늘색·흰 면)만 희미하게 떠오른다. 2.7의 "0.06까지 올리기"를 검토할 만하다.
- 색 스킨(주황·파랑): 풍경이 그 색 종이에 찍힌 판화처럼 보인다. 파랑 다크에서 가장 잘 보인다.

**다크 바탕 진하게** (2026-11-23, developer. 이슈 #7 저장소 주인 결정 (2))

| 값 | 전 | 후 |
|---|---|---|
| 다크 상한 `limits.darkMaxLuminance` (2.3, V2) | 0.045 | **0.06** |
| 다크 불투명도 `opacity.dark` (도구가 계산) | 스시 0.13, 소바 0.14, 역·신사·이자카야·온천 0.13 | 스시 0.17, 소바 0.19, 역 0.18, 신사 0.18, 이자카야 0.18, 온천 0.17 |
| 기본 색 다크 99.9백분위 (예: 소바) | 0.037 | 0.052 |
| 5색 중 최고 (V2, 청록이 정함) | 0.0428~0.0445 | 0.0572~0.0599 |

- 고른 값: 2.7이 허용한 끝인 **0.06**. 0.06보다 올리면 풍경의 가장 밝은 곳이 다크 `PathEdge`(기본 0.047, 청록 0.061)보다 밝아져 점선보다 풍경이 먼저 보인다(라이트에서 0.55를 `PathEdge`에 맞춘 것과 같은 위계 기준). 그래서 이 문서 안에서 고를 수 있는 가장 진한 값이다. 더 올리는 것은 designer 결정이다.
- 대비·후광 검사 (2.4): 지도 요소는 모두 면이나 바탕색 테 위에 있어 글자·아이콘 대비는 지금 바탕 위 값 그대로다(바뀌지 않음). 테가 없다고 쳐도 풍경 최고 0.06에서 `Ink` 다크(0.863) 8.3:1, `InkSecondary` 다크(0.402) 4.1:1, 다크 `Outline`(0.188) 2.2:1(2.4 표대로 적용 안 함). `InkSecondary`가 4.5:1을 넘으려면 0.05 이하여야 하므로 **띠 글자의 가독은 글자 테(2px)에 기댄다.** 스티커는 크림 테, 기리는 흰 몸이 떼어 놓는다. 스크린샷(`docs/review/backdrop-dark-after.png`, 소바, 기본 색)에서 띠 글자·가나·자물쇠 칸·점선 점·말풍선이 풍경에 닿는 곳이 없다.
- 화면 픽셀(같은 자리, sRGB 0~255): 언덕 (52, 51, 53) → (58, 60, 63), 밭 (47, 46, 35) → (53, 54, 40). 풍경이 없는 곳은 (31, 23, 20) 그대로. 전·후 스크린샷 `docs/review/backdrop-dark-before.png`, `-after.png`(iPhone 17, `-backdropDebug soba`).
- 라이트는 건드리지 않았다(불투명도·에셋 PNG 그대로, `build`가 같은 파일을 냈다).
- V4 예외(청록 다크의 초록 비율)가 커졌다: 역 12.8%, 이자카야 12.4%, 온천 20.3%, 소바 29.0%, 신사 44.0%, 스시 0.14%. 휘도는 0.06 이하라 여전히 아주 어둡지만 비율이 커졌으므로 **designer 확인 필요**(위 V4 예외 항목과 같은 건).
- 테스트: `BackdropTests`의 다크 기준은 `backdrops.json`의 `limits`를 읽으므로 자동으로 0.06을 쓴다. `BackdropLimits` 기본값과 테스트 픽스처의 0.045도 0.06으로 맞췄다.

**돈카츠집·료칸 다시 그리기** (2026-11-23, developer. 이슈 #7 결정 (1))

- 대상 문장은 `tools/make_backdrop_art.py`의 `SUBJECTS`로 옮겼다(`prompt {id}`가 7.3대로 조립해 출력). 고른 6장의 문장은 `source/backdrop-{id}.json`과 글자 하나 다르지 않게 맞췄다. STYLE·PALETTE·LAYOUT은 그대로다.
- 돈카츠집 3차(시드 309~312): 1·2차 탈락 이유는 2층 가게집의 창·기와 줄 같은 작은 선(N4), 가운데로 빨려 드는 길(B6), 초록 나무(N5). 통과한 이자카야처럼 **낮은 단층 가게, 넓은 무지 벽, 무늬 없는 지붕, 길 대신 땅 띠**, 가운데는 나무 하나만, "Large simple shapes with few small details."를 더했다. 결과: 309 통과(N4 5.3%), 310 땅 띠 지워짐(B8), 311·312 선 굵음(B7). **309를 골랐다.** 약점: 문 손잡이 두 점이 원본 100%에서 눈처럼 보일 수 있다(402pt에서는 보이지 않음), 양끝의 큰 하늘색 원과 땅의 차선 점선은 옛 상점가 고증이 약하다(B10 약함). 시트 `docs/review/backdrop-tonkatsu-r2.png`, 홈 `backdrop-tonkatsu-light.png`·`-dark.png`.
- 료칸 2차(시드 305~308): 1차 탈락 이유는 정면 대칭 앞면의 창-문-창 얼굴(B3), 선 굵음(B7), 생울타리·덤불 초록(N5). **비스듬히 옆에서 본 여관**(넓은 처마, 무지 남색 노렌, 기둥 위 종이 등롱, 툇마루 뒤 같은 미닫이 칸의 줄), 생울타리를 빼고, 가운데는 작은 연못만, "Large simple shapes with few small details.", "All lines are thin."으로 고쳤다. 결과: 초록은 모두 사라졌고(N5 0.0%) 305·307은 얼굴도 피했지만, 305·306·307의 선이 굵고(N4 8.4%, 6.3%, 7.8%) 308은 선은 가늘지만(5.9%) 땅 띠가 없어 지운 비율이 76%이고 정면 대칭이다. 306·308은 다시 정면이 되었다. **통과 없음, 에셋을 넣지 않았다.** 선 굵기로 두 번 실패라 7.6대로 PM에 알린다. 건물이 화면 폭에서 차지하는 몫이 큰 장면은 창살·지붕 줄 같은 작은 선이 많아 N4(전체 픽셀 대비 6%)를 넘기 쉽다. 다음 시도 후보: 7.6의 "about one percent"로 8장 전체를 다시 맞추기(designer 결정), 또는 여관을 더 작게 멀리 두고 정원(연못·소나무)을 크게. 시트 `docs/review/backdrop-ryokan-r2.png`.

## 11. 변경 기록

- 2026-11-21 (designer): 처음 씀. 이슈 #7 답 "3안으로, 스킨, 그냥 다 열리게"에 따라 안 3을 확정 사양으로. 뷰포트 위 고정 띠(W × W/2), 라이트 곱하기·다크 스크린 씻김(도구가 그림마다 불투명도 계산, 라이트 휘도 ≥ 0.55, 다크 ≤ 0.045), 지도 요소의 바탕색 테 규칙, 장면 그림과의 겹침 해법(자리·세기·받침·내용), K 스킨 탭의 "홈 바탕" 줄, C2 묶음, `backdrops.json`, `RewardState.backdrop`, 그림 주문서(1280×640, 8장면 대상 문장, 후보 4장, 수치·눈 검사, 다크는 같은 그림). 기획 결정 D1~D3은 0.2.
- 2026-11-22 (developer): 끝에 "구현 메모"를 더함(기본값 바꾸는 곳, 검사 도구에서 정한 것, 고른 그림 6장과 돈카츠집·료칸 없음, verify 결과, 화면에서 본 것).
- 2026-11-23 (developer): 다크 상한 0.045 → 0.06(이슈 #7 결정), 다크 불투명도 0.13~0.14 → 0.17~0.19. 0번 요약, 2.3, 2.4, 2.7, 6.1, 6.4, 10번 수치와 구현 메모 "다크 바탕 진하게".
- 2026-11-23 (developer): 돈카츠집 3차(309~312)에서 309를 넣음, 료칸 2차(305~308)는 통과 없음. 대상 문장은 `make_backdrop_art.py` `SUBJECTS`로. 구현 메모 "돈카츠집·료칸 다시 그리기".
