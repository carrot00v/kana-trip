import Foundation

/// 화면에 나오는 문구 모음 (docs/design/scene-flow.md 15번).
/// 장면 이름, 글자, 단어, 쓰기 포인트는 여기 두지 않고 Resources의 데이터 파일에서 읽는다.
enum L {
    // MARK: 홈
    static let appTitle = "니혼go"
    static let soundToggle = "발음 소리"
    static let done = "완료"
    static let more = "더 보기"
    static let comingSoon = "준비 중이에요"
    static let ok = "확인"
    static let devSpike = "개발용: 쓰기 판정 스파이크"

    static func homeStart(scene: String, step: String, resume: Bool) -> String {
        "\(scene) · \(stepAction(step, resume: resume))"
    }

    // MARK: 지도 홈 (docs/design/home-map.md 9.4)
    /// 바의 뒤로 버튼(S·K에서 "‹ 지도").
    static let mapTitle = "지도"
    static func regionProgress(script: String, done: Int, total: Int) -> String { "\(script) \(done)/\(total)" }
    static func regionProgressLabel(script: String, done: Int, total: Int) -> String {
        "\(script), \(total)장면 중 \(done)장면 완료"
    }
    static let mapLabel = "여행 지도"
    static func regionStart(_ script: String) -> String { "\(script) 여행" }
    static func regionStartLabel(_ script: String) -> String { "\(script) 여행 출발" }
    static let katakanaComingSoon = "가타카나 여행 · 준비 중"
    static let katakanaComingSoonLabel = "가타카나 여행, 준비 중"
    static func quizPill(review: Int) -> String { review > 0 ? "\(quizSessionName) · 복습 \(review)" : quizSessionName }
    static func buildingPill(order: Int, name: String) -> String { "\(order) \(name)" }
    /// 바 1줄: 지금 장면 (home-map.md R2.3). 모두 끝내면 "{지역} 여행 완료".
    static func mapSceneTitle(order: Int, name: String) -> String { "\(order) \(name)" }
    static func regionDone(_ script: String) -> String { "\(script) 여행 완료" }
    static let toCurrentNodeLabel = "지금 칸으로 이동"
    static let customizeShort = "꾸미기"

    // 칸 카드 (3.3)
    static func nodeCardTitle(scene: String, session: String) -> String { "\(scene) · \(session)" }
    static let nodeMyTurn = "할 차례예요"
    static let nodeResume = "하던 데부터 이어서 해요"
    static let nodeDone = "끝냈어요"
    static func nodeLocked(previous: String) -> String { "\(previous)\(hasFinalConsonant(previous) ? "을" : "를") 끝내면 열려요" }
    static let goalWordsTitle = "읽게 되는 단어"
    static let start = "시작"
    static let resume = "이어서 하기"
    static let redo = "다시 하기"
    static let allSceneWords = "장면 단어 전체 보기"

    // 알림 (4.5)
    static func turnAnnouncement(scene: String, session: String) -> String { "\(scene) \(session) 차례예요" }
    static func newSceneAnnouncement(scene: String, step: String) -> String {
        "다음 여행지는 \(scene)\(copula(scene)). \(step) 차례예요"
    }

    // VoiceOver (9.3)
    static func stepNodeLabel(order: Int, scene: String, step: String, kana: [String], status: String) -> AttributedString {
        var japanese = AttributedString(kana.joined(separator: " "))
        japanese.languageIdentifier = "ja"
        return AttributedString("\(order)번 \(scene) \(step), ") + japanese + AttributedString(", \(status)")
    }
    static func quizNodeLabel(order: Int, scene: String, review: Int, status: String) -> String {
        "\(order)번 \(scene) \(quizSessionName)" + (review > 0 ? ", 복습 \(review)자" : "") + ", \(status)"
    }
    static let nodeStatusMyTurn = "지금 할 차례"
    static let nodeStatusResume = "하던 중"
    static func nodeStatusLocked(previous: String) -> String { "\(locked), \(nodeLocked(previous: previous))" }
    static func buildingLabel(order: Int, name: String, status: String) -> String { "\(order)번 \(name), \(status)" }
    static let buildingInProgress = "진행 중"
    static let buildingSeeWords = "장면 단어 보기"

