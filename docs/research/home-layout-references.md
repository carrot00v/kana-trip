# 홈 레이아웃 참고 사례: 학습 진행을 길·지도·목록으로 보여 주는 앱

- 조사 질문: 학습 진행을 홈 화면의 길/지도/단계 목록으로 보여 주는 모바일 앱들은 메인 레이아웃을 어떻게 짜는가. KanaTrip 홈을 다시 구성할 때 바로 쓸 수 있는 원칙은 무엇인가.
- 조사한 날짜: 2026-11-21 (아래 모든 URL을 이날 확인했다)
- 방법: 공식 블로그·도움말·스토어 페이지·팬 위키·화면 모음 사이트의 그림을 브라우저로 열어 직접 봤다(이미지 파일은 저장소에 넣지 않았다). 앱을 설치해 써 보지는 않았다. KanaTrip 쪽은 `docs/review/map-sushi-light.png`, `docs/review/map-sushi-done-stickers.png`(402×874pt)와 `docs/design/home-map.md`의 수치를 썼다.
- 본 앱: 16개(화면을 직접 본 것 14개, 글로만 확인한 것 2개). 본 화면 약 60장, 판단에 쓴 것 약 25장.
- 수치(칸 크기 %, 한 화면의 칸 수, 좌우 이동 %)는 모두 스크린샷을 보고 잰 눈대중이다. 오차 ±20% 정도로 읽는다.

요약: 본 사례는 네 유형으로 나뉜다(세로 길형, 세로 타임라인 목록형, 오늘의 한 가지 카드형, 표·격자형). 세로 길형 6개 가운데 **길을 선으로 그리지 않거나 아주 옅은 점선으로만 그린 것이 5개**이고, 칸이 화면 폭의 약 13~20%로 커서 칸 자체가 길로 읽힌다. 이웃한 칸의 좌우 이동은 Duolingo가 폭의 약 7~15%로 가장 작고, 캔디 크러시는 2017년 → 2023년 개편에서 구불구불한 길을 가운데 거의 곧은 길로 바꿨다. 캐릭터는 대부분 길 옆 빈 곳에 서고, 단원은 위에 붙는 띠(배너)나 화면 폭을 다 쓰는 큰 그림 하나로 구분한다. 지금 KanaTrip 화면은 칸이 폭의 9~11%로 작고, 이웃 칸이 폭의 40%씩 좌우로 움직이고, 4~6pt 선이 화면에서 가장 긴 요소라는 점이 본 사례들과 다르다.

## 1. KanaTrip에 쓸 수 있는 원칙

"구분"의 뜻. 확인: 그림에서 직접 본 것. 글: 공식 글·기사에만 있는 것. 해석: 여러 사례를 묶어 조사 담당이 읽은 것. 설계 결정은 디자이너 몫이라 "~하는 사례가 많다/적다"로만 적는다.

