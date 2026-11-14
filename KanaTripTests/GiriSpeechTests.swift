import Foundation
import Testing
@testable import KanaTrip

// 기리 대사 찾기와 고르기 (docs/design/giri-companion.md 3번, docs/content/giri-lines.md).

private let library = ContentLibrary.shared

private final class GiriMemoryStorage: ProgressStorage {
    var saved: ProgressState?
    func load() -> ProgressState? { saved }
    func save(_ state: ProgressState) { saved = state }
}

/// 테스트용 조회: 쌍은 い–こ 하나, 로마자 → 글자는 앱 데이터.
private struct StubLookup: GiriLookup {
    func pairLine(_ a: String, _ b: String) -> String? {
        Set([a, b]) == ["い", "こ"] ? "쌍 짚기" : nil
    }
    func kana(forRomaji romaji: String) -> String? { library.kana(forRomaji: romaji) }
}

private func choiceItem(_ kana: String, answer: String, wrong: String, replacement: String?) -> QuizItem {
    QuizItem(id: 1, kind: .readingChoice, kana: kana, word: nil, answer: answer,
             wrongs: [.init(romaji: wrong, changedIndex: nil, original: nil, replacement: replacement)], isReview: false)
}

private func wordItem(_ word: TripWord, index: Int, replacement: String) -> (QuizItem, String) {
    var parts = word.units.map(\.romaji)
    parts[index] = library.kana(replacement)!.romaji
    let made = parts.joined()
    let item = QuizItem(id: 1, kind: .wordReading, kana: nil, word: word.text, answer: word.reading,
                        wrongs: [.init(romaji: made, changedIndex: index, original: word.units[index].kana, replacement: replacement)],
                        isReview: false)
    return (item, made)
}

@Suite("기리 대사 데이터")
struct GiriDataTests {
    /// 단어 설명 60개, 장면 소개 8개, 쓰기 포인트 46개, 쌍 짚기 19개가 빠짐없이 들어 있다 (giri-lines.md 9.4).
    @Test func everyLineIsInData() {
        let words = library.steps.flatMap(\.words)
        #expect(words.count == 60)
        #expect(words.allSatisfy { !($0.giri ?? "").isEmpty })
        #expect(library.scenes.count == 8)
        #expect(library.scenes.allSatisfy { !($0.giriIntro ?? "").isEmpty })
        let kana = library.steps.flatMap(\.kana)
        #expect(kana.count == 46)
        #expect(kana.allSatisfy { !(library.kana($0)?.tip ?? "").isEmpty })
        var pairs = 0
        for char in kana {
            for partner in library.confusablePartners(of: char) {
                #expect(library.pairLine(char, partner) != nil, "\(char)–\(partner)")
                pairs += 1
            }
        }
        #expect(pairs == 19 * 2)
    }

    /// 쓰기 포인트는 44자 이하: 96pt 기리 옆 4줄 = 11자 × 4 (giri-companion.md 2.3, 2026-11-15에 48자에서 낮춤).
    @Test func writingTipsFitFourLinesBesideGiri() {
        let over = library.steps.flatMap(\.kana).compactMap { char -> String? in
            guard let tip = library.kana(char)?.tip, tip.count > 44 else { return nil }
            return "\(char) \(tip.count)자"
        }
        #expect(over.isEmpty, "\(over)")
    }

    @Test func lookupFindsDataLines() {
        #expect(library.word(text: "すし")?.giri == "초밥이에요. すしざんまい처럼 가게 이름에 써요")
        #expect(library.scene(id: "sushi")?.giriIntro == "첫 가게는 스시집이에요. 간판부터 같이 읽어요")
        // 쌍은 두 순서 모두 같은 말.
        #expect(library.pairLine("い", "こ") == "い는 세로, こ는 가로로 놓여요")
        #expect(library.pairLine("こ", "い") == library.pairLine("い", "こ"))
        #expect(library.pairLine("い", "か") == nil)
        #expect(library.kana(forRomaji: "shi") == "し")
        #expect(library.kana(forRomaji: "n") == "ん")
    }