    // MARK: 장면 진입
    static func learnedCount(_ learned: Int, of total: Int) -> String { "배운 글자 \(learned) / \(total)" }
    static let canRead = "읽을 수 있어요"
    static let unreadableWords = "아직 못 읽는 글자가 있는 단어"
    static let resumeShort = "이어서"

    static func stepAction(_ step: String, resume: Bool) -> String {
        "\(step) \(resume ? "이어서 하기" : "시작")"
    }

    /// C1·C2·S에서 지도로 돌아가는 버튼. 세션을 닫으면 늘 지도로 돌아간다 (home-map.md 3.4).
    static let backToSceneList = "지도로 돌아가기"

    /// 세션의 이름: 단계 이름(간판, 메뉴) 또는 "종합 퀴즈".
    static func sessionName(_ session: TripSession) -> String {
        session.step?.name ?? quizSessionName
    }

    // MARK: 상단 바
    static func partName(_ part: SessionPart) -> String {
        switch part {
        case .learn: "배우기"
        case .quiz: "퀴즈"
        case .words: "단어 읽기"
        }
    }

    // MARK: 구간 안내
    static let quizIntroTitle = "퀴즈"
    static let quizIntroBody = "방금 배운 글자를 기억으로 맞혀요"
    static func quizIntroReview(_ r: Int) -> String { "지난 장면에서 헷갈린 글자 \(r)자도 함께 나와요" }
    static let quizStart = "퀴즈 시작"
    static let wordsIntroTitle = "단어 읽기"
    static func wordsIntroBody(step: String, count: Int) -> String { "\(step)에서 보는 단어 \(count)개를 읽어요" }
    static func wrongKanaReturns(_ kana: [String]) -> String {
        let particle = kana.last == "ん" ? "은" : "는"
        return "\(kana.joined(separator: ", "))\(particle) 다음 장면 퀴즈에 다시 나와요"
    }
    static let wordsStart = "단어 읽기 시작"
    /// 종합 퀴즈 세션의 이름. 장면 진입의 세 번째 행과 C1 제목에 쓴다.
    static let quizSessionName = "종합 퀴즈"
    static let quizSessionStart = "종합 퀴즈 시작"

    // MARK: 배우기
    static let newKana = "새 글자"
    static func strokeCount(_ n: Int) -> String { "\(n)획" }
    static func stepWords(scene: String, step: String) -> String { "\(scene) \(step) 단어" }
    static let tryWriting = "써 보기"
    static func traceRound(_ round: Int, of total: Int) -> String { "따라 쓰기 \(round)/\(total)" }
    static let traceHint = "번호가 있는 점에서 시작해 따라 쓰세요"
    static let strokeGood = "좋아요"
    static func traceFinished(mistakes: Int) -> String {
        mistakes == 0 ? "완성, 한 번에 썼어요" : "완성, 틀린 획 \(mistakes)번"
    }
    static let rewrite = "다시 쓰기"
    static let next = "다음"

    // MARK: 획 판정
    static func verdictMessage(_ verdict: StrokeVerdict, expectedStroke: Int) -> String {
        switch verdict {
        case .reversed: "방향이 반대예요"
        case .wrongOrder: "지금은 \(expectedStroke)번째 획 차례예요"
        case .tooShort: "너무 짧아요"
        case .missingLoop: "점선 자리에서 고리를 만들어야 해요"
        case .extraLoop: "이 획에는 고리가 없어요"
        case .offTarget, .correct: "위치나 모양이 달라요"
        }
    }

    // MARK: 퀴즈
    static let choiceCorrect = "맞아요"
    /// 로마자가 n으로 끝나면 받침으로 보고 "이에요" (scene-flow.md 13.1).
    static func choiceAnswer(_ romaji: String) -> String {
        romaji.hasSuffix("n") ? "정답은 \(romaji)이에요" : "정답은 \(romaji)예요"
    }