| # | 원칙 | 근거 사례 | 지금 KanaTrip 화면 | 구분 |
|---|---|---|---|---|
| 1 | **칸이 곧 길이다.** 세로 길형 6개 중 5개는 길을 선으로 그리지 않거나(Duolingo, Speak) 바탕보다 조금 진한 옅은 점선·가는 선으로만 그린다(LingoDeer, Mimo, Duolingo ABC). 굵은 길 면을 그리는 것은 게임(캔디 크러시)뿐이고, 그 길도 바탕과 같은 분홍 계열이다 | Duolingo 2026-10 화면, Speak 2025-12 화면, LingoDeer·Mimo·Duolingo ABC 화면 | 진갈색 6pt(지난 길)·베이지 4pt(앞길) 실선이 칸 사이를 잇는다. 첫 화면에서 가장 길고 진한 모양이 길 선이다 | 확인 |
| 2 | **칸이 크다.** 칸 지름이 화면 폭의 약 19~20%(Duolingo, LingoDeer, Mimo, Duolingo ABC. 402pt로 치면 약 76~80pt), 캔디 크러시 새 지도는 약 13%. Speak는 칸이 글자를 담은 알약(폭의 약 35%)이다 | 같은 화면들 | 단계 칸 36pt(폭의 9%), 퀴즈 칸 44pt(11%). 본 사례의 절반 크기 | 확인(눈대중) |
| 3 | **이웃 칸의 좌우 이동이 작다.** Duolingo는 칸 가운데가 화면 폭의 약 0.31~0.62 사이에서 움직이고, 이웃한 칸끼리는 폭의 약 7~15%만 옮긴다. 캔디 크러시 새 지도(2023~)는 이웃 칸 이동이 폭의 10% 이하로 거의 곧다. 크게 지그재그하는 것은 LingoDeer(약 0.2 ↔ 0.8)와 Mimo(3열 격자)다 | Duolingo, 캔디 크러시(2017·2023·현재 화면 비교), LingoDeer, Mimo | 칸이 0.30 ↔ 0.70을 번갈아 밟아 이웃 칸마다 폭의 40%(161pt)를 옮긴다. LingoDeer 쪽에 가깝다 | 확인(눈대중) |
| 4 | **한 화면에 칸 5~6개.** 학습 앱 길형은 상단 띠와 탭 바 사이에 칸이 5~6개 보인다(Duolingo 6, LingoDeer 5~6, Speak 5, Mimo 6, Duolingo ABC 5~6). 칸 사이 세로 간격은 Duolingo에서 약 100~110pt. 게임은 더 촘촘하다(캔디 크러시 새 지도 8~10, 옛 지도 13 이상) | 같은 화면들 | 한 화면에 세션 칸 3개 + 건물 1개. 간격 128pt, 장면 사이 248pt. 첫 화면 아래 30%는 곧은 선과 출발 표지뿐이다 | 확인(눈대중) |
| 5 | **단원은 위에 붙는 띠 하나로 말한다.** Duolingo는 화면 맨 위에 단원 색으로 채운 띠("SECTION 4, UNIT 1" + 단원 제목 + 안내서 버튼)가 붙어 있고, Speak는 "UNIT 1 / Starting a Conversation" + 안내서 아이콘, Mimo는 "Intro to Web Development 0%" 알약, Busuu는 "Chapter 1 · 1/4 lessons completed"다. 길 안에 단원 이름을 따로 적지 않는다 | Duolingo(2022 그림, 2026 화면), Speak, Mimo, Busuu | 위에는 "히라가나 0/8"(지역 전체)만 있고, 장면 이름은 길 가운데 건물 카드 아래 글자로 있다. 지금 장면이 무엇인지는 건물이 화면에 보일 때만 알 수 있다 | 확인 |
| 6 | **단원의 큰 그림은 길 밖에, 화면 폭을 다 쓴다.** Duolingo ABC는 단원 경계에 화면 폭 전체의 건물·문 그림을 두고 길은 그 위에서 다시 시작한다. 캔디 크러시는 랜드마크를 길 양옆 가장자리에 두고 길 위에는 칸만 둔다. 게임 지도 제작 글도 "칸은 맨 위 층, 키 큰 건물은 옆으로, 구역 사이는 구름으로 가린다"고 정리한다. 길 한가운데에 작은 그림 카드를 칸처럼 끼워 넣은 사례는 보지 못했다 | Duolingo ABC, 캔디 크러시, Junxue Li(Game Developer 2014~2016) | 96pt(지금 장면)·72pt 건물 카드가 길 가운데(x 0.5)에 칸과 같은 줄로 서 있고 길 선이 카드 위아래로 지나간다 | 확인 + 글 |
| 7 | **캐릭터는 길 옆에 선다.** Duolingo는 Duo가 길이 휘어 생긴 빈 쪽(칸에서 폭의 약 25% 옆)에 서고 말풍선이 없다. Finch는 화면 위 40%를 캐릭터의 방으로 따로 떼고 목록은 그 아래에 둔다. 캐릭터가 지금 칸 위에 올라선 것은 Duolingo ABC(받침대 위의 Duo)와 캔디 크러시(칸 옆에 붙은 프로필 틀)다. 길 위 캐릭터가 여러 줄 말풍선을 늘 달고 있는 사례는 보지 못했다 | Duolingo, Finch, Duolingo ABC, 캔디 크러시 | 기리 96pt가 지금 칸 위에 서고 옆에 2~3줄 말풍선(폭 약 205pt)이 늘 보인다. 말풍선이 화면에서 가장 큰 테두리 상자다 | 확인 |
| 8 | **지금 칸은 칸 자체를 바꿔 표시한다.** Duolingo: 칸 둘레 고리 + (2022년 그림에서는) "START" 꼬리표. Speak: 파랗게 채우고 맥박. LingoDeer: 노랑 + 번짐. Mimo: 보라 테 + "1/2". Busuu: 그 줄만 떠오른 카드. 잠긴 칸은 모두 회색 한 가지(+자물쇠)이고 완료 칸은 단원 색 + 체크다. 색은 "단원 색 하나 + 회색 + 바탕"으로 끝난다 | 같은 화면들 | 지금 칸은 원을 그리지 않고 노랑 발판 + 기리로 표시한다. 완료·잠김 칸은 둘 다 크림색 원에 테만 다르다(테 색과 아이콘으로 구분) | 확인 |
| 9 | **칸에 글자를 붙이지 않거나, 붙이면 칸마다 같은 자리에 붙인다.** Duolingo·Mimo·Duolingo ABC·캔디 크러시는 칸 옆 라벨이 없다(칸 안의 아이콘이나 번호뿐). 라벨이 있는 LingoDeer는 "단원 이름 + 0/3"을 칸 안쪽 옆에, Busuu는 왼쪽 원 + 오른쪽 글자로 줄을 맞춘다. Speak는 글자를 칸 안에 넣었다 | 같은 화면들 | 칸 옆(지도 가운데 쪽)에 가나 라벨. 칸이 좌우를 오가므로 라벨도 왼쪽·오른쪽을 오간다 | 확인 |
| 10 | **시작은 칸에서 한다.** 길형은 칸을 누르면 칸에 붙은 팝오버가 뜨고 그 안에 시작 버튼이 있다(Duolingo, Speak). LingoDeer는 칸 → 단원 화면(레슨 카드 목록). 길형 홈에 아래 고정 "시작" 버튼을 함께 둔 사례는 보지 못했다. 아래 고정 영역은 탭 바(4~6칸)가 차지한다. 큰 시작 버튼이 있는 것은 카드형(Babbel "Start lesson", Imprint "Continue")이고 버튼은 카드 안에 있다 | Duolingo(공식 글 + 그림), Speak(도움말 + 그림), LingoDeer, Babbel, Imprint | 칸을 누르면 칸 카드, 아래에는 늘 [꾸미기][시작] 고정 버튼. 탭 바는 없다. 같은 시작이 칸과 아래 버튼 두 곳에 있다 | 확인 |
| 11 | **보상·곁가지는 길의 한 칸이거나 가장자리 아이콘이다.** Duolingo는 보물 상자를 칸 하나로 길에 넣고, 캔디 크러시는 이벤트 아이콘을 좌우 가장자리 세로 줄에 모은다(2022~2023 개편의 목표가 "읽기 쉽게, 기능은 필요할 때만 지도에 나타나게"). 완료한 구간에 수집품을 붙여 두는 사례는 보지 못했다 | Duolingo, 캔디 크러시(PocketGamer.biz 2026-01) | 완료한 장면의 건물 양옆에 단어 그림 스티커 2장 | 확인 + 글 |
| 12 | **길형의 약점은 단조로움과 전체가 안 보이는 것.** Duolingo 길 개편에 대한 대표 비판은 "같은 동전이 끝없이 이어지고 누를 것은 초록 칸 하나뿐", "지금까지 한 것이 한눈에 안 보인다"였다. Duolingo는 지금 구역(섹션) 목록 화면(구역마다 캐릭터 한 컷 + 진행 막대 카드)을 따로 두고, 길을 벗어나면 "지금 칸으로" 화살표를 띄운다 | Ilya Birman(2023), Duolingo 블로그(2022-05, 2026-10), 캔디 크러시 UX 글 | 장면 8개라 전체 길이 4,384pt(약 6.6화면). "지금 칸으로" 캡슐이 이미 있다 | 글 + 확인 |

