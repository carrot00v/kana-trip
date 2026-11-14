# 단어 그림 목록 (히라가나 60단어)

- 작성: 2026-11-15, planner
- 근거: 사용자 지시(2026-11-15) "장면별 대표 단어·메뉴, 특히 여행 중 많이 보는 단어 위주로 그림을 그려 둔다. 돈카츠 그림은 기리 꾸미기 아이템에 넣지 말고 단어 학습할 때 보여 준다. 움직임은 Lottie로."
- 기준 문서: `PLAN.md` 3·4·5번, `docs/content/hiragana-allocation.md`(단어 60개, 뜻), `docs/content/giri-lines.md` 3번(단어 설명), `docs/design/item-art/brief.md`(화풍·색 규칙), `KanaTrip/Resources/rewards.json`
- 웹 조사 없이 썼다. 단어의 뜻과 현지 표기는 `hiragana-allocation.md` 4번을 그대로 따르고, 그 문서와 giri-lines.md에서 "확인 필요"인 단어는 여기서도 그렇게 표시했다. 조사 결과가 오면 우선순위를 다시 맞춘다.

## 0. 요약

| 우선순위 | 뜻 | 단어 수 | 새로 그릴 장수 | 기존 그림 복사 |
|---|---|---|---|---|
| 1 | 장면 대표, 여행 중 자주 봄 | 28 | 26 | 2 (tonkatsu, kitsune) |
| 2 | 그리면 도움이 됨 | 16 | 15 | 1 (ひのき ← word-ofuro) |
| 3 | 그림 없이 감 | 16 | 0 | |
| 합계 | | 60 | 41 | 3 |

- 우선순위 1을 장면마다 3~4개 두었다: 4, 4, 4, 3, 4, 3, 3, 3.
- 한 장에 5~15분이면 우선순위 1의 새 그림 26장은 약 2시간 10분~6시간 30분이다.
- 움직임(Lottie)을 붙일 추천 단어는 10개다 (5번).

## 1. 공통 규격

아이템 그림(`docs/design/item-art/brief.md` 1번)과 같은 화풍·색 규칙을 따르고, 슬롯 자리(targetBox, 쥐는 점)는 따르지 않는다.

| 항목 | 값 |
|---|---|
| 파일 이름 | `word-{로마자}` (예: `word-tonkatsu`). 로마자는 `hiragana-allocation.md`의 읽기에서 공백·장음 기호를 뺀 소문자. 장음 う는 그대로 쓴다(`houjicha`, 아이템 `youkan`과 같은 방식) |
| 형식·크기 | PNG 1024×1024, 생성은 옅은 회색 단색 바탕 → `tools/remove_bg.py`로 투명. 대상이 가운데, 둘레 여백 10% 정도 |
| 프롬프트 조립 | `tools/gen_item_art.py`의 `STYLE` + `PALETTE` + `"Subject: "` + 이 문서의 Subject + `OBJECT_RULES`. 아이템과 똑같이 조립하므로 Subject만 바꿔 넣으면 된다 |
| 한 장에 | 대상 하나(접시·그릇·꼬치처럼 그 음식을 알아보는 데 필요한 것까지). 탁자, 바닥, 배경, 사람, 손, 젓가락은 Subject에 적은 경우만 |
| 글자 | 그림 안에 글자·숫자를 그리지 않는다. 간판·표·버튼은 빈칸으로. `word-yu`만 빈 자리에 ゆ를 KanjiVG 획으로 합성한다(brief.md 1.2와 같은 방식) |
| 색 | 초록(125°~160°)과 분홍빨강(330°~359°)을 넓게 쓰지 않는다(brief.md 1.1). 참치·문어·사과 사탕의 빨강은 주황빨강 `#E2533F` 쪽으로, 미역은 김 색 `#34402F`나 MOSS 쪽으로 Subject에 적어 두었다. 파 고명처럼 작은 초록은 허용 |
| 움직이는 부분 | **정지 그림에 그리지 않는다.** 김, 가쓰오부시, 떨어지는 동전처럼 Lottie로 움직일 부분은 Subject에 "no steam" 등으로 빼 두었다. 정지 그림에 김이 그려져 있으면 Lottie 김과 겹친다 |
| 저장 위치 (제안) | `docs/design/word-art/source/word-{로마자}.png`와 같은 이름의 `.json`(프롬프트, 시드). item-art와 같은 구조. 앱 에셋 이름과 화면 크기는 developer·designer가 정한다 |

## 2. 단어 60개

열 설명:

- **그림**: 필요 / 없음. 우선순위 3은 없음.
- **우선순위**: 1 = 장면 대표·여행 중 자주 봄, 2 = 그리면 도움이 됨, 3 = 그림 없이 감(이유를 비고에 적음).
- **Subject**: 이미지 모델 프롬프트의 Subject에 그대로 넣는 영어 한 줄.
- **움직임 후보**: 실제로 움직이는 요소가 있을 때만 적었다. 5번의 추천은 이 가운데서 골랐다.
- **재사용**: 기존 그림을 복사해 쓰면 그 경로. 비어 있으면 새로 그린다.
- 장면 그림(`docs/design/scene-art/source/thumb-*.png`)과 같은 대상이 있지만(가츠동, 자루소바, 야키토리, 찻잔) 재사용하지 않는다. 장면 그림은 칸색 바탕과 김이 그려져 있고 52pt용 구도라서다.

### 2.1 장면 1 스시집

| 단계 | 단어 | 뜻 | 그림 | 우선순위 | 파일 | Subject | 움직임 후보 | 재사용 | 비고 |
|---|---|---|---|---|---|---|---|---|---|
| 1a | すし | 초밥 | 필요 | 1 | word-sushi | Two pieces of nigiri sushi side by side on a small low wooden geta board, one topped with a soft orange-red tuna slice and one with a yellow rolled egg omelet tied with a thin dark nori band, seen from the front and slightly above. | | | 장면 1a의 유일한 단어. 리워드 아이템 `sushi`(손)와 같은 대상 (4.3) |
| 1b | いか | 오징어 | 필요 | 1 | word-ika | One single piece of squid nigiri sushi: a pale off-white squid slice with fine diagonal score lines draped over an oval block of white rice, seen from the front and slightly above, no plate. | | | 1b 목표 단어 (い か까지 배우면 완성) |
| 1b | たこ | 문어 | 필요 | 1 | word-tako | One single piece of octopus nigiri sushi: a white octopus slice with a wavy plum-purple and soft orange-red skin edge over an oval block of white rice, seen from the front and slightly above, no plate. | | | 1b 목표 단어. 문어 껍질을 진홍·자주로 칠하지 않게 plum purple로 적음 |
| 1b | いくら | 연어알 | 필요 | 2 | word-ikura | One single gunkan sushi: an oval of white rice wrapped in a band of dark nori, heaped on top with round shiny orange salmon roe beads, seen from the front and slightly above, no plate. | | | |
| 1b | まぐろ | 참치 | 필요 | 1 | word-maguro | One single piece of tuna nigiri sushi: a thick soft orange-red tuna slice draped over an oval block of white rice, seen from the front and slightly above, no plate. | | | 회전초밥의 대표 메뉴. 빨강은 주황빨강으로 (분홍빨강 금지 색) |
| 1b | えび | 새우 | 필요 | 2 | word-ebi | One single piece of shrimp nigiri sushi: a butterflied cooked shrimp with soft orange-red and white stripes and a fanned tail, over an oval block of white rice, seen from the front and slightly above, no plate. | | | |
| 1b | いなり | 유부초밥 | 필요 | 2 | word-inari | One single inari sushi: a plump oval pouch of golden-brown sweet fried tofu stuffed with white rice, the rice showing at the open top, seen from the front and slightly above, no plate. | | | |

### 2.2 장면 2 돈카츠집

| 단계 | 단어 | 뜻 | 그림 | 우선순위 | 파일 | Subject | 움직임 후보 | 재사용 | 비고 |
|---|---|---|---|---|---|---|---|---|---|
| 2a | とんかつ | 돈가스 | 필요 | 1 | word-tonkatsu | (재사용. 원래 Subject는 `item-art/source/tonkatsu.json`) | | `docs/design/item-art/source/tonkatsu.png` 복사 | 사용자 지시로 리워드 아이템에서 빼고 단어 그림으로 씀 (4.2) |
| 2a | かつ丼 | 돈가스덮밥 | 필요 | 1 | word-katsudon | A dark indigo donburi bowl of rice topped with sliced golden tonkatsu simmered in soft yellow egg and thin onion strips, a few small moss olive leaves on top, seen from the front and slightly above, no lid, no chopsticks, no steam. | 김 | | 장면 그림(thumb-tonkatsu)도 가츠동이지만 김·젓가락이 그려져 있어 새로 그림 |
| 2b | ひれかつ | 안심 돈가스 | 필요 | 1 | word-hirekatsu | Three thick round medallions of pork fillet cutlet with jagged golden panko crust, the front piece cut open to show pale pink-white meat, standing close together, seen from the front and slightly above, no plate, no cabbage. | | | 2b 목표 단어. word-tonkatsu(길쭉한 한 조각)와 모양이 달라야 한다: 두툼한 동그란 조각 |
| 2b | おろし | 간 무를 올린 | 필요 | 2 | word-oroshi | A round golden panko-crusted fillet cutlet with a small white mound of grated daikon radish on top and a few thin moss olive scallion rings, seen from the front and slightly above, no plate. | | | 단독 품명이 아니라 앞에 붙는 말(おろしひれかつ). 그림은 "간 무를 올린 돈가스" |
| 2b | ごはん | 밥 | 필요 | 1 | word-gohan | A small round dark indigo rice bowl filled with a soft dome of white rice, seen from the front and slightly above, no chopsticks, no steam. | 김 | | 여행 중 정식마다 나오는 말 |
| 2b | おかわり | 리필 | 없음 | 3 | | | | | 행동을 가리키는 말이라 그림(빈 그릇, 밥통)이 "그릇", "밥"으로 읽힌다. 아이템 おひつ와도 헷갈림 |