    // MARK: 종합 퀴즈 (scene-flow.md 12, 13번)
    static func quizPartName(_ kind: QuizKind) -> String {
        switch kind {
        case .readingChoice: "발음 고르기"
        case .wordReading: "읽기 고르기"
        case .recallWrite: "기억으로 쓰기"
        }
    }
    static func partStart(name: String, count: Int) -> String { "여기부터 \(name) \(count)문항" }
    static func partStartLabel(name: String, count: Int) -> String { "여기부터 \(name), \(count)문항" }
    static func retryRemaining(_ n: Int) -> String { "다시 풀기 · \(n)개 남음" }
    static func quizTitle(scene: String) -> String { "\(scene) 종합 퀴즈" }
    static func questionCount(_ n: Int) -> String { "\(n)문항" }
    static func reviewIncluded(_ kana: [String]) -> String { "지난 장면에서 헷갈린 글자 \(kana.joined(separator: ", "))도 나와요" }
    static let resumeAnytime = "중간에 나가도 이어서 할 수 있어요"
    static func quizRowSummary(kana: Int, words: Int, review: Int) -> String {
        "글자 \(kana)자 · 단어 \(words)개" + (review > 0 ? " · 복습 \(review)자" : "")
    }
    static func quizRowLocked(previous: String) -> String { "\(previous)까지 끝내면 열려요" }
    static func quizAllCorrect(_ n: Int) -> String { "\(n)문항을 모두 맞혔어요" }
    static func confusedThisTime(_ kana: [String]) -> String {
        let particle = kana.last == "ん" ? "을" : "를"
        return "\(kana.joined(separator: ", "))\(particle) 이번에 헷갈렸어요"
    }
    static func confusedKana(_ kana: [String]) -> String { "헷갈린 글자 \(kana.joined(separator: ", "))" }
    static let recallHint = "기억나는 대로 한 획씩 쓰세요"
    static let guideOn = "가이드를 보고 따라 쓰세요"
    static let recallFinished = "완성, 기억으로 썼어요"
    static let recallFinishedWithGuide = "완성, 이 글자는 뒤에 한 번 더 나와요"
    static let showGuide = "가이드 보기"

    // MARK: 단어 읽기
    static let checkReading = "읽기 확인"

    // MARK: 완료
    static func stepDone(scene: String, step: String) -> String { "\(scene) \(step) 완료" }
    static func stepSummary(kana: Int, words: Int) -> String { "새 글자 \(kana)자를 배우고 단어 \(words)개를 읽었어요" }
    static let nowReadable = "이제 읽을 수 있는 단어"
    static func readableWords(_ scene: String) -> String { "이제 읽을 수 있는 \(scene) 단어" }
    static let stopHere = "여기까지 하기"
    static func sceneDone(_ scene: String) -> String { "\(scene) 장면 완료" }
    static func sceneSummary(_ n: Int) -> String { "히라가나 \(n)자를 읽고 쓸 수 있어요" }
    static func nextSceneOpened(_ scene: String) -> String {
        "다음 장면 '\(scene)'\(hasFinalConsonant(scene) ? "이" : "가") 열렸어요"
    }

    // MARK: 리워드 (docs/design/reward-flow.md 10번)
    /// "1,000엔". 천 단위 쉼표를 붙인다.
    static func yen(_ n: Int) -> String {
        "\(n.formatted(.number.locale(Locale(identifier: "ko_KR"))))엔"
    }
    static func coinsReceived(_ n: Int) -> String { "\(yen(n))을 받았어요" }
    static func coinsBalance(_ n: Int) -> String { "가진 엔 \(yen(n))" }
    static let customize = "기리 꾸미기"
    static let canBuyItem = "살 수 있는 아이템이 있어요"
    static func itemsUnlocked(_ n: Int) -> String { "새 아이템 \(n)개가 열렸어요" }
    static func itemsGranted(_ n: Int) -> String { "남은 아이템 \(n)개를 모두 받았어요" }
    static func hiraganaMilestone(_ coins: Int) -> String { "히라가나를 모두 끝내서 \(yen(coins))을 더 받았어요" }