해석(조사 담당의 읽기, 결정 아님):

- 지금 화면이 본 사례와 가장 크게 다른 곳은 1~3번이다. 본 사례는 "큰 칸이 촘촘히, 조금씩만 옆으로 옮겨 가며" 서 있어 선 없이도 길로 읽히고, KanaTrip은 "작은 칸이 멀리 떨어져 있어" 선이 길을 대신 그린다. 2026-11-18 정리에서 칸을 56 → 36pt로 줄인 것은 본 사례와 반대 방향이다.
- 장면이 8개, 장면당 세션이 3개뿐이라는 점은 본 사례(단원당 칸 5~10개 이상)와 다르다. 칸이 적은 구성에 가까운 것은 Busuu(장 하나에 레슨 4개 + 체크포인트)와 Babbel(오늘 레슨 카드 1 + 작은 카드 3)이다.
- 6·7·11번에서 "보지 못했다"고 적은 세 가지(길 가운데 그림 카드, 늘 떠 있는 말풍선, 구간 옆 스티커)는 모두 사용자가 2026-11-17에 정한 것과 닿아 있다. 영향: 이것들을 바꾸려면 사용자 확인이 필요하다. 바꾸지 않더라도 놓는 자리(길 밖 가장자리, 위 띠, 화면 폭 그림)는 본 사례에서 빌릴 수 있다.

## 2. 유형 정리

| 유형 | 모양 | 대표 사례 | 장점 | 단점 |
|---|---|---|---|---|
| A. 세로 길형 | 큰 칸이 세로로 이어지고 좌우로 조금씩 옮긴다. 위에 단원 띠, 아래 탭 바. 칸 → 팝오버 → 시작 | Duolingo(2022~), Speak(2025~), LingoDeer(2022-09~), Mimo, Duolingo ABC, 캔디 크러시 | 다음에 할 것이 하나로 정해진다(Duolingo가 밝힌 개편 이유). 진행이 "이동"으로 느껴진다. 캐릭터·보상 칸을 끼우기 쉽다 | 단조롭다, 전체가 안 보인다, 고를 수 없다는 비판(Duolingo). 칸이 적으면 길이 비어 보인다. 장식을 얹을수록 읽기 어려워져 캔디 크러시도 2022~2023년에 덜어 냈다 |
| B. 세로 타임라인 목록형 | 왼쪽에 곧은 선과 원, 오른쪽에 제목 글자. 지금 줄만 카드로 떠오르거나 펼쳐진다 | Busuu(장 → 레슨 줄 → 체크포인트 카드), Headspace Today("Your essentials" 4줄, 첫 줄만 큰 카드), Mondly(단원 안 레슨 목록, 지금 줄에만 Start) | 글자를 줄 맞춰 읽을 수 있다. 칸이 적어도 어색하지 않다. 좌우로 시선이 흔들리지 않는다 | 게임 느낌이 약하다. 캐릭터가 설 자리가 줄 밖(머리 그림)뿐이다 |
| C. 오늘의 한 가지 카드형 | 인사말 + 연속 기록 + 큰 카드 하나(그림 + 시작 버튼) + 그 아래 작은 카드 줄 | Babbel Today 탭, Imprint, Finch(위 40% 캐릭터 방 + 아래 오늘 목록), Khan Academy Kids(큰 재생 버튼, 글로만) | 첫 화면에서 할 일이 하나로 보인다. 그림을 크게 쓸 수 있다. 캐릭터에 전용 자리를 줄 수 있다(Finch) | 전체 여정과 지금 위치가 안 보여 따로 화면이 필요하다(Babbel은 "Learning plan" 탭). 진행의 재미가 카드 밖에 있어야 한다 |
| D. 표·격자형 | 글자표나 주제 격자를 그대로 홈으로 쓴다. 배운 칸에 색이 찬다 | MARU(오십음표를 "줄 단위로 열기"), Kana - Hiragana and Katakana(글자 카드 + 통계), Duolingo 옛 트리(~2022, 줄마다 1~3개 원 + 아래 이름) | 가나처럼 전체가 정해진 내용은 한눈에 다 보인다. 고를 수 있다 | 다음에 무엇을 할지 스스로 정해야 한다(Duolingo가 트리를 버린 이유). 장면·여행 같은 이야기를 담기 어렵다 |