    /// 고정 대사(Strings.swift)를 실제 데이터로 채워 상한 안인지 센다 (giri-lines.md 맨 위 표).
    /// 자리별 상한은 모두 지킨다. 한 문장 22자는 designer 고정 대사 일부(하던 중, 장면 이름이 긴 경우)가 넘어
    /// 알려진 문제로 남겨 둔다. 문구를 고치면 이 표시가 실패로 바뀐다.
    @Test func fixedLinesFitLimits() {
        var over: [String] = []
        var longSentences: [String] = []
        func check(_ text: String, _ limit: Int) {
            if text.count > limit { over.append("\(text.count)>\(limit) \(text)") }
            // 문장은 ". "로 나누고 마침표까지 센다.
            let parts = text.components(separatedBy: ". ")
            for (i, part) in parts.enumerated() {
                let n = part.count + (i < parts.count - 1 ? 1 : 0)
                if n > 22 { longSentences.append("문장 \(n) \(part)") }
            }
        }
        for scene in library.scenes {
            let a = scene.steps[0].name, b = scene.steps[1].name
            check(L.giriHomeFirst(scene.name), 26)
            check(L.giriHomeNewScene(scene: scene.name, step: a), 26)
            check(L.giriHomeStepB(scene: scene.name, step: b), 26)
            check(L.giriHomeQuiz(scene.name), 26)
            for session in [a, b, L.quizSessionName] {
                check(L.giriHomeResume(scene: scene.name, session: session), 26)
                check(L.giriSceneResume(session), 26)
            }
            check(L.giriSceneStepA(scene: scene.name, step: a), 26)
            check(L.giriSceneStepB(b), 26)
            check(L.giriSceneDone(scene.name), 26)
            check(L.giriReread(a), 28)
            check(L.giriQuizIntro(scene.name), 36)
            check(L.giriDoneStepA(step: a, next: b), 30)
            check(L.giriDoneScene(scene.name), 30)
        }
        for text in [L.giriSceneQuiz, L.giriComingSoon, L.giriAllDone] { check(text, 26) }
        for text in [L.giriReadAloud, L.giriKanjiWord, L.giriFirstRuby] { check(text, 28) }
        for text in [L.giriAskKana, L.giriAskWord, L.giriAskWrite, L.giriPartWord, L.giriPartWrite,
                     L.giriRetryRead, L.giriRetryWrite, L.giriGuideNoTip] { check(text, 28) }
        for text in [L.giriDoneStepB, L.giriDoneStepReplay, L.giriDoneQuizReplay, L.giriDoneSceneWrong, L.giriDoneAll] {
            check(text, 30)
        }
        // 오답 틀 문구: 46자의 모든 짝으로 채워 본다.
        let all = library.steps.flatMap(\.kana)
        for c in all {
            for k in all where k != c {
                let rk = library.kana(k)!.romaji, rc = library.kana(c)!.romaji
                check(L.giriWrongKana(picked: rk, pickedKana: k, correct: c, correctRomaji: rc), 28)
            }
            check(L.giriWrongWord(kana: c, romaji: library.kana(c)!.romaji), 28)
        }
        #expect(over.isEmpty, "\(over)")
        withKnownIssue("giri-companion.md 3.11 고정 대사 일부가 한 문장 22자를 넘음 (designer·planner 확인)") {
            #expect(longSentences.isEmpty, "\(longSentences)")
        }
    }
}

@Suite("기리 대사 고르기")
struct GiriSpeechTests {
    @Test func particlesFollowFinalConsonant() {
        #expect(L.giriSceneStepB("메뉴") == "이제 메뉴를 읽어 볼까요?")
        #expect(L.giriSceneStepB("간판") == "이제 간판을 읽어 볼까요?")
        #expect(L.giriHomeFirst("스시집") == "첫 여행지는 스시집이에요. 같이 가 봐요")
        #expect(L.giriSceneDone("역") == "역은 이제 읽을 수 있어요")
        #expect(L.giriSceneDone("소바·우동집") == "소바·우동집은 이제 읽을 수 있어요")
        #expect(L.giriDoneStepA(step: "간판", next: "메뉴") == "간판 다 읽었어요. 다음은 메뉴예요")
    }