    static let resetOutfit = "기본 차림으로"
    static let defaultOutfit = "기본 차림"
    static let balanceTitle = "가진 엔"
    static let none = "없음"
    // 2026-11-16: 토핑·밥·배경을 "입는다"고 하지 않으려고 동사를 바꿨다 (reward-flow.md 3.0, 10번).
    static let wearing = "쓰는 중"
    static let owned = "가짐"

    static func slotName(_ slot: RewardSlot) -> String {
        switch slot {
        case .top: "머리"
        case .filling: "속재료"
        case .rice: "밥"
        // 데이터 슬롯은 background, 화면 이름은 스킨 (app-skin.md 5.2, 이슈 #7).
        case .background: "스킨"
        }
    }
    /// 안내 줄 "처음" 문구 (reward-flow.md 3.8). 조사는 받침 판별 없이 슬롯마다 따로 둔다.
    static func slotWearing(_ slot: RewardSlot) -> String {
        switch slot {
        case .top: "머리에 쓰고 있어요"
        case .filling: "속재료로 쓰고 있어요"
        case .rice: "이 밥으로 쓰고 있어요"
        case .background: "앱 색으로 쓰고 있어요"
        }
    }
    /// 밥은 비울 수 없어 쓰지 않는다.
    static func slotEmpty(_ slot: RewardSlot) -> String {
        switch slot {
        case .top: "머리가 비어 있어요"
        case .filling: "속재료가 비어 있어요"
        case .rice, .background: ""
        }
    }
    static let wearingNow = "지금 쓰고 있어요"
    static let equipped = "바꿨어요"
    /// 밥은 비울 수 없어 쓰지 않는다.
    static func slotCleared(_ slot: RewardSlot) -> String {
        switch slot {
        case .top: "머리를 비웠어요"
        case .filling: "속재료를 비웠어요"
        case .rice, .background: ""
        }
    }
    static func tryingOn(price: Int) -> String { "미리 보는 중이에요 · \(yen(price))" }
    static func shortOf(_ n: Int) -> String { "\(yen(n))이 더 있으면 살 수 있어요" }
    static func lockedItemTitle(scene: String) -> String { "\(scene) 장면 아이템" }
    static func unlocksWith(scene: String) -> String { "\(scene) 장면을 끝내면 열려요" }
    static let bought = "사서 바꿨어요"
    static let outfitReset = "기본 차림으로 돌아왔어요"

    // 스킨 탭 (app-skin.md 5.2, 5.3. 2026-11-21 색상 선택 개정). {색 이름}은 skins.json의 nameKo.
    static let skinDefault = "기본"
    static let skinDefaultWearing = "기본 색을 쓰고 있어요"
    static let skinDefaultRestored = "기본 색으로 돌아왔어요"
    static let skinEquipped = "앱 색을 바꿨어요"
    static let skinBought = "사서 앱 색을 바꿨어요"
    static let skinDefaultLabel = "기본 색"
    static let skinDefaultAction = "기본 색으로 바꾸기"
    /// C2 열린 아이템 줄과 VoiceOver의 색 아이템 이름 (5.4).
    static func skinColorName(_ name: String) -> String { "\(name) 색" }
    /// K 미리보기 VoiceOver 값의 마지막 항목 (5.3).
    static func skinPreviewPart(_ name: String) -> String { "스킨 \(name)" }
    /// 미리 보는 견본의 VoiceOver 값 앞머리 (5.3).
    static func tryingPrefix(_ value: String) -> String { "\(tryingOnLabel), \(value)" }
    /// 확인 창 제목. "색을"로 받침 판별을 피한다 (5.3).
    static func buySkinQuestion(name: String, price: Int) -> String { "\(name) 색을 \(yen(price))에 살까요?" }
    static func buyQuestion(kana: String, nameKo: String, price: Int) -> String {
        "\(kana)(\(nameKo))\(hasFinalConsonant(nameKo) ? "을" : "를") \(yen(price))에 살까요?"
    }
    static let buyNoRefund = "산 아이템은 되돌릴 수 없어요"
    static func buyButton(price: Int) -> String { "\(yen(price))으로 사기" }
    static let cancel = "취소"