섞어 쓴 사례: Speak는 A인데 칸에 글자를 넣어 B처럼 읽힌다. Finch는 C인데 캐릭터 방이 화면 위쪽을 차지한다. Duolingo는 A의 길 + 구역 목록 화면(C에 가까운 카드)을 따로 둔다.

## 3. 사례 표

"본 것"의 번호는 조사 질문의 1~8이다(1 요소 수·색, 2 길 모양·칸, 3 단원 구분, 4 현재 위치·상태, 5 누르면·주 버튼, 6 캐릭터·장식, 7 상단·하단, 8 평가·개편 이유).

### 3.1 세로 길형

| 앱 | 화면에서 본 것 | 본 것 | 확인 수준 | 출처 |
|---|---|---|---|---|
| Duolingo (지금 길, 2026-10 화면) | 흰 바탕. 위: 깃발·연속·보석·구독 표시 한 줄 + 하늘색 단원 띠("SECTION 4, EXTRA UNIT 1" + 제목). 가운데: 칸 6개(하늘색 4, 보물 상자 1, 회색 1), 길 선 없음, 칸 지름 폭의 약 19%, 칸 가운데 x 약 0.31~0.62, 세로 간격 약 100~110pt. 지금 칸은 둘레에 고리. 캐릭터 Duo 하나가 길 오른쪽 빈 곳에, 아래에 옅은 별 3개. 아래: 탭 6개. 색은 단원 색(하늘) + 회색 + 흰색 + 캐릭터 초록. 테두리 선은 거의 없고 칸 아래쪽 두께로 입체만 준다 | 1 2 3 4 6 7 | 스크린샷 직접 확인 | [S1] |
| Duolingo (2022 개편 전후 그림) | 전: 줄마다 원 1~2개 + 아래 이름("Basics 1", "Phrases"), 원 둘레 진행 고리와 왕관 숫자, 위 양옆 떠 있는 버튼 2개, 탭 5개. 후: 초록 단원 띠("Unit 1 / Use basic phrases, greet people" + 안내서 버튼), 금색 완료 칸 2 + 초록 지금 칸("START" 꼬리표, 둘레 진행 고리) + 회색 책 칸 + 회색 자물쇠 칸, Duo는 길 오른쪽 옆. 칸을 누르면 주제 정보 팝업. 길을 벗어나면 오른쪽 아래 떠 있는 화살표 | 1 2 3 4 5 6 7 8 | 공식 설명 그림(단순화한 그림) 직접 확인 + 글 | [S2] |
| Duolingo 구역 목록 | 구역마다 카드 하나: 위에 캐릭터 한 컷과 말풍선, 아래 "Section 4" + 점수 범위 + 진행 막대. 다음 구역 카드에는 "JUMP HERE" | 3 8 | 스크린샷 직접 확인 | [S1] |
| Speak (2025-12 홈 개편) | 위: 레벨 고르기, Course/Practice 전환, 연속. "UNIT 1 / Starting a Conversation" + 안내서 아이콘. 가운데: 글자가 든 알약 칸 5개가 조금씩 좌우로(이웃 이동 폭의 약 5~10%). 완료는 파랑 + 체크 배지, 지금은 파랑 + 번짐(도움말: "blue pulsing bubble"), 앞 칸은 흰색. 칸을 누르면 칸 바로 아래에 파란 팝오버(레슨 종류 3개 + Start). 오른쪽에 곁가지 아이콘 하나, 오른쪽 아래 떠 있는 튜터 버튼. 아래: 탭 5개. 색은 파랑 + 흰색 | 1 2 3 4 5 7 8 | 공식 도움말 그림 직접 확인 + 글 | [S3] |
| LingoDeer (2022-09 "single path") | 위: 메뉴, 로고, 알림, 할인 띠. 칸 5~6개가 크게 지그재그(x 약 0.2 ↔ 0.8), 옅은 회색 점선으로 이음. 칸 지름 폭의 약 20%. 칸 안쪽 옆에 "단원 이름 + 0/3". 지금 칸만 노랑 + 번짐, 나머지 회색. 오른쪽 위에 "Alphabet" 지름길 그림. 칸 → 단원 화면(레슨 카드 목록 + Tips + Story). 아래: 탭 4개 | 1 2 4 5 7 8 | 스크린샷 직접 확인(화면 모음 사이트, 찍은 날짜 미상) + 공식 업데이트 기록 | [S4] |
| Mimo | 위: 동전, 연속, 과정 이름. "Intro to Web Development 0%" 알약이 구획 머리. 모서리 둥근 네모 칸 6개가 3열로 꺾이며 가는 회색 선으로 이어짐. 지금 칸은 보라 테 + "1/2", 나머지는 옅은 회색 + 자물쇠·번개. 캐릭터·장식 없음. 아래: 탭 5개. 색은 보라 + 회색 | 1 2 3 4 7 | 스크린샷 직접 확인(화면 모음 사이트, 날짜 미상) | [S5] |
| Duolingo ABC (어린이) | 나무판 바탕 전체. 바탕보다 조금 진한 갈색 점선 길 + 둥근 자물쇠 칸(둘 다 바탕과 같은 갈색 계열이라 대비가 낮다) + 큰 네모 칸(책). 지금 칸에는 Duo가 파란 받침대 위에 서 있고, 완료 칸은 금색 체크 + 반짝임. 단원 경계는 화면 폭을 다 쓰는 건물·문 그림. 위 양쪽에 둥근 버튼 2개(뒤로, 목록). 탭 바 없음, 글자 없음 | 1 2 3 4 6 7 | 스크린샷 직접 확인(화면 모음 사이트, 날짜 미상) | [S6] |
| 캔디 크러시 사가 | 2D 옛 지도: 가로로 크게 굽이치는 길, 한 화면에 칸 14개 이상, 섬 그림 2개. 2017년 3D 지도: 지그재그, 칸 약 13개, 캐릭터가 길 옆에. 2023년 새 지도와 현재: 가운데 거의 곧은 넓은 길, 칸 8~10개(지름 폭의 약 13%, 번호 + 별), 랜드마크는 양옆 가장자리, 이벤트 아이콘은 좌우 가장자리 세로 줄, 지금 칸은 프로필 틀 + 큰 칸, 위에 에피소드 이름 띠("Candy Factory 5/15"), 아래 탭 3~5개. 2022년 개편 목표: 읽기 쉽게, 다니기 쉽게, 기능은 필요할 때만 지도에. 멀리 스크롤하면 지금 레벨로 가는 아이콘 | 1 2 3 4 6 7 8 | 팬 위키 스크린샷 직접 확인 + 기사 | [S7] [S8] [S9] |

