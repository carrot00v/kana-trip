import Foundation
import Testing
@testable import KanaTrip

// docs/content/quiz-rules.md의 규칙과 8번 예시(장면 1, 3)를 확인한다.
// 무작위 자리는 시드로 고정하고, 값이 아니라 등급과 칸 순서가 규칙대로인지 본다 (8번 머리말).

private let library = ContentLibrary.shared

private func scene(_ id: String) -> TripScene { library.scene(id: id)! }

private func builder(_ id: String, review: [String] = []) -> QuizBuilder {
    QuizBuilder(library: library, scene: scene(id), review: review)
}

private func romaji(_ char: String) -> String { library.kana(char)!.romaji }

/// 퀴즈를 끝까지 풀며 나온 문항 id 순서를 모은다. `wrong`이 true를 돌려주는 차례는 틀리게 답한다.
private func play(_ quiz: inout QuizProgress, recorded: inout [String],
                  wrong: (QuizItem, Bool) -> QuizItem.Wrong?? ) -> [(id: Int, retry: Bool)] {
    var order: [(Int, Bool)] = []
    var seen: Set<Int> = []
    while let item = quiz.currentItem {
        let retry = seen.contains(item.id)
        seen.insert(item.id)
        order.append((item.id, retry))
        if let picked = wrong(item, retry) {
            // 틀림: 고른 오답(나)이 있으면 그 오답의 원래 글자, 없으면(쓰기에서 가이드) 묻는 글자를 기록
            let char: String? = picked.map { item.wrongKana(picked: $0.romaji) } ?? item.kana
            if let char, !recorded.contains(char) { recorded.append(char) }
            quiz.answerCurrent(correct: false)
        } else {
            quiz.answerCurrent(correct: true)
        }
    }
    return order
}

@Suite("종합 퀴즈 규칙")
struct QuizRulesTests {
    // MARK: 3.2 복습 글자 끼우기

    @Test func reviewKanaAreSpreadBetweenNewKana() {
        let new = ["1", "2", "3", "4", "5", "6"]
        #expect(QuizBuilder.interleave(new, ["a"]) == ["1", "2", "3", "a", "4", "5", "6"])
        #expect(QuizBuilder.interleave(new, ["a", "b"]) == ["1", "2", "a", "3", "4", "b", "5", "6"])
        #expect(QuizBuilder.interleave(new, ["a", "b", "c"]) == ["1", "a", "2", "3", "b", "4", "c", "5", "6"])
        let five = Array(new.prefix(5))
        #expect(QuizBuilder.interleave(five, ["a"]) == ["1", "2", "a", "3", "4", "5"])
        #expect(QuizBuilder.interleave(five, ["a", "b"]) == ["1", "a", "2", "3", "b", "4", "5"])
        #expect(QuizBuilder.interleave(five, ["a", "b", "c"]) == ["1", "a", "2", "b", "3", "c", "4", "5"])
    }

    // MARK: 3.5 단어 문항 (복습 없음)

    @Test func wordItemsMatchTableWithoutReview() {
        let expected: [String: [String]] = [
            "sushi": ["すし", "いか", "たこ"],
            "tonkatsu": ["とんかつ", "ひれかつ", "すし"],
            "soba": ["きつね", "かけ", "とんかつ"],
            "station": ["のりかえ", "こちら", "おかめ"],
            "shrine": ["おまもり", "たこやき", "えき", "すし"],
            "izakaya": ["つくね", "かわ", "おまいり", "おかわり"],
            "onsen": ["おんせん", "ゆかた", "やきとり", "たぬき"],
            "ryokan": ["おふろ", "おもてなし", "ひのき", "おろし"],
        ]
        for (id, words) in expected {
            #expect(builder(id).selectedWords().map(\.text) == words, "\(id)")
        }
    }

    @Test func eligibleWordsHaveNoRubyOrKanji() {
        let l1 = QuizBuilder.learned(through: scene("sushi"), library: library)
        let sushi = scene("sushi")
        #expect(sushi.words.filter { QuizBuilder.isEligible($0, learned: l1) }.map(\.text) == ["すし", "いか", "たこ"])
        let ryokan = scene("ryokan")
        let l8 = QuizBuilder.learned(through: ryokan, library: library)
        // ようこそ(장음 표기), ほうじ茶(한자)는 자격이 없다.
        #expect(!ryokan.words.contains { ["ようこそ", "ほうじ茶"].contains($0.text) && QuizBuilder.isEligible($0, learned: l8) })
        #expect(!QuizBuilder.isEligible(library.word(text: "ゆ")!, learned: l8))
        #expect(!QuizBuilder.isEligible(library.word(text: "くつをぬいでください")!, learned: l8))
    }