    // MARK: 기리 고정 대사 (docs/design/giri-companion.md 3.11, docs/content/giri-lines.md 4.2·6.1)
    // 단어 설명, 장면 소개, 쓰기 포인트, 쌍 짚기는 데이터에 있다 (tools/build_giri_lines.py).

    // H 홈
    static func giriHomeFirst(_ scene: String) -> String { "첫 여행지는 \(scene)\(copula(scene)). 같이 가 봐요" }
    static func giriHomeNewScene(scene: String, step: String) -> String { "다음 여행지는 \(scene)\(copula(scene)). \(step)부터 봐요" }
    static func giriHomeStepB(scene: String, step: String) -> String { "\(sceneStep(scene, step))\(object(step)) 읽으러 가요" }
    static func giriHomeQuiz(_ scene: String) -> String { "\(scene)에서 읽은 걸 같이 확인해 봐요" }
    /// `session`은 단계 이름 또는 "종합 퀴즈".
    static func giriHomeResume(scene: String, session: String) -> String { "\(sceneStep(scene, session)) 하던 데부터 이어서 해요" }
    // H 홈 지도의 한 줄 대사 (home-map.md "2026-11-21 재구성안" R2.5). 장면·단계 이름은 바와 시작 버튼이 말하므로 줄였다.
    static func giriHomeLineFirst(_ scene: String) -> String { "첫 여행지는 \(scene)\(copula(scene))" }
    static func giriHomeLineNewScene(_ scene: String) -> String { "다음 여행지는 \(scene)\(copula(scene))" }
    static func giriHomeLineStepB(_ step: String) -> String { "\(step) 읽으러 가요" }
    static let giriHomeLineQuiz = "읽은 걸 같이 확인해 봐요"
    static let giriHomeLineResume = "하던 데부터 이어서 해요"
    /// 장면 이름 뒤에 단계 이름을 붙인다. 단계 이름에 장면 이름의 낱말이 들어 있으면 장면 이름을 뺀다
    /// ("신사·축제 축제 노점" → "축제 노점", "신사·축제 신사" → "신사"). giri-companion.md 3.11.
    static func sceneStep(_ scene: String, _ step: String) -> String {
        let sceneWords = scene.split(separator: "·").map { $0.trimmingCharacters(in: .whitespaces) }
        return sceneWords.contains(where: { !$0.isEmpty && step.contains($0) }) ? step : "\(scene) \(step)"
    }
    static let giriComingSoon = "다음 여행지는 아직 준비 중이에요"
    static let giriAllDone = "히라가나 여행을 다 마쳤어요"

    // S 장면 진입
    static func giriSceneStepA(scene: String, step: String) -> String { "\(scene)에 왔어요. \(step)부터 읽어 볼까요?" }
    static func giriSceneStepB(_ step: String) -> String { "이제 \(step)\(object(step)) 읽어 볼까요?" }
    static let giriSceneQuiz = "여기 단어는 다 봤어요. 같이 확인해 볼까요?"
    static func giriSceneResume(_ session: String) -> String { "\(session) 하던 데부터 이어서 해요" }
    static func giriSceneDone(_ scene: String) -> String { "\(scene)\(topic(scene)) 이제 읽을 수 있어요" }

    // L1, L2 (쓰기 포인트가 없는 글자)
    static let giriNoTip = "번호 순서대로 따라 써 봐요"