### 3.2 타임라인 목록형·카드형·격자형

| 앱 | 화면에서 본 것 | 본 것 | 확인 수준 | 출처 |
|---|---|---|---|---|
| Busuu | 위: 언어, "A1 Beginner" + 진행 막대(22%). "Chapter 1 · 1/4 lessons completed". 왼쪽 곧은 세로 선에 원(사진) 3개, 오른쪽에 레슨 제목. 완료는 초록 테 + 체크, 지금 줄은 떠오른 흰 카드, 잠김은 회색 + 자물쇠. 장 끝 "Checkpoint"는 노란 카드. 아래 탭 4개. 2023-11 개편 글: 과정 화면에 "learning path"를 넣고 들어가는 단계를 줄임, "Next up" 버튼 | 1 2 3 4 7 8 | 스토어 홍보 그림 직접 확인(실제 화면과 다를 수 있음) + 글 | [S10] |
| Headspace (Today) | "Your essentials": 왼쪽 점선 + 점 4개, 첫 줄만 그림이 든 큰 카드("Day 1 / Getting Started"), 나머지 3줄은 한 줄짜리 낮은 카드. 그 아래 다른 묶음. 떠 있는 탭 바 3칸 | 1 2 4 7 | 스크린샷 직접 확인(화면 모음 사이트, 날짜 미상). 2026-06 Today 개편 도움말은 열리지 않았다 | [S11] |
| Mondly (단원 안) | 위 큰 그림 + 요약 카드(단어·문장 수, 예상 시간) + 레슨 줄 목록. 지금 줄만 펼쳐져 Start 버튼이 보인다 | 2 4 5 | 스크린샷 직접 확인(날짜 미상). 홈 자체는 못 봄 | [S12] |
| Babbel (Today 탭) | "Hi, 이름" + Today/Learning plan 전환 + 활동 막대 + 단원 줄("Newcomer I (A1.1) · Unit 1 / Greet people and say goodbye") + 화면 폭 큰 카드 하나(사진 + "Start lesson") + 작은 카드 3개(Review, Lesson 3, Recap). 아래 탭 4개. 색은 주황 계열 하나. 테두리 선 없음 | 1 3 5 7 | 스크린샷 직접 확인(날짜 미상) | [S13] |
| Imprint | "Good Afternoon" + 요일 7칸 연속 기록 + 큰 과정 카드 하나("2% Complete" + Continue) + 아래 탐색. 탭 4개 | 1 5 7 | 스크린샷 직접 확인(날짜 미상) | [S14] |
| Finch | 화면 위 약 40%가 캐릭터의 방(캐릭터는 방 안에 혼자). 그 아래 모험 에너지 막대, "6 goals left for today", 할 일 줄(오른쪽 체크 버튼). 아래 탭 6개. 비평 글은 퀘스트·설정 화면이 "할 수 있는 것이 너무 많아 결정 피로"라고 지적 | 1 6 7 8 | 스크린샷 직접 확인(날짜 미상) + 비평 글 | [S15] |
| MARU (가나) | 홈은 큰 마스코트 + 시계. 학습 화면은 5열 오십음표, "Unlock Row by Row", 배운 칸에 색 | 2 4 6 | 스토어 홍보 그림 직접 확인 | [S16] |
| Kana - Hiragana and Katakana | 글자 카드, 퀴즈 범위 설정, 통계 그래프. 길·지도 없음 | 2 | 스토어 홍보 그림 직접 확인 | [S17] |
| Khan Academy Kids | 가로 화면 앱. 홈에 큰 시작 버튼(안내 캐릭터 Kodi)과 왼쪽 위 Library 아이콘이 있다고 여러 글이 말한다(버튼 모양 설명은 글마다 다름) | 5 6 | 글로만 확인(검색 결과 요약. 공식 도움말은 열리지 않았다). 약함 | [S18] |
| Memrise | 2025-05 예고 글: "명확함과 자신감에 초점을 둔" 새 홈. 모양 설명 없음 | 8 | 글로만 확인 | [S19] |