    // MARK: 8.1 장면 1 스시집

    @Test func scene1ItemsFollowTiers() throws {
        var rng = SeededGenerator(seed: 1)
        let b = builder("sushi")
        let quiz = b.make(using: &rng)
        #expect(quiz.parts.map(\.kind) == [.readingChoice, .wordReading, .recallWrite])
        #expect(quiz.parts.map(\.items.count) == [6, 3, 6])
        #expect(quiz.totalCount == 15)
        #expect(Set(quiz.parts[0].items.compactMap(\.kana)) == Set(["す", "し", "い", "か", "た", "こ"]))

        // (가): こ와 い는 서로가 오답에 반드시 들어간다(짝). 오답 3개, 서로 다른 로마자, 정답과 다름.
        for item in quiz.parts[0].items {
            let wrongs = item.wrongs.map(\.romaji)
            #expect(wrongs.count == 3)
            #expect(Set(wrongs).count == 3)
            #expect(!wrongs.contains(item.answer))
            if item.kana == "こ" { #expect(wrongs.contains("i")) }
            if item.kana == "い" { #expect(wrongs.contains("ko")) }
        }

        // (라): 바꿀 칸 순서와 짝 우선.
        let words = Dictionary(uniqueKeysWithValues: quiz.parts[1].items.map { ($0.word!, $0) })
        let sushi = try #require(words["すし"])
        #expect(sushi.wrongs.map(\.changedIndex) == [0, 1, 0])
        let ika = try #require(words["いか"])
        #expect(ika.wrongs.map(\.changedIndex) == [0, 1, 0])
        #expect(ika.wrongs[0].romaji == "koka")
        #expect(ika.wrongs[0].original == "い")
        let tako = try #require(words["たこ"])
        #expect(tako.wrongs.map(\.changedIndex) == [1, 0, 1])
        #expect(tako.wrongs[0].romaji == "tai")
        for item in quiz.parts[1].items {
            #expect(Set(item.wrongs.map(\.romaji)).count == 3)
            #expect(!item.wrongs.map(\.romaji).contains(item.answer))
        }
    }

    /// 8.1의 진행 예: 1부 こ, 2부 いか에서 koka, 3부 す에서 가이드 → 부 끝에 다시 내고, 틀린 글자 {こ, い, す}.
    @Test func scene1WrongAnswersAreRetriedAtPartEnd() {
        var rng = SeededGenerator(seed: 7)
        var quiz = builder("sushi").make(using: &rng)
        var recorded: [String] = []
        let order = play(&quiz, recorded: &recorded) { item, retry in
            guard !retry else { return nil }
            switch item.kind {
            case .readingChoice: return item.kana == "こ" ? .some(nil) : nil
            case .wordReading: return item.word == "いか" ? .some(item.wrongs.first { $0.romaji == "koka" }) : nil
            case .recallWrite: return item.kana == "す" ? .some(nil) : nil
            }
        }
        // 처음 문항 15 + 다시 낸 문항 3.
        #expect(order.count == 18)
        // 다시 낸 문항은 각 부의 끝(1부 7번째, 2부 4번째, 3부 7번째 차례)에 나온다.
        #expect(order.enumerated().filter(\.element.retry).map(\.offset) == [6, 10, 17])
        let part1 = quiz.parts[0], part2 = quiz.parts[1], part3 = quiz.parts[2]
        #expect(part1.item(id: order[6].id)?.kana == "こ")
        #expect(part2.item(id: order[10].id)?.word == "いか")
        #expect(part3.item(id: order[17].id)?.kana == "す")
        #expect(Set(recorded) == ["こ", "い", "す"])
        #expect(quiz.isFinished)

        var waiting: [String: Int] = [:]
        ReviewQueue.update(&waiting, review: [], wrong: recorded, sceneOrder: 1)
        #expect(waiting == ["す": 1, "い": 1, "こ": 1])
        #expect(ReviewQueue.pick(from: waiting, sceneOrder: 2, learnOrder: library.learnOrder(of:)) == ["す", "い", "こ"])
    }

    // MARK: 8.2 장면 3 소바·우동집 (복습 3자)

    @Test func scene3ReviewPickAndPlacement() throws {
        let waiting = ["し": 2, "お": 2, "ひ": 2, "れ": 2]
        let review = ReviewQueue.pick(from: waiting, sceneOrder: 3, learnOrder: library.learnOrder(of:))
        #expect(review == ["し", "お", "ひ"])

        var rng = SeededGenerator(seed: 3)
        let b = builder("soba", review: review)
        let quiz = b.make(using: &rng)
        #expect(quiz.parts.map(\.items.count) == [9, 3, 9])
        #expect(quiz.totalCount == 21)
        // 복습 글자는 새 글자 1, 3, 4개 뒤 → 2, 5, 7번째 문항 (첫·마지막 문항이 아님).
        for part in [quiz.parts[0], quiz.parts[2]] {
            let reviewPositions = part.items.enumerated().filter(\.element.isReview).map(\.offset)
            #expect(reviewPositions == [1, 4, 6])
            #expect(Set(part.items.filter(\.isReview).compactMap(\.kana)) == Set(review))
        }
        #expect(quiz.parts[1].items.map(\.word) == ["きつね", "かけ", "ひれかつ"])

        // 1부 ね: 짝 れ가 오답에. し(복습): 짝 つ가 오답에. め: 짝 ぬ는 아직 없음.
        for item in quiz.parts[0].items {
            if item.kana == "ね" { #expect(item.wrongs.map(\.romaji).contains("re")) }
            if item.kana == "し" { #expect(item.wrongs.map(\.romaji).contains("tsu")) }
            if item.kana == "め" { #expect(!item.wrongs.map(\.romaji).contains("nu")) }
        }

        let words = Dictionary(uniqueKeysWithValues: quiz.parts[1].items.map { ($0.word!, $0) })
        let kitsune = try #require(words["きつね"])
        #expect(kitsune.wrongs.map(\.changedIndex) == [1, 2, 0])
        #expect(kitsune.wrongs[0].romaji == "kishine")
        #expect(kitsune.wrongs[1].romaji == "kitsure")
        let kake = try #require(words["かけ"])
        #expect(kake.wrongs.map(\.changedIndex) == [1, 0, 1])
        let hirekatsu = try #require(words["ひれかつ"])
        #expect(hirekatsu.wrongs.map(\.changedIndex) == [1, 3, 0])
        #expect(hirekatsu.wrongs[0].romaji == "hinekatsu")
        #expect(hirekatsu.wrongs[1].romaji == "hirekashi")
        // 3칸째 오답은 ひ를 Q의 글자로 바꾼다.
        let third = hirekatsu.wrongs[2]
        #expect(third.original == "ひ")
        let replaced = String(third.romaji.dropLast("rekatsu".count))
        #expect(b.quizKana.map(romaji).contains(replaced))
    }

    /// 8.2의 진행 예: ね, きつね의 kishine(→ つ 기록), お 가이드 → 대기 목록 {れ: 2, つ: 3, お: 3, ね: 3}.
    @Test func scene3WaitingListUpdateAndScene4Review() {
        var rng = SeededGenerator(seed: 11)
        var quiz = builder("soba", review: ["し", "お", "ひ"]).make(using: &rng)
        var recorded: [String] = []
        let order = play(&quiz, recorded: &recorded) { item, retry in
            guard !retry else { return nil }
            switch item.kind {
            case .readingChoice: return item.kana == "ね" ? .some(nil) : nil
            case .wordReading: return item.word == "きつね" ? .some(item.wrongs.first { $0.romaji == "kishine" }) : nil
            case .recallWrite: return item.kana == "お" ? .some(nil) : nil
            }
        }
        #expect(order.count == 24)
        #expect(order.enumerated().filter(\.element.retry).map(\.offset) == [9, 13, 23])
        #expect(Set(recorded) == ["ね", "つ", "お"])

        var waiting = ["し": 2, "お": 2, "ひ": 2, "れ": 2]
        ReviewQueue.update(&waiting, review: ["し", "お", "ひ"], wrong: recorded, sceneOrder: 3)
        #expect(waiting == ["れ": 2, "つ": 3, "お": 3, "ね": 3])
        let review4 = ReviewQueue.pick(from: waiting, sceneOrder: 4, learnOrder: library.learnOrder(of:))
        #expect(review4 == ["れ", "つ", "お"])
        // 장면 4의 2부 (2)는 R을 담은 장면 3 단어 가운데 (1)에서 안 쓴 おかめ.
        #expect(builder("station", review: review4).selectedWords().map(\.text) == ["のりかえ", "こちら", "おかめ"])
    }

    // MARK: 4.3 제약

    @Test func wordWrongsChangeExactlyOneUnitAndAvoidNAmbiguity() throws {
        var rng = SeededGenerator(seed: 5)
        for id in library.scenes.map(\.id) {
            let b = builder(id)
            for word in b.selectedWords() {
                let wrongs = b.wordWrongs(for: word, using: &rng)
                #expect(wrongs.count == 3, "\(word.text)")
                for wrong in wrongs {
                    let index = try #require(wrong.changedIndex)
                    let original = word.units.map(\.romaji)
                    #expect(wrong.original == word.units[index].kana)
                    #expect(wrong.romaji != original.joined())
                    // n 뒤 모음·y행은 쓰지 않는다.
                    if index > 0, word.units[index - 1].kana == "ん" {
                        #expect(!["a", "i", "u", "e", "o", "ya", "yu", "yo"].contains { wrong.romaji.hasPrefix(original.prefix(index).joined() + $0) })
                    }
                }
            }
        }
    }
}

/// 메모리에만 저장하는 저장소.
private final class MemoryStorage: ProgressStorage {
    var saved: ProgressState?
    func load() -> ProgressState? { saved }
    func save(_ state: ProgressState) { saved = state }
}

@Suite("종합 퀴즈 저장")
struct QuizStorageTests {
    /// 단계 b의 단어 읽기 맨 앞에 단계 a의 첫 단어를 다시 읽는다 (quiz-rules.md 9.2).
    @Test func stepBStartsWithStepAFirstWord() {
        let store = ProgressStore(storage: MemoryStorage())
        let sessions = library.sessions(in: scene("sushi"))
        let b = SessionRun(session: sessions[1], store: store)
        #expect(b.orderedWords.map(\.text) == ["すし", "いか", "たこ", "いくら", "まぐろ", "えび", "いなり"])
        let a = SessionRun(session: sessions[0], store: store)
        #expect(a.orderedWords.map(\.text) == ["すし"])
    }

    /// 퀴즈를 통과하면 장면별 틀린 글자와 복습 대기 목록이 고쳐지고, 다음 장면 퀴즈의 복습 글자가 된다.
    @Test func passingQuizUpdatesWaitingListAndNextReview() throws {
        let storage = MemoryStorage()
        let store = ProgressStore(storage: storage)
        let sessions = library.sessions(in: scene("sushi"))
        _ = SessionRun(session: sessions[0], store: store).complete()
        _ = SessionRun(session: sessions[1], store: store).complete()

        let run = SessionRun(session: sessions[2], store: store)
        run.prepareQuiz()
        let quiz = try #require(run.progress.quiz)
        #expect(quiz.review.isEmpty)
        // 첫 문항을 틀리고 나머지는 맞힌다.
        var first = true
        while let item = run.progress.quiz?.currentItem {
            if first {
                run.answerCurrent(correct: false, wrongKana: item.kana)
                first = false
            } else {
                run.answerCurrent(correct: true, wrongKana: nil)
            }
        }
        let wrongChar = try #require(quiz.parts[0].items.first?.kana)
        // 나갔다 들어와도 문항 목록이 같다.
        #expect(storage.saved?.sessions["sushi-quiz"]?.quiz?.parts == run.progress.quiz?.parts)
        let grant = run.complete()
        #expect(grant.coins == 100)
        #expect(store.wrongKana(sceneID: "sushi") == [wrongChar])
        #expect(storage.saved?.reviewQueue == [wrongChar: 1])
        #expect(store.reviewKana(for: scene("tonkatsu")) == [wrongChar])
        #expect(store.isSceneCompleted(scene("sushi")))

        // 다시 하는 퀴즈는 복습 글자 없이, 대기 목록을 바꾸지 않는다.
        let replay = SessionRun(session: sessions[2], store: store)
        #expect(replay.isReplay)
        replay.prepareQuiz()
        #expect(replay.progress.quiz?.review.isEmpty == true)
        #expect(storage.saved?.sessions["sushi-quiz"]?.quiz == nil)
    }
}