    /// 읽기 전 안내: 다시 읽기 단어 → 발음 표기 첫 단어 → 한자 → 보통 (giri-lines.md 4.2).
    @Test func readingContextOrder() {
        #expect(GiriSpeech.readingContext(isReread: true, previousStep: "간판", isFirstRuby: true, hasKanji: true)
            == .reread(previousStep: "간판"))
        #expect(GiriSpeech.readingContext(isReread: false, previousStep: "간판", isFirstRuby: true, hasKanji: true) == .firstRuby)
        #expect(GiriSpeech.readingContext(isReread: false, previousStep: nil, isFirstRuby: false, hasKanji: true) == .kanji)
        #expect(GiriSpeech.readingContext(isReread: false, previousStep: nil, isFirstRuby: false, hasKanji: false) == .plain)
        #expect(GiriSpeech.beforeReading(.reread(previousStep: "간판")) == "간판에서 본 단어예요. 다시 읽어 봐요")
        #expect(GiriSpeech.afterReading(nil, scene: "스시집", step: "메뉴") == "스시집 메뉴에서 볼 수 있어요")
        #expect(GiriSpeech.afterReading("설명", scene: "스시집", step: "메뉴") == "설명")
    }

    @Test func writingTipFallbacks() {
        #expect(GiriSpeech.writingTip(nil) == L.giriNoTip)
        #expect(GiriSpeech.writingTip("팁") == "팁")
        #expect(GiriSpeech.guideTip(nil) == L.giriGuideNoTip)
    }

    /// 질문: 다시 내는 문항 → 부의 첫 문항 → 질문.
    @Test func questionSelection() {
        #expect(GiriSpeech.question(kind: .readingChoice, isPartStart: false, isRetry: false) == L.giriAskKana)
        #expect(GiriSpeech.question(kind: .wordReading, isPartStart: true, isRetry: false) == L.giriPartWord)
        #expect(GiriSpeech.question(kind: .recallWrite, isPartStart: true, isRetry: false) == L.giriPartWrite)
        #expect(GiriSpeech.question(kind: .wordReading, isPartStart: true, isRetry: true) == L.giriRetryRead)
        #expect(GiriSpeech.question(kind: .recallWrite, isPartStart: false, isRetry: true) == L.giriRetryWrite)
    }

    /// QA 오답: 헷갈리는 쌍이면 쌍의 말, 아니면 틀 문구 (giri-lines.md 6.1).
    @Test func choiceWrongLine() {
        let pair = choiceItem("い", answer: "i", wrong: "ko", replacement: "こ")
        #expect(GiriSpeech.wrongAnswer(item: pair, picked: "ko", word: nil, lookup: library) == "い는 세로, こ는 가로로 놓여요")

        let plain = choiceItem("た", answer: "ta", wrong: "ko", replacement: "こ")
        #expect(GiriSpeech.wrongAnswer(item: plain, picked: "ko", word: nil, lookup: library) == "ko는 こ예요. た는 ta로 읽어요")

        // ん과 로마자 n은 받침으로 본다.
        let n = choiceItem("な", answer: "na", wrong: "n", replacement: "ん")
        #expect(GiriSpeech.wrongAnswer(item: n, picked: "n", word: nil, lookup: library) == "n은 ん이에요. な는 na로 읽어요")
        let toN = choiceItem("ん", answer: "n", wrong: "na", replacement: "な")
        #expect(GiriSpeech.wrongAnswer(item: toN, picked: "na", word: nil, lookup: library) == "na는 な예요. ん은 n으로 읽어요")

        // 바꿔 넣은 글자를 저장하기 전의 문항은 로마자로 글자를 찾는다.
        let legacy = choiceItem("い", answer: "i", wrong: "ko", replacement: nil)
        #expect(GiriSpeech.wrongAnswer(item: legacy, picked: "ko", word: nil, lookup: StubLookup()) == "쌍 짚기")
    }

    /// QD 오답: 원래 글자 k와 바꿔 넣은 글자 s가 쌍이면 쌍의 말, 아니면 "이 단어의 {k}는 {k의 로마자}예요".
    @Test func wordWrongLine() throws {
        let ika = try #require(library.word(text: "いか"))
        let (pairItem, pairPick) = wordItem(ika, index: 0, replacement: "こ")
        #expect(GiriSpeech.wrongAnswer(item: pairItem, picked: pairPick, word: ika, lookup: library) == "い는 세로, こ는 가로로 놓여요")

        let (plainItem, plainPick) = wordItem(ika, index: 1, replacement: "た")
        #expect(GiriSpeech.wrongAnswer(item: plainItem, picked: plainPick, word: ika, lookup: library) == "이 단어의 か는 ka예요")

        let tonkatsu = try #require(library.word(text: "とんかつ"))
        let (nItem, nPick) = wordItem(tonkatsu, index: 1, replacement: "つ")
        #expect(GiriSpeech.wrongAnswer(item: nItem, picked: nPick, word: tonkatsu, lookup: library) == "이 단어의 ん은 n이에요")
    }

    /// 앱이 만든 문항의 오답에는 바꿔 넣은 글자가 저장된다.
    @Test func builderStoresReplacement() {
        let quiz = library.makeQuiz(for: library.scene(id: "sushi")!, review: [])
        for part in quiz.parts where part.kind != .recallWrite {
            for item in part.items {
                for wrong in item.wrongs {
                    #expect(wrong.replacement != nil)
                    if part.kind == .readingChoice, let s = wrong.replacement {
                        #expect(library.kana(s)?.romaji == wrong.romaji)
                    }
                }
            }
        }
    }

    /// 홈과 장면 진입의 상태: 처음 → 단계 b → 하던 중 → 종합 퀴즈 → 다음 장면.
    @Test func homeAndSceneTurns() {
        let store = ProgressStore(storage: GiriMemoryStorage())
        let sushi = library.scene(id: "sushi")!
        let sessions = library.sessions(in: sushi)
        #expect(store.giriHomeTurn() == .first(scene: "스시집"))
        #expect(GiriSpeech.scene(store.giriSceneTurn(sushi)) == sushi.giriIntro)

        _ = SessionRun(session: sessions[0], store: store).complete()
        #expect(store.giriHomeTurn() == .stepB(scene: "스시집", step: sushi.steps[1].name))
        #expect(store.giriSceneTurn(sushi) == .stepB(step: sushi.steps[1].name))

        SessionRun(session: sessions[1], store: store).markLearnDone("い")
        #expect(store.giriHomeTurn() == .resume(scene: "스시집", session: sushi.steps[1].name))

        _ = SessionRun(session: sessions[1], store: store).complete()
        #expect(store.giriHomeTurn() == .quiz(scene: "스시집"))
        #expect(store.giriSceneTurn(sushi) == .quiz)

        let quiz = SessionRun(session: sessions[2], store: store)
        quiz.prepareQuiz()
        while quiz.progress.quiz?.currentItem != nil { quiz.answerCurrent(correct: true, wrongKana: nil) }
        _ = quiz.complete()
        let tonkatsu = library.scene(id: "tonkatsu")!
        #expect(store.giriHomeTurn() == .newScene(scene: tonkatsu.name, step: tonkatsu.steps[0].name))
        #expect(store.giriSceneTurn(sushi) == .done(scene: "스시집"))
    }

    @Test func completionLines() {
        #expect(GiriSpeech.completion(.scene(scene: "스시집", hadWrong: false, isLastScene: false)) == "스시집에서 본 글자, 이제 다 읽혀요")
        #expect(GiriSpeech.completion(.scene(scene: "스시집", hadWrong: true, isLastScene: false)) == L.giriDoneSceneWrong)
        #expect(GiriSpeech.completion(.scene(scene: "료칸", hadWrong: true, isLastScene: true)) == L.giriDoneAll)
        #expect(GiriSpeech.quizIntro(scene: "스시집", isReplay: false) == "스시집 마지막 차례예요. 헷갈린 건 한 번 더 나와요")
        #expect(GiriSpeech.quizIntro(scene: "스시집", isReplay: true) == L.giriQuizIntroReplay)
    }
}