### 2.3 장면 3 소바·우동집

| 단계 | 단어 | 뜻 | 그림 | 우선순위 | 파일 | Subject | 움직임 후보 | 재사용 | 비고 |
|---|---|---|---|---|---|---|---|---|---|
| 3a | うどん | 우동 | 필요 | 1 | word-udon | A deep round dark indigo bowl of hot udon: thick glossy white udon noodles in light brown broth with a few thin moss olive scallion rings, seen from the front and slightly above, no chopsticks, no steam. | 김 | | 굵고 흰 면. word-soba와 면 굵기·색으로 구분 |
| 3a | そば | 메밀국수 | 필요 | 1 | word-soba | A deep round dark indigo bowl of hot soba: thin light brown buckwheat noodles in dark brown broth with a few thin moss olive scallion rings, seen from the front and slightly above, no chopsticks, no steam. | 김 | | 가는 갈색 면. 면에 옅은 회색을 쓰면 바탕 지우기에서 지워질 수 있어 light brown으로 적음 |
| 3b | きつね | 유부 올린 | 필요 | 1 | word-kitsune | (재사용. 원래 Subject는 `item-art/source/kitsune.json`) | 김 | `docs/design/item-art/source/kitsune.png` 복사 | 김이 그려져 있지 않아 Lottie 김을 얹을 수 있다. 리워드 아이템 `kitsune`(손)와 같은 그림 (4.3) |
| 3b | かけ | 국물만 부은 기본 | 없음 | 3 | | | | | 고명 없는 소바·우동이라 그림이 word-udon, word-soba와 같아진다. "아무것도 안 올린"은 그림으로 드러나지 않는다 |
| 3b | おかめ | 어묵 등을 올린 | 필요 | 2 | word-okame | A deep round dark indigo bowl of soba topped with several separate toppings arranged in a ring: pink-and-white kamaboko fish cake slices, a brown simmered shiitake, a yellow omelet slice, seen from the front and slightly above, no steam. | 김 | | **확인 필요.** 고명 구성은 해설 기사 한 곳뿐이다(giri-lines.md). 확인 뒤 그린다. 고명을 얼굴 모양으로 놓지 않는다(물건에 얼굴 금지) |
| 3b | わかめ | 미역 올린 | 필요 | 2 | word-wakame | A deep round dark indigo bowl of hot udon with thick white noodles, topped with a heap of dark olive (#34402F) wakame seaweed, seen from the front and slightly above, no steam. | 김 | | 미역은 초록이 넓어지기 쉬워 김 색으로 적음 |
| 3b | たぬき | 튀김 부스러기 올린 | 필요 | 2 | word-tanuki | A deep round dark indigo bowl of hot soba with thin light brown noodles, topped with a heap of small crunchy golden tempura bits and a few scallion rings, seen from the front and slightly above, no steam. | 김 | | 간토 기준 그림. 간사이에서는 가리키는 것이 다르다(giri-lines.md) |
| 3b | ざる | 채반에 담은 찬 면 | 필요 | 1 | word-zaru | A square flat bamboo slatted zaru tray in warm wood brown with a neat heap of cold thin light brown soba noodles on it and a few thin dark nori strips on top, seen from the front and slightly above, no dipping cup. | | | 장면 그림(thumb-soba)도 자루소바지만 칸색 바탕이라 새로 그림 |

### 2.4 장면 4 역

| 단계 | 단어 | 뜻 | 그림 | 우선순위 | 파일 | Subject | 움직임 후보 | 재사용 | 비고 |
|---|---|---|---|---|---|---|---|---|---|
| 4a | えき | 역 | 필요 | 1 | word-eki | A small Japanese local train station building seen from the front: pale cream walls, a dark indigo tiled roof, a round clock above the open entrance, a blank plain board where the station name would be. | | | 리워드 배경 `eki`(승강장)와 대상이 겹치지만 구도가 다르다 (4.1 규칙 2) |
| 4a | おつり | 거스름돈 | 필요 | 1 | word-otsuri | A small rounded metal change tray in pale sky blue holding three Japanese coins: one warm yellow coin with a round center hole and two pale cream silver coins, seen from the front and slightly above, no numbers on the coins. | 떨어짐 (동전) | | 발매기·자판기에서 늘 보는 말. 확인 필요(hiragana-allocation.md [지식]) |
| 4a | きっぷうりば | 표 파는 곳 | 필요 | 1 | word-kippuuriba | A Japanese train ticket vending machine seen from the front: a pale cream boxy machine with a blank pale sky blue touch screen, a round coin slot, a narrow ticket slot, and a few blank round buttons, no text, no numbers. | | | 아이템 `kippu`(표 한 장)를 쓰면 "표"로 읽혀 "파는 곳"이 드러나지 않는다 |
| 4b | のりかえ | 환승 | 없음 | 3 | | | | | 갈아탐이라는 행동이라 그림(전철 두 대, 화살표)이 "전철"로 읽힌다 |
| 4b | こちら | 이쪽 | 없음 | 3 | | | | | 방향을 가리키는 기능어. 화살표 그림은 어느 쪽이 맞는지 오해를 만든다 |
| 4b | のりば | 타는 곳 | 필요 | 2 | word-noriba | A short section of a train platform edge with a yellow tactile paving strip, and the side of a pale cream commuter train with an open door stopped beside it, seen from the front at a slight angle, no signs. | | | word-eki와 구분되게 승강장 끝과 열린 문 |
| 4b | でぐち | 출구 | 없음 | 3 | | | | | 문 그림은 입구와 출구가 같아진다. 표지판의 글자 자체가 뜻이라 그림이 뜻을 흐린다 |
| 4b | いりぐち | 입구 | 없음 | 3 | | | | | でぐち와 같은 이유 |

### 2.5 장면 5 신사·축제

| 단계 | 단어 | 뜻 | 그림 | 우선순위 | 파일 | Subject | 움직임 후보 | 재사용 | 비고 |
|---|---|---|---|---|---|---|---|---|---|
| 5a | おまもり | 부적 | 필요 | 1 | word-omamori | One small Japanese omamori charm: a flat rectangular soft orange-red brocade pouch with a simple warm yellow pattern and a pointed top tied with a looped cord and knot, front view, upright, blank front with no characters. | 흔들림 (끈) | | 확인 필요(현지 표기). 예전 리워드 아이템 후보였으나 빠져 그림이 없다 |
| 5a | おまいり | 참배 | 없음 | 3 | | | | | 행동을 가리키는 말. 새전함·방울 그림은 "새전함", "방울"로 읽힌다 |
| 5a | おみくじ | 운세 제비 | 필요 | 1 | word-omikuji | Several narrow white paper fortune slips folded lengthwise and tied in knots along a short horizontal warm wood brown rail, front view, blank paper with no writing. | 팔랑임 (종이) | | 확인 필요(현지 표기). 신사에서 묶어 둔 모습 |
| 5a | えんむすび | 인연 맺기 | 없음 | 3 | | | | | 기원을 가리키는 추상어. 하트·붉은 실 그림은 "사랑", "실"로 읽힌다 |
| 5b | たこやき | 다코야키 | 필요 | 1 | word-takoyaki | Six round takoyaki balls in a boat-shaped warm wood brown tray, covered with dark brown sauce and thin white mayonnaise zigzags, a few tiny moss olive aonori flakes, one wooden pick, seen from the front and slightly above, no bonito flakes, no steam. | 가쓰오부시 흔들림, 김 | | 축제 노점의 대표. 가쓰오부시는 Lottie 레이어로 얹으므로 정지 그림에서 뺌 |
| 5b | おまつり | 축제 | 필요 | 2 | word-omatsuri | One round paper chochin lantern in soft orange-red with a pale cream band at the top and bottom, hanging from a short cord, front view, blank with no characters. | 흔들림, 불빛 깜박임 | | 확인 필요(현지 표기). 축제 자체는 장면이라 노점 초롱 하나로 대신함 |
| 5b | あたり | 당첨 | 없음 | 3 | | | | | 제비뽑기 결과. 제비 그림은 あたり와 はずれ가 같아져 뜻을 흐린다 |
| 5b | やきそば | 볶음국수 | 필요 | 2 | word-yakisoba | A heap of brown sauce-fried yakisoba noodles with small pieces of cabbage and a little soft orange-red pickled ginger on top, in a rectangular white paper food tray, seen from the front and slightly above, no steam. | 김 | | |
| 5b | はずれ | 꽝 | 없음 | 3 | | | | | あたり와 같은 이유 |
| 5b | りんごあめ | 사과 사탕 | 필요 | 1 | word-ringoame | One whole candy apple coated in a smooth soft orange-red candy shell, on a straight wooden stick pointing down, upright, front view. | | | 노점 깃발 근거 있음. 빨강은 주황빨강으로 |

### 2.6 장면 6 이자카야

| 단계 | 단어 | 뜻 | 그림 | 우선순위 | 파일 | Subject | 움직임 후보 | 재사용 | 비고 |
|---|---|---|---|---|---|---|---|---|---|
| 6a | やきとり | 닭꼬치 | 필요 | 1 | word-yakitori | One bamboo skewer with four glazed grilled chicken pieces in warm brown, upright with the bare stick end at the bottom, front view, no plate. | 김 (연기) | | 장면 그림(thumb-izakaya)은 접시 위 여러 꼬치. 단어 그림은 꼬치 하나 |
| 6a | つくね | 다진 닭고기 꼬치 | 필요 | 1 | word-tsukune | One bamboo skewer with a single long oval glazed chicken meatball in shiny dark brown sauce, upright with the bare stick end at the bottom, front view, no plate. | | | word-yakitori와 구분되게 길쭉한 경단 하나 |
| 6a | かわ | 닭껍질 꼬치 | 필요 | 2 | word-kawa | One bamboo skewer threaded with wavy, crispy golden-brown folded chicken skin, upright with the bare stick end at the bottom, front view, no plate. | | | |
| 6a | むね | 닭가슴살 | 없음 | 3 | | | | | 꼬치로 그리면 word-yakitori와 구분되지 않는다. 메뉴 이름 앞에 붙는 꼴이라 단독 그림이 맞지 않음 |
| 6b | ささみ | 닭안심 | 없음 | 3 | | | | | 꼬치로 그리면 word-yakitori와 구분되지 않는다 |
| 6b | なんこつ | 오돌뼈 | 없음 | 3 | | | | | 꼬치로 그리면 구분되지 않고, 연골을 크게 그리면 무엇인지 알기 어렵다 |
| 6b | しいたけ | 표고버섯 | 필요 | 2 | word-shiitake | One bamboo skewer with two grilled shiitake mushroom caps in warm brown, each cap with a cross-shaped cut on top, upright with the bare stick end at the bottom, front view, no plate. | | | |
| 6b | おにぎり | 주먹밥 | 필요 | 1 | word-onigiri | One grilled yaki onigiri: a rounded triangle of rice with a toasty golden-brown soy glaze and a few darker grill marks, no nori, front view, upright. | | | 기리(김 두른 흰 오니기리)와 헷갈리지 않게 구운 오니기리. 이자카야 마무리 메뉴(확인 필요) |
| 6b | うずら | 메추리알 꼬치 | 필요 | 2 | word-uzura | One bamboo skewer with four small boiled quail eggs, pale cream with a light brown glaze, upright with the bare stick end at the bottom, front view, no plate. | | | |

### 2.7 장면 7 온천

| 단계 | 단어 | 뜻 | 그림 | 우선순위 | 파일 | Subject | 움직임 후보 | 재사용 | 비고 |
|---|---|---|---|---|---|---|---|---|---|
| 7a | ゆ | 목욕탕 | 필요 | 1 | word-yu | A short dark indigo split noren curtain with two panels hanging from a thin warm wood brown rod, front view, with a large plain pale cream circle in the middle of the cloth left completely empty. | 흔들림 (노렌 아랫단) | | **그림 속 가나: ゆ.** 가운데 원에 KanjiVG 획으로 합성(brief.md 1.2). 리워드 배경 `yu`와 대상이 겹치지만 구도가 다르다(4.1 규칙 2). 확인 필요 |
| 7a | おんせん | 온천 | 필요 | 1 | word-onsen | A small round outdoor hot spring pool seen from the front and slightly above: a ring of rounded warm beige-brown stones around pale sky blue water, no people, no steam. | 김, 물결 | | 확인 필요(현지 표기). 돌에 옅은 회색을 쓰면 바탕 지우기에서 지워질 수 있어 beige-brown으로 적음 |
| 7a | ゆかた | 유카타 | 필요 | 1 | word-yukata | A cotton yukata robe with a simple dark indigo and white pattern, hung open flat on a horizontal warm wood brown kimono hanger with a narrow soft orange-red sash draped over it, front view. | 흔들림 | | 확인 필요(현지 표기) |
| 7b | ぬる湯 | 미지근한 탕 | 없음 | 3 | | | | | "미지근함"은 그림으로 드러나지 않는다. 그리면 word-onsen과 같아진다 |
| 7b | ひのき | 편백나무 | 필요 | 2 | word-hinoki | (재사용) | 김 | `word-ofuro` 복사 (2.8) | ひのき風呂(편백 욕조)로 쓰는 말이라 word-ofuro의 편백 욕조를 같이 쓴다. 새로 그리지 않음 |
| 7b | くつをぬいでください | 신발을 벗어 주세요 | 필요 | 2 | word-kutsuonuide | A small section of a Japanese entrance: a low stone floor with a pair of sneakers placed neatly side by side, and a raised warm wood brown step behind it with a pair of pale cream slippers on top, seen from the front at a slight angle. | | | 공통 끝 문장(OBJECT_RULES)의 "no floor"를 뺀다. 단(段)이 뜻이라 필요. 문구 처리는 PLAN.md 8번 미정 |

### 2.8 장면 8 료칸

| 단계 | 단어 | 뜻 | 그림 | 우선순위 | 파일 | Subject | 움직임 후보 | 재사용 | 비고 |
|---|---|---|---|---|---|---|---|---|---|
| 8a | ようこそ | 환영합니다 | 없음 | 3 | | | | | 인사말. 절하는 사람 그림은 금지(사람 없음)이고 다른 그림은 뜻을 흐린다 |
| 8a | おもてなし | 환대 | 없음 | 3 | | | | | 추상어 |
| 8a | ほうじ茶 | 호지차 | 필요 | 1 | word-houjicha | One cylindrical Japanese yunomi teacup without a handle, pale cream with a thin dark indigo band, filled with reddish warm brown roasted tea, seen from the front and slightly above so the tea surface shows, no saucer, no steam. | 김 | | 장면 그림(thumb-ryokan)은 찻주전자와 찻잔. 단어 그림은 찻잔 하나 |
| 8b | おふろ | 욕실, 목욕 | 필요 | 1 | word-ofuro | A square Japanese bathtub made of pale warm wood planks (hinoki cypress), filled with pale sky blue water, a small round wooden bucket resting on the rim, seen from the front and slightly above, no steam. | 김 | | ひのき(2.7)가 이 그림을 같이 쓴다 |
| 8b | おへや | 객실 | 필요 | 2 | word-oheya | A low square warm wood brown Japanese table with a small teapot and one teacup on it and two flat square floor cushions beside it, resting on a single pale tatami mat, seen from the front and slightly above, no walls. | | | 공통 끝 문장의 "no floor"를 뺀다(다다미 한 장이 뜻의 일부) |
| 8b | ふとん | 이불 | 필요 | 1 | word-futon | A Japanese futon bed laid flat, seen from the front and slightly above at an angle: a white mattress, a dark indigo patterned quilt folded back halfway, and a small rectangular pillow. | | | |

## 3. 그리는 순서

`gen_item_art.py`와 같은 방식(한 번에 한 장, 후보 여러 장 → 사람이 고름)을 가정했다. 복사는 생성 없이 파일만 옮긴다.

### 3.1 우선순위 1 (28개: 새로 26, 복사 2)

| 순서 | 장면 | 파일 | 할 일 |
|---|---|---|---|
| 1 | 1 스시집 | word-sushi | 생성 |
| 2 | 1 스시집 | word-ika | 생성 |
| 3 | 1 스시집 | word-tako | 생성 |
| 4 | 1 스시집 | word-maguro | 생성 |
| - | 2 돈카츠집 | word-tonkatsu | 복사 (`item-art/source/tonkatsu.png`) |
| 5 | 2 돈카츠집 | word-katsudon | 생성 |
| 6 | 2 돈카츠집 | word-hirekatsu | 생성 |
| 7 | 2 돈카츠집 | word-gohan | 생성 |
| 8 | 3 소바·우동집 | word-udon | 생성 |
| 9 | 3 소바·우동집 | word-soba | 생성 |
| - | 3 소바·우동집 | word-kitsune | 복사 (`item-art/source/kitsune.png`) |
| 10 | 3 소바·우동집 | word-zaru | 생성 |
| 11 | 4 역 | word-eki | 생성 |
| 12 | 4 역 | word-otsuri | 생성 |
| 13 | 4 역 | word-kippuuriba | 생성 |
| 14 | 5 신사·축제 | word-omamori | 생성 |
| 15 | 5 신사·축제 | word-omikuji | 생성 |
| 16 | 5 신사·축제 | word-takoyaki | 생성 |
| 17 | 5 신사·축제 | word-ringoame | 생성 |
| 18 | 6 이자카야 | word-yakitori | 생성 |
| 19 | 6 이자카야 | word-tsukune | 생성 |
| 20 | 6 이자카야 | word-onigiri | 생성 |
| 21 | 7 온천 | word-yu | 생성 → ゆ 합성 |
| 22 | 7 온천 | word-onsen | 생성 |
| 23 | 7 온천 | word-yukata | 생성 |
| 24 | 8 료칸 | word-houjicha | 생성 |
| 25 | 8 료칸 | word-ofuro | 생성 |
| 26 | 8 료칸 | word-futon | 생성 |

### 3.2 우선순위 2 (16개: 새로 15, 복사 1)

| 순서 | 장면 | 파일 | 할 일 |
|---|---|---|---|
| 27 | 1 스시집 | word-ikura | 생성 |
| 28 | 1 스시집 | word-ebi | 생성 |
| 29 | 1 스시집 | word-inari | 생성 |
| 30 | 2 돈카츠집 | word-oroshi | 생성 |
| 31 | 3 소바·우동집 | word-wakame | 생성 |
| 32 | 3 소바·우동집 | word-tanuki | 생성 |
| 33 | 3 소바·우동집 | word-okame | 고명 구성 확인 뒤 생성 |
| 34 | 4 역 | word-noriba | 생성 |
| 35 | 5 신사·축제 | word-omatsuri | 생성 |
| 36 | 5 신사·축제 | word-yakisoba | 생성 |
| 37 | 6 이자카야 | word-kawa | 생성 |
| 38 | 6 이자카야 | word-shiitake | 생성 |
| 39 | 6 이자카야 | word-uzura | 생성 |
| - | 7 온천 | word-hinoki | 복사 (`word-ofuro`) |
| 40 | 7 온천 | word-kutsuonuide | 생성 (no floor 뺌) |
| 41 | 8 료칸 | word-oheya | 생성 (no floor 뺌) |

### 3.3 우선순위 3 (16개, 그리지 않음)

おかわり, かけ, のりかえ, こちら, でぐち, いりぐち, おまいり, えんむすび, あたり, はずれ, むね, ささみ, なんこつ, ぬる湯, ようこそ, おもてなし. 이유는 2번 표의 비고. 크게 세 가지다: 행동·기원·인사 같은 추상어(おかわり, のりかえ, おまいり, えんむすび, ようこそ, おもてなし), 짝이 되는 말과 그림이 같아지는 말(でぐち·いりぐち, あたり·はずれ, こちら), 다른 단어 그림과 구분되지 않는 말(かけ, むね, ささみ, なんこつ, ぬる湯).

## 4. 리워드 아이템과의 관계

### 4.1 규칙

1. **같은 대상을 단어 그림과 손에 드는 아이템으로 함께 쓰지 않는다.** 학습 단어인 물건은 단어 그림으로 보여 주고, 리워드 아이템으로 팔지 않는다. 사용자 지시(とんかつ)를 일반화한 규칙이다. 같은 그림이 단어 읽기와 꾸미기 상점에 함께 나오면 "배운 단어"와 "산 물건"이 섞인다.
2. **배경 아이템은 단어와 같은 말이어도 둔다.** のれん(스시집), えき(역), ゆ(온천) 배경은 기리가 서는 장소이고, 단어 그림은 그 물건 하나를 가까이서 본 그림이라 구도와 쓰임이 다르다. 원본 그림은 나눠 쓰지 않고 따로 그린다(word-eki, word-yu는 새로).
3. **학습 단어가 아닌 아이템은 그대로 둔다.** おひつ, たすき, きっぷ, とりい, おめん, はちまき, まえかけ, てぬぐい, ふろしき, ようかん. きっぷ는 단어 きっぷうりば와 이어지지만 단어 그림은 발매기로 그려 겹치지 않는다.
4. **아이템 그림을 단어 그림으로 옮길 때는 원본을 복사한다.** 아이템에서 빠지는 시점에 앱 에셋(`Item-{id}-*`, `ItemThumb-{id}`)을 정리하는 일은 developer가 rewards.json 변경과 함께 한다.
5. 단어 그림은 화풍·색 규칙만 아이템과 같고, 슬롯 자리 규격은 따르지 않는다.

### 4.2 돈카츠집의 빈 아이템 자리: おしんこ (손) 추천

| 항목 | 내용 |
|---|---|
| 아이템 | おしんこ, 한국어 "절임 반찬"(예: 다쿠앙), 슬롯 손 |
| 읽기 | お(2b) し(1a) ん(2a) こ(1b). 장면 2까지 배운 글자로 다 읽힌다(못 읽는 글자 0). 장면 2 글자 お ん이 들어간다 |
| 장면과 맞음 | 돈카츠 정식은 밥·된장국과 함께 절임 반찬이 붙어 나온다. 같은 장면의 おひつ(밥통)와 함께 "정식 한 상"을 이룬다 |
| 꾸미기와 맞음 | 오니기리 곁에 노란 다쿠앙을 곁들이는 차림과 맞다. 그림은 tonkatsu.png처럼 **젓가락으로 집은 노란 다쿠앙 한두 조각**으로 그리면 손 슬롯 규격(세로로 선 모양, 아래 가운데가 쥐는 점)과 64pt에서의 단순한 실루엣(노란 반달)을 지킨다 |
| 학습 단어와 겹침 | 60단어에 없다. 규칙 1에 걸리지 않는다 |
| 슬롯 | 손 5개(すし, とんかつ, きつね, きっぷ, ようかん) 중 とんかつ가 빠진 자리를 같은 슬롯으로 채워 슬롯 수(배경 4, 손 5, 모자 4, 두건 3)가 그대로다 |
| 확인 필요 | 현지 표기. お新香로 쓰는 곳이 많고, おしんこ 히라가나 표기가 돈카츠집 메뉴에 나오는지는 확인하지 못했다 [지식]. PLAN.md 8번의 "리워드 아이템 이름의 현지 표기 확인"에 들어간다 |

검토하고 뺀 후보:

- たれ (た れ, 다 읽힘): 소스 단지. 메뉴에서는 タレ(가타카나)가 흔해 보여 [지식] 히라가나 근거가 약하고, 단지를 든 모습이 어색하다.
- おかし, こたつ, たいこ, すいか (다 읽힘): 돈카츠집과 관계가 없다.
- はし (젓가락): 꾸미기로는 가장 자연스럽지만 は가 5b라 장면 2 시점에 1자를 못 읽는다.

**전제**: 사용자가 とんかつ를 뺀 이유가 "학습 단어는 단어 그림으로"라면 おしんこ가 맞다. 이유가 "음식은 꾸미기 아이템으로 두지 않는다"라면 おしんこ도 음식이라 맞지 않고, 그때는 はし(1자 못 읽음)를 차선으로 둔다.

### 4.3 다른 장면의 음식 아이템에 같은 원칙을 적용할지

| 아이템 | 학습 단어인가 | 규칙 1 적용 | 판단 |
|---|---|---|---|
| すし (1 스시집, 손) | 예 (1a すし) | 걸림 | 같은 원칙을 적용해 아이템에서 빼고 word-sushi로만 쓰기를 권한다. 아이템 그림은 아직 없어 버리는 작업이 없다 |
| きつね (3 소바·우동집, 손) | 예 (3b きつね) | 걸림 | 같은 원칙을 적용해 아이템에서 빼기를 권한다. 이미 그린 kitsune.png는 word-kitsune으로 옮겨 쓰므로 버리는 그림이 없다 |
| ようかん (8 료칸, 손) | 아니요 | 안 걸림 | 그대로 둔다. "음식은 아이템에서 뺀다"가 이유라면 함께 뺀다 |

- 판단 근거: 사용자 지시의 핵심을 "단어 그림은 학습에서 보여 준다"로 읽으면, 같은 경우인 すし와 きつね를 남기는 것은 일관되지 않다.
- 영향: 두 개를 빼면 대체 아이템 2개가 더 필요하다(스시집, 소바·우동집). 손 아이템은 きっぷ, ようかん, おしんこ의 3개가 되고 나머지 둘은 다른 슬롯으로 채워 슬롯 균형을 맞출 수 있다. 대체 후보는 적용이 결정되면 따로 고른다.
- PLAN.md(3번 "리워드 아이템", 8번 재배정 항목)와 rewards.json은 고치지 않았다.

## 5. 움직임(Lottie) 추천

PLAN.md 3번 "그림 움직임"대로 정지 그림 + 움직이는 벡터 레이어의 Lottie 파일 하나로 만든다. 정지 그림에는 움직이는 부분을 그리지 않았다(1번 공통 규격).

| 순서 | 파일 | 움직임 | 효과가 큰 이유 |
|---|---|---|---|
| 1 | word-takoyaki | 가쓰오부시 3~4조각이 하늘하늘 흔들림 + 김 | 다코야키를 다른 둥근 음식과 가르는 특징이 움직임이다 |
| 2 | word-onsen | 김이 피어오름 + 물결 | 김 없는 온천 그림은 "연못"으로 보인다. 움직임이 뜻을 보탠다 |
| 3 | word-yu | 노렌 아랫단이 좌우로 살랑 | 목욕탕 입구의 노렌을 지나가는 느낌. 장면 7의 첫 단어 |
| 4 | word-omatsuri | 초롱이 좌우로 흔들림 + 불빛 깜박임 | 저녁 축제의 분위기를 한 물건으로 전한다 |
| 5 | word-gohan | 김 | 갓 지은 밥. 김 레이어를 다른 뜨거운 음식과 같이 쓴다 |
| 6 | word-udon | 김 | 같은 김 레이어. word-soba, word-kitsune에도 그대로 쓸 수 있다 |
| 7 | word-katsudon | 김 | 같은 김 레이어 |
| 8 | word-houjicha | 김 (가늘게 한두 줄) | 찻잔 하나라 김이 없으면 무엇인지 약하다 |
| 9 | word-otsuri | 동전이 위에서 떨어져 접시에서 한 번 튐 (반복 없이 한 번) | "거스름돈이 나온다"는 장면을 움직임으로 보여 준다 |
| 10 | word-omikuji | 묶은 종이 끝이 바람에 팔랑 | 매달린 종이라는 모양이 또렷해진다 |

- 김 레이어 하나(3줄, 위로 오르며 사라짐)를 만들어 뜨거운 음식·온천·차에 위치와 크기만 바꿔 쓰면 작업량이 줄어든다.
- 움직임 후보는 있지만 추천에서 뺀 것: word-soba·word-kitsune·word-wakame·word-tanuki·word-okame·word-yakisoba·word-ofuro·word-hinoki(김, 같은 레이어로 나중에 붙이기 쉬움), word-yakitori(연기), word-omamori(끈), word-yukata(흔들림, 걸린 옷이라 움직임이 약함).
- 단어 그림이 나오는 화면에는 기리도 나온다. 한 화면에 반복 움직임 하나라는 규칙(PLAN.md 3번 "시각 스타일"은 기리의 움직임 기준)과 단어 그림 움직임이 함께 있을 때의 처리는 designer가 정한다.