### 3.3 공개된 평가·개편 이유

| 대상 | 내용 | 구분 | 출처 |
|---|---|---|---|
| Duolingo 트리 → 길 (2022) | 이유: 학습자가 "올바르게 쓰고 있는지" 확신하지 못해 더 분명히 안내하려고, 복습을 길에 섞으려고(간격 반복). 단원 이름을 "City 3" 대신 "get directions"처럼 하는 일로 적음. 수치(A/B 결과)는 글에 없다 | 글(공식) | [S2] |
| 같은 개편, 주주 서한 | 새 사용자가 "어떻게 진도를 나가야 할지 헷갈려" 해서 단순화, 일부 새 사용자 실험에서 "encouraging results"(수치 없음) | 글(검색 결과 요약으로만 확인, 원문은 열지 않음). 약함 | [S20] |
| 같은 개편, 비판 | 고를 수 없게 됐다는 반발과 청원. "같은 동전이 끝없이 이어지고 정보가 거의 없다", "한 것이 안 보인다" | 글 | [S21] [S22] |
| Duolingo 주요 탭 정리 (2026-02) | 문제: 탭마다 머리 크기·글자 위계·간격이 달랐다. 한 것: 머리 크기를 목적별 단계로, 글자 스타일 수 줄임, **상자로 감싸는 대신 여백으로 구분**, 카드 평평하게. 머리의 큰 그림은 "목적이 있는가"를 따짐. 결과: 탭 참여 증가(수치 없음) | 글(공식) | [S23] |
| Duolingo 미니 유닛 (2026-03) | 긴 단원이 "반복적이고 추상적"이라는 의견으로 단원을 칸 8개로 줄임 | 글(공식) | [S24] |
| 캔디 크러시 지도 (2022) | 읽기 쉽게, 다니기 쉽게, 기능은 관련 있을 때만 지도에 나타나게, 더 살아 있게 | 글(기사 속 설명) | [S8] |
| 게임 지도 제작 (2014~2016) | 세로 스크롤이 모바일에서 가장 흔한 형식. 구역 하나(화면 1.5개 높이)에 칸 15~25개. 칸은 맨 위 층이라 길이 건물 뒤로 가지 않게, 큰 건물은 옆으로. 구역 사이는 구름·안개·바탕색 그라데이션 | 글(한 저자의 연재). 약함 | [S9] |
| Speak 홈 개편 (2025-12) | 어디에 있고 다음이 무엇이고 얼마나 왔는지 보이게 하려고 길로 바꿈 | 글(공식 도움말) | [S3] |

## 4. 지금 KanaTrip 화면과 나란히

`docs/review/map-sushi-light.png`(처음 상태)에서 센 값과 3번 표의 길형 사례.

