import Foundation

/// 화면에 나오는 문구 모음 (docs/design/scene-flow.md 13번).
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

    static func homeStart(scene: String, session: SessionKind, resume: Bool) -> String {
        "\(scene) · \(sessionAction(session, resume: resume))"
    }

    // MARK: 장면 진입
    static func goalWordsHeader(scene: String, allLearned: Bool) -> String {
        allLearned ? readableWords(scene) : "글자를 배우면 읽는 \(scene) 단어"
    }
    static func readableWords(_ scene: String) -> String { "이제 읽을 수 있는 \(scene) 단어" }
    static func learnedCount(_ learned: Int, of total: Int) -> String { "배운 글자 \(learned) / \(total)" }
    static let canRead = "읽을 수 있어요"
    static let unreadableWords = "아직 못 읽는 글자가 있는 단어"
    static func newKanaCount(_ n: Int) -> String { "새 글자 \(n)자" }

    static func sessionTitle(_ kind: SessionKind) -> String {
        switch kind {
        case .learn: "배우기"
        case .quiz: "퀴즈"
        case .words: "단어 읽기"
        }
    }

    static func sessionDescription(_ kind: SessionKind, scene: String, wordCount: Int) -> String {
        switch kind {
        case .learn: "새 글자를 보고 따라 써요"
        case .quiz: "발음을 고르고 기억으로 써요"
        case .words: "\(scene)에서 보는 단어 \(wordCount)개를 읽어요"
        }
    }

    static func sessionLocked(_ kind: SessionKind) -> String {
        switch kind {
        case .learn: ""
        case .quiz: "배우기를 끝내면 열려요"
        case .words: "퀴즈를 끝내면 열려요"
        }
    }

    static func resumeAt(done: Int, total: Int) -> String { "이어서 하기 · \(done) / \(total)" }
    static let doneRedo = "완료 · 다시 하기"

    static func sessionAction(_ kind: SessionKind, resume: Bool) -> String {
        "\(sessionTitle(kind)) \(resume ? "이어서 하기" : "시작")"
    }

    static let backToSceneList = "장면 목록으로"

    // MARK: 배우기
    static let newKana = "새 글자"
    static func strokeCount(_ n: Int) -> String { "\(n)획" }
    static func sceneWords(_ scene: String) -> String { "\(scene) 단어" }
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
    static func choiceAnswer(_ romaji: String) -> String {
        romaji == "n" ? "정답은 n이에요" : "정답은 \(romaji)예요"
    }
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
    static func sessionDone(_ kind: SessionKind) -> String { "\(sessionTitle(kind)) 완료" }
    static func learnSummary(_ n: Int) -> String { "새 글자 \(n)자를 따라 썼어요" }
    static func quizSummaryPerfect(_ n: Int) -> String { "\(n)자를 모두 한 번에 맞혔어요" }
    static func quizSummaryWrong(_ kana: [String]) -> String {
        let particle = kana.last == "ん" ? "은" : "는"
        return "\(kana.joined(separator: ", "))\(particle) 다음 장면 퀴즈에 다시 나와요"
    }
    static func wordsSummary(scene: String, count: Int) -> String { "\(scene) 단어 \(count)개를 읽었어요" }
    static let stopHere = "여기까지 하기"
    static let backToScene = "장면으로 돌아가기"
    static func sceneDone(_ scene: String) -> String { "\(scene) 장면 완료" }
    static func sceneSummary(_ n: Int) -> String { "히라가나 \(n)자를 읽고 쓸 수 있어요" }
    static func nextSceneOpened(_ scene: String) -> String {
        "다음 장면 '\(scene)'\(hasFinalConsonant(scene) ? "이" : "가") 열렸어요"
    }

    // MARK: VoiceOver
    static let close = "닫기"
    static let closeHint = "진행은 저장돼요"
    static func progressLabel(done: Int, total: Int) -> String { "진행, \(total)개 중 \(done)개" }
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
    static func sceneRowLabel(order: Int, name: String, kana: [String], done: Int) -> String {
        "\(order)번 \(name), 새 글자 \(kana.joined(separator: " ")), 세션 3개 중 \(done)개 완료"
    }
    static func learnedCountLabel(_ learned: Int, of total: Int) -> String { "글자 \(total)개 중 \(learned)개 배움" }
    /// "すし의 す"에서 단어와 글자를 잇는 말.
    static let possessive = "의 "
    static func sceneRowLocked(order: Int, name: String) -> String { "\(order)번 \(name), \(locked)" }

    /// 한글 낱말이 받침으로 끝나는지. 조사를 고를 때 쓴다.
    private static func hasFinalConsonant(_ word: String) -> Bool {
        guard let scalar = word.unicodeScalars.last, (0xAC00...0xD7A3).contains(scalar.value) else { return false }
        return (scalar.value - 0xAC00) % 28 != 0
    }
}