    // W 단어 읽기 전 (giri-lines.md 4.2)
    static let giriReadAloud = "같이 소리 내어 읽어 봐요"
    static let giriKanjiWord = "한자는 위에 쓴 발음으로 읽어요"
    static let giriFirstRuby = "위에 작게 쓴 건 아직 안 배운 글자예요"
    static func giriReread(_ step: String) -> String { "\(step)에서 본 단어예요. 다시 읽어 봐요" }
    static func giriWordFallback(scene: String, step: String) -> String { "\(scene) \(step)에서 볼 수 있어요" }

    // QI 퀴즈 안내
    static func giriQuizIntro(_ scene: String) -> String { "\(scene) 마지막 차례예요. 헷갈린 건 한 번 더 나와요" }
    static let giriQuizIntroReplay = "한 번 더 같이 확인해 봐요"

    // QA, QD, QC 질문
    static let giriAskKana = "이 글자, 어떻게 읽을까요?"
    static let giriAskWord = "이 단어, 어떻게 읽을까요?"
    static let giriAskWrite = "이 발음의 글자를 써 봐요"
    static let giriPartWord = "이번엔 단어예요. 어떻게 읽을까요?"
    static let giriPartWrite = "이번엔 기억으로 써 봐요"
    static let giriRetryRead = "한 번 더 봐요. 어떻게 읽을까요?"
    static let giriRetryWrite = "한 번 더 기억으로 써 봐요"
    static let giriGuideNoTip = "가이드를 따라 같이 써 봐요"

    // 오답 틀 문구 (giri-lines.md 6.1). ん과 로마자 n은 받침으로 본다.
    /// QA: "ko는 こ예요. た는 ta로 읽어요"
    static func giriWrongKana(picked romaji: String, pickedKana: String, correct: String, correctRomaji: String) -> String {
        "\(romaji)\(kanaTopic(romaji)) \(pickedKana)\(kanaCopula(pickedKana)). \(correct)\(kanaTopic(correct)) \(correctRomaji)\(kanaInstrument(correctRomaji)) 읽어요"
    }
    /// QD: "이 단어의 か는 ka예요"
    static func giriWrongWord(kana: String, romaji: String) -> String {
        "이 단어의 \(kana)\(kanaTopic(kana)) \(romaji)\(kanaCopula(romaji))"
    }

    // C1, C2 완료
    static func giriDoneStepA(step: String, next: String) -> String { "\(step) 다 읽었어요. 다음은 \(next)\(copula(next))" }
    static let giriDoneStepB = "이제 종합 퀴즈만 남았어요"
    static let giriDoneStepReplay = "한 번 더 읽으니 눈에 잘 들어와요"
    static let giriDoneQuizReplay = "다시 해도 다 읽었네요"
    static func giriDoneScene(_ scene: String) -> String { "\(scene)에서 본 글자, 이제 다 읽혀요" }
    static let giriDoneSceneWrong = "헷갈린 글자는 다음 여행지에서 또 봐요"
    static let giriDoneAll = "히라가나 여행을 다 마쳤어요. 같이 와서 즐거웠어요"

    // 조사 (한글 낱말)
    private static func copula(_ word: String) -> String { hasFinalConsonant(word) ? "이에요" : "예요" }
    private static func object(_ word: String) -> String { hasFinalConsonant(word) ? "을" : "를" }
    private static func topic(_ word: String) -> String { hasFinalConsonant(word) ? "은" : "는" }

    // 조사 (가나, 로마자 값). 받침이 있으면 `|`의 뒤쪽 (giri-lines.md 6.1)
    static func kanaHasFinalConsonant(_ value: String) -> Bool {
        guard let last = value.last else { return false }
        if last == "ん" || last == "n" || last == "N" { return true }
        if let scalar = last.unicodeScalars.first, (0xAC00...0xD7A3).contains(scalar.value) {
            return (scalar.value - 0xAC00) % 28 != 0
        }
        return false
    }
    private static func kanaTopic(_ v: String) -> String { kanaHasFinalConsonant(v) ? "은" : "는" }
    private static func kanaCopula(_ v: String) -> String { kanaHasFinalConsonant(v) ? "이에요" : "예요" }
    private static func kanaInstrument(_ v: String) -> String { kanaHasFinalConsonant(v) ? "으로" : "로" }