| 항목 | KanaTrip (2026-11-21 화면) | 길형 사례(학습 앱 5개) |
|---|---|---|
| 한 화면의 세션 칸 | 3개(+ 건물 1) | 5~6개 |
| 칸 지름 / 화면 폭 | 9%(36pt), 11%(44pt) | 약 19~20%, Speak는 글자 든 알약 |
| 이웃 칸 좌우 이동 / 화면 폭 | 40% | Duolingo 7~15%, Speak 5~10%, LingoDeer 약 60%, Mimo 약 30% |
| 길 선 | 6pt 진갈색 / 4pt 베이지 실선 | 없음 2, 옅은 점선·가는 선 3 |
| 칸 라벨 | 칸 옆 가나(좌우 번갈아) | 없음 3, 칸 안쪽 옆 1, 칸 안 1 |
| 단원 표시 | 길 가운데 건물 카드 + 아래 이름 | 위에 붙는 띠 4, 화면 폭 그림 1 |
| 지금 칸 | 원 없음, 노랑 발판 + 캐릭터 | 칸에 색·고리·번짐 5 (그중 1은 캐릭터도 올라섬) |
| 캐릭터 | 지금 칸 위 96pt + 늘 보이는 말풍선 | 길 옆 1, 칸 위 1, 없음 3. 말풍선 0 |
| 주 버튼 | 아래 고정 [꾸미기][시작] | 칸 → 팝오버의 시작 2, 칸 → 다음 화면 1, 미확인 2 |
| 아래 고정 영역 | 버튼 2개 | 탭 바 4~6칸 4, 없음 1 |
| 상단 | 지역 진행 "히라가나 0/8" + 메뉴 | 연속·재화 한 줄 + 단원 띠 |
| 완료 구간의 꾸밈 | 건물 옆 스티커 2장 | 없음(완료 칸 색과 체크만) |

## 5. 찾지 못한 것, 확인하지 못한 것

- 앱을 설치해 써 보지 않았다. 스크롤 중 띠가 바뀌는 방식, 칸을 눌렀을 때의 움직임, 세션을 끝낸 뒤 홈으로 돌아오는 연출은 그림 한 장과 글로만 봤다.
- 화면 모음 사이트(screensdesign.com)의 스크린샷은 찍은 날짜가 적혀 있지 않다. 지금 버전과 다를 수 있다. Busuu·MARU·Kana는 스토어 홍보 그림이라 실제 화면을 다듬은 것일 수 있다.
- Duolingo 길 개편의 A/B 수치, 길형과 목록형을 견준 공개 실험 결과는 찾지 못했다. "효과가 있었다"는 말은 모두 수치 없는 회사 쪽 서술이다.
- Lingokids, Prodigy, Renshuu, Dr. Moku, Hiragana Quest, Drops·Memrise의 홈 화면은 보지 못했다(스토어 그림에 홈이 없거나 자료를 찾지 못함). Khan Academy Kids는 글로만 확인했고 가로 화면 앱이다.
- Headspace 2026-06 Today 개편 도움말, Duolingo 길 비평 글 2건(Medium, UX Collective)은 접근이 막혀 읽지 못했다.
- 가나 전용 앱 가운데 여행 장면·지도를 홈으로 쓰는 사례는 찾지 못했다. 본 2개는 모두 글자표·카드형이다. 스토어 검색 결과에 "마스코트가 안내하는 단계별 길"을 내세운 가나 앱(HiraKata)이 있었으나 화면은 보지 못했다.
- 장면 8개 × 칸 3개처럼 칸이 적은 길형 사례는 찾지 못했다. 본 길형은 모두 단원당 칸이 5개 이상이다.
- 수치는 800×600 화면에 줄여 띄운 그림에서 잰 눈대중이다. pt 값으로 옮긴 것(76~80pt, 100~110pt)은 폭 402pt 기기를 가정한 환산이다.

## 6. 출처 목록

모두 2026-11-21 확인. 이미지 주소는 직접 본 그림이다.

