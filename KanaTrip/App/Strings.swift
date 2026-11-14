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

    // MARK: 장면 진입
    static func learnedCount(_ learned: Int, of total: Int) -> String { "배운 글자 \(learned) / \(total)" }
    static let canRead = "읽을 수 있어요"
    static let unreadableWords = "아직 못 읽는 글자가 있는 단어"
    static let resumeShort = "이어서"

    static func stepAction(_ step: String, resume: Bool) -> String {
        "\(step) \(resume ? "이어서 하기" : "시작")"
    }

    static let backToSceneList = "장면 목록으로"

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
    static let choiceQuestion = "이 글자의 발음은?"
    static let choiceCorrect = "맞아요"
    /// 로마자가 n으로 끝나면 받침으로 보고 "이에요" (scene-flow.md 13.1).
    static func choiceAnswer(_ romaji: String) -> String {
        romaji.hasSuffix("n") ? "정답은 \(romaji)이에요" : "정답은 \(romaji)예요"
    }
    static let wordQuestion = "이 단어의 읽기는?"

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
    static let quizIntroWithWords = "배운 글자와 단어를 섞어 물어요"
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
    static let recallQuestion = "이 발음의 글자를 쓰세요"
    static let recallHint = "기억나는 대로 한 획씩 쓰세요"
    static let guideOn = "가이드를 보고 따라 쓰세요"
    static let recallFinished = "완성, 기억으로 썼어요"
    static let recallFinishedWithGuide = "완성, 이 글자는 뒤에 한 번 더 나와요"
    static let showGuide = "가이드 보기"

    // MARK: 단어 읽기
    static let readAloud = "소리 내어 읽어 보세요"
    static let checkReading = "읽기 확인"

    // MARK: 완료
    static func stepDone(scene: String, step: String) -> String { "\(scene) \(step) 완료" }
    static func stepSummary(kana: Int, words: Int) -> String { "새 글자 \(kana)자를 배우고 단어 \(words)개를 읽었어요" }
    static let nowReadable = "이제 읽을 수 있는 단어"
    static func readableWords(_ scene: String) -> String { "이제 읽을 수 있는 \(scene) 단어" }
    static let stopHere = "여기까지 하기"
    static let backToScene = "장면으로 돌아가기"
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
    static let wearing = "입는 중"
    static let owned = "가짐"

    static func slotName(_ slot: RewardSlot) -> String {
        switch slot {
        case .hat: "모자"
        case .scarf: "두건"
        case .hand: "손"
        case .background: "배경"
        }
    }
    static func slotWearing(_ slot: RewardSlot) -> String { "\(slotName(slot))에 입고 있어요" }
    static func slotEmpty(_ slot: RewardSlot) -> String {
        "\(slotName(slot))\(hasFinalConsonant(slotName(slot)) ? "이" : "가") 비어 있어요"
    }
    static let wearingNow = "지금 입고 있어요"
    static let equipped = "입었어요"
    static func slotCleared(_ slot: RewardSlot) -> String { "\(slotName(slot)) 자리를 비웠어요" }
    static func tryingOn(price: Int) -> String { "입어 보는 중이에요 · \(yen(price))" }
    static func shortOf(_ n: Int) -> String { "\(yen(n))이 더 있으면 살 수 있어요" }
    static func lockedItemTitle(scene: String) -> String { "\(scene) 장면 아이템" }
    static func unlocksWith(scene: String) -> String { "\(scene) 장면을 끝내면 열려요" }
    static let bought = "사서 입었어요"
    static let outfitReset = "기본 차림으로 돌아왔어요"
    static func buyQuestion(kana: String, nameKo: String, price: Int) -> String {
        "\(kana)(\(nameKo))\(hasFinalConsonant(nameKo) ? "을" : "를") \(yen(price))에 살까요?"
    }
    static let buyNoRefund = "산 아이템은 되돌릴 수 없어요"
    static func buyButton(price: Int) -> String { "\(yen(price))으로 사기" }
    static let cancel = "취소"

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
    static let tryingOnLabel = "입어 보는 중"
    static func clearSlotLabel(_ slot: RewardSlot) -> String { "\(slotName(slot)) 자리 비우기" }
    static let canBuyInSlot = "살 수 있는 아이템 있음"
    static let resetOutfitHint = "모자와 두건을 처음 차림으로 바꾸고 손과 배경을 비워요"

    /// 한글 낱말이 받침으로 끝나는지. 조사를 고를 때 쓴다. 끝의 괄호·공백은 건너뛰고 마지막 한글로 본다.
    static func hasFinalConsonant(_ word: String) -> Bool {
        guard let scalar = word.unicodeScalars.last(where: { (0xAC00...0xD7A3).contains($0.value) }) else { return false }
        return (scalar.value - 0xAC00) % 28 != 0
    }
}