    // MARK: VoiceOver
    static let close = "닫기"
    static let closeHint = "진행은 저장돼요"
    static func progressLabel(name: String, done: Int, total: Int, detail: String?) -> String {
        "\(name), \(total)개 중 \(done)개" + (detail.map { ", \($0)" } ?? "")
    }
    static let questionGlyph = "문제 글자"
    static let tipPrefix = "쓰기 포인트"
    static let locked = "잠김"
    static let myTurn = "할 차례"
    static let correctAnswer = "정답"
    static let myWrongAnswer = "내가 고른 답, 오답"
    static func canvasLabel(char: String?, total: Int, current: Int) -> String {
        let head = char.map { "쓰기 칸. \($0), " } ?? "쓰기 칸. "
        return current > total ? "\(head)\(total)획 완성" : "\(head)\(total)획 중 \(current)번째 획"
    }
    static func sceneRowLabel(order: Int, name: String, steps: [(name: String, kana: [String])], done: Int, total: Int) -> String {
        let parts = steps.map { "\($0.name) \($0.kana.joined(separator: " "))" }.joined(separator: ", ")
        return "\(order)번 \(name), \(parts), \(total)개 중 \(done)개 완료"
    }
    static func stepRowLabel(number: Int, name: String, kana: [String], status: String) -> String {
        "\(number)단계 \(name), 새 글자 \(kana.joined(separator: " ")), \(status)"
    }
    static func stepRowLockedLabel(number: Int, name: String, previous: String) -> String {
        "\(number)단계 \(name), 잠김, \(previous)\(hasFinalConsonant(previous) ? "을" : "를") 끝내면 열려요"
    }
    static let resumeLabel = "이어서 하기"
    static let doneRedoLabel = "완료, 다시 하기"
    static func learnedCountLabel(_ learned: Int, of total: Int) -> String { "글자 \(total)개 중 \(learned)개 배움" }
    /// "すし의 す"에서 단어와 글자를 잇는 말.
    static let possessive = "의 "
    static func sceneRowLocked(order: Int, name: String) -> String { "\(order)번 \(name), \(locked)" }

    static func customizeRowLabel(balance: Int, canBuy: Bool) -> String {
        "\(customize), \(coinsBalance(balance))" + (canBuy ? ", \(canBuyItem)" : "")
    }
    static func coinsLineLabel(received: Int, balance: Int) -> String { "\(coinsReceived(received)), \(coinsBalance(balance))" }
    static let giri = "기리"
    static let canBuy = "살 수 있음"
    static func short(_ n: Int) -> String { "\(yen(n)) 모자람" }
    static let tryingOnLabel = "미리 보는 중"
    static func clearSlotLabel(_ slot: RewardSlot) -> String { "\(slotName(slot)) 비우기" }
    static let canBuyInSlot = "살 수 있는 아이템 있음"
    /// 스킨은 권장안(app-skin.md 5.5)이면 되돌리지 않는다.
    static let resetOutfitHint = SkinPolicy.resetOutfitKeepsSkin
        ? "머리를 요리사 모자로, 밥을 흰 밥으로 바꾸고 속재료를 비워요"
        : "머리를 요리사 모자로, 밥을 흰 밥으로 바꾸고 속재료를 비우고 기본 스킨으로 돌려요"

    /// 한글 낱말이 받침으로 끝나는지. 조사를 고를 때 쓴다. 끝의 괄호·공백은 건너뛰고 마지막 한글로 본다.
    static func hasFinalConsonant(_ word: String) -> Bool {
        guard let scalar = word.unicodeScalars.last(where: { (0xAC00...0xD7A3).contains($0.value) }) else { return false }
        return (scalar.value - 0xAC00) % 28 != 0
    }
}