- [S1] Duolingo 블로그, "How to Review Previous Lessons on Duolingo" (2026-10-01). https://blog.duolingo.com/how-to-review-lessons-on-duolingo/ · 그림: https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/10/Review-lessons_path.png , https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2026/10/Review-lessons_current-unit.png
- [S2] Duolingo 블로그, "The Science Behind Duolingo's Home Screen Redesign" (2022-05-06, Holly Munson 외). https://blog.duolingo.com/new-duolingo-home-screen-design/ · 그림: https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2022/05/NEWV2Blog-Tree-Homescreen--2-.png , https://storage.ghost.io/c/7a/33/7a33d0f4-927d-4fe8-a6bf-96131b5e76d4/content/images/2022/05/NEWV2Blog-Tips-Guidebook--2-.png
- [S3] Speak 도움말, "Explore Your New Home Screen" (2025-12-18). https://help.speak.com/en/articles/11430473-explore-your-new-home-screen
- [S4] LingoDeer 화면 모음: https://screensdesign.com/showcase/lingodeer-learn-languages · LingoDeer 업데이트 기록(2022-09 "single path"): https://blog.lingodeer.com/update-log/
- [S5] Mimo 화면 모음: https://screensdesign.com/showcase/mimo-learn-codingprogramming · 그림: https://media.screensdesign.com/avs-pp-640/ce435fb7b6244a259ddacb714aab778d.webp
- [S6] Duolingo ABC 화면 모음: https://screensdesign.com/showcase/learn-to-read-duolingo-abc · 그림: https://media.screensdesign.com/avs-pp-640/6e44b246a68f4961a32a3bd82cfb4ecb.webp , https://media.screensdesign.com/avs-pp-640/4f18a041719742449fb293ce0103a424.webp , https://media.screensdesign.com/avs-pp-640/024adc3ab01b4db58523e6da6518d8f9.webp
- [S7] Candy Crush Saga Wiki, "Map"(팬 위키). https://candycrush.fandom.com/wiki/Map · 그림: https://static.wikia.nocookie.net/candy-crush-saga/images/3/32/Mobile-map.png , https://static.wikia.nocookie.net/candy-crush-saga/images/b/bc/Mobile-map-revamp.png , https://static.wikia.nocookie.net/candy-crush-saga/images/3/3e/Screenshot-2023-01-27-at-13-47-16.webp , https://static.wikia.nocookie.net/candy-crush-saga/images/e/e9/Bounceout_2532.png
- [S8] PocketGamer.biz, "Competitive or casual: designing Candy Crush with a spectrum of flavours" (2026-01-08). https://www.pocketgamer.biz/competitive-or-casual-designing-candy-crush-with-a-spectrum-of-flavours/ · 지금 레벨로 돌아가는 아이콘: https://uxdesign.cc/does-candy-crush-have-a-good-ux-3c1a865d24e (검색 결과 요약으로만 확인)
- [S9] Junxue Li, Game Developer 연재: "Mobile game maps: which format is right for you" (2014-11-19) https://gamedeveloper.com/production/mobile-game-maps-which-format-is-right-for-you · "The Maps of Mystery Match" (2015-09-24) https://www.gamedeveloper.com/production/the-maps-of-mystery-match-rich-and-classic · "All the saga map specifications you should know" (2016-12-07) https://gamedeveloper.com/design/all-the-saga-map-specifications-you-should-know
- [S10] Busuu App Store 페이지(다섯 번째 홍보 그림): https://apps.apple.com/us/app/busuu-language-learning-app/id379968583 · Busuu 블로그, 새 버전 안내(2023-11): https://blog.busuu.com/busuu-new-features/ (검색 결과 요약으로 확인)
- [S11] Headspace 화면 모음: https://screensdesign.com/showcase/headspace-meditation-sleep · 그림: https://media.screensdesign.com/avs-pp-640/e1a117c048a349d59fb1b24b9bd43ae5.webp
- [S12] Mondly 화면 모음: https://screensdesign.com/showcase/mondly-learn-41-languages · 그림: https://media.screensdesign.com/avs-pp-640/36645ad18d464a9695a040a303530529.webp
- [S13] Babbel 화면 모음: https://screensdesign.com/showcase/babbel-language-learning · 그림: https://media.screensdesign.com/avs-pp-640/75c435bf21834a199ce7fab1262d57b0.webp , https://media.screensdesign.com/avs-pp-640/3c21b0cfcd8346d4b27092179b2b04e0.webp
- [S14] Imprint 화면 모음: https://screensdesign.com/showcase/imprint-learn-visually · 그림: https://media.screensdesign.com/avs-pp-640/fd249d4701ea42ebb0bafa9481bc6dce.webp
- [S15] Finch 화면 모음: https://screensdesign.com/showcase/finch-self-care-pet · 그림: https://media.screensdesign.com/avs-pp-640/18a93d9cdc7541c1b53c4e54a131718c.webp · 비평 글(Pratt IXD, 2026-02-17): https://ixd.prattsi.org/2026/02/design-critique-finch-self-care-pet-ios-app/
- [S16] MARU App Store 페이지: https://apps.apple.com/us/app/maru-learn-japanese-hiragana/id1208009110
- [S17] Kana - Hiragana and Katakana App Store 페이지: https://apps.apple.com/us/app/kana-hiragana-and-katakana/id1454200955
- [S18] Khan Academy Kids 도움말 "How the Learning Path works": https://khankids.zendesk.com/hc/en-us/articles/360041615571 (열리지 않음, 검색 결과 요약만) · App Store: https://apps.apple.com/us/app/khan-academy-kids/id1378467217
- [S19] Memrise 블로그 (2025-05-30): https://www.memrise.com/blog/team-update-prototype
- [S20] Duolingo 2022년 1분기 주주 서한: https://investors.duolingo.com/static-files/d667f9d1-8f7f-418c-b116-e699a30a9826 (검색 결과 요약만)
- [S21] Ilya Birman, "How I stopped using Duolingo" (2023): https://ilyabirman.net/meanwhile/all/duolingo-no-more/
- [S22] PiunikaWeb, 길 UI 반발 기사(2022-10~12): https://piunikaweb.com/2022/10/17/duolingo-app-update-with-path-ui-faces-backlash-from-users/ (검색 결과 요약만)
- [S23] Duolingo 블로그, "Elevating craft: How we refreshed our core tabs" (2026-02-04): https://blog.duolingo.com/core-tabs-redesign
- [S24] Duolingo 블로그, 중급 미니 유닛 (2026-03-04): https://blog.duolingo.com/intermediate-mini-units
