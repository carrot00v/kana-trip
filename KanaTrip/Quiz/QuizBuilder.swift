import Foundation

// 종합 퀴즈의 문항 만들기 (docs/content/quiz-rules.md 1, 3, 4번).
// SwiftUI에 의존하지 않는다. 무작위 자리는 난수를 받아 테스트에서 시드로 재현한다.

struct QuizBuilder {
    let library: ContentLibrary
    let scene: TripScene
    /// 복습 글자(R). 끝낸 퀴즈를 다시 하면 비운다.
    let review: [String]

    /// 이 장면까지 배운 글자(L): 앞 장면들의 새 글자 + 이 장면의 새 글자.
    let learned: Set<String>
    /// 이 장면의 새 글자(N). 단계 순서.
    var newKana: [String] { scene.kana }
    /// 이 퀴즈의 글자(Q) = N + R.
    let quizKana: Set<String>

    init(library: ContentLibrary, scene: TripScene, review: [String]) {
        self.library = library
        self.scene = scene
        self.review = review
        learned = Self.learned(through: scene, library: library)
        quizKana = Set(scene.kana + review)
    }

    static func learned(through scene: TripScene, library: ContentLibrary) -> Set<String> {
        library.kana(before: scene).union(scene.kana)
    }

    /// 단어 문항 수: 장면 1은 이 장면 3개, 그 뒤는 이 장면 2개 + 직전 장면 1개, 장면 5부터 지난 장면 1개 더 (3.1).
    static func thisSceneWordCount(_ scene: TripScene) -> Int { scene.order == 1 ? 3 : 2 }

    // MARK: - 문항 전체

    func make<R: RandomNumberGenerator>(using rng: inout R) -> QuizProgress {
        var nextID = 0
        func newID() -> Int { defer { nextID += 1 }; return nextID }

        let first = Self.interleave(newKana.shuffled(using: &rng), review.shuffled(using: &rng))
        let reading = first.map { char in
            QuizItem(id: newID(), kind: .readingChoice, kana: char, word: nil,
                     answer: romaji(char), wrongs: charWrongs(for: char, using: &rng), isReview: review.contains(char))
        }
        let words = selectedWords().map { word in
            QuizItem(id: newID(), kind: .wordReading, kana: nil, word: word.text,
                     answer: word.units.map(\.romaji).joined(), wrongs: wordWrongs(for: word, using: &rng), isReview: false)
        }
        let third = Self.interleave(newKana.shuffled(using: &rng), review.shuffled(using: &rng))
        let writing = third.map { char in
            QuizItem(id: newID(), kind: .recallWrite, kana: char, word: nil,
                     answer: romaji(char), wrongs: [], isReview: review.contains(char))
        }
        return QuizProgress(
            kana: newKana,
            review: review,
            parts: [
                QuizProgress.Part(kind: .readingChoice, items: reading),
                QuizProgress.Part(kind: .wordReading, items: words),
                QuizProgress.Part(kind: .recallWrite, items: writing),
            ].filter { !$0.items.isEmpty }
        )
    }

    /// 1부·3부 순서 (3.2): i번째 복습 글자를 새 글자 `floor(i × n ÷ (r + 1))`개 뒤에 끼운다.
    static func interleave(_ new: [String], _ review: [String]) -> [String] {
        let n = new.count, r = review.count
        var result: [String] = []
        var inserted = 0
        for (index, char) in new.enumerated() {
            result.append(char)
            while inserted < r, (inserted + 1) * n / (r + 1) == index + 1 {
                result.append(review[inserted])
                inserted += 1
            }
        }
        // n이 0이면(없는 경우) 남은 복습 글자를 뒤에 둔다.
        result += review.dropFirst(inserted)
        return result
    }

    // MARK: - 2부 단어 (3.3, 3.4)

    /// 자격 있는 단어: 모든 칸이 L의 기본 글자, 두 칸 이상, 칸 로마자를 이으면 읽기와 같다.
    static func isEligible(_ word: TripWord, learned: Set<String>) -> Bool {
        word.units.count >= 2
            && word.units.allSatisfy { !$0.isKanji && learned.contains($0.kana) }
            && word.units.map(\.romaji).joined() == word.reading
    }

    /// 2부의 단어. (1) 이 장면 → (2) 직전 장면 → (3) 지난 장면 순서.
    func selectedWords() -> [TripWord] {
        var result = Self.thisSceneWords(scene, library: library)
        if let previous = library.scene(before: scene), let word = previousSceneWord(previous) {
            result.append(word)
        }
        if scene.order >= 5, let word = olderSceneWord() {
            result.append(word)
        }
        return result
    }

    /// (1) 이 장면 단어: 아직 고른 단어에 없는 N의 글자를 많이 담은 단어 → 데이터 순서. 복습 글자와 무관하다.
    static func thisSceneWords(_ scene: TripScene, library: ContentLibrary) -> [TripWord] {
        let learned = learned(through: scene, library: library)
        var candidates = scene.words.filter { isEligible($0, learned: learned) }
        var covered: Set<String> = []
        var picked: [TripWord] = []
        let newKana = Set(scene.kana)
        while picked.count < thisSceneWordCount(scene), !candidates.isEmpty {
            let score = { (word: TripWord) in Set(word.units.map(\.kana)).intersection(newKana).subtracting(covered).count }
            let best = candidates.indices.max { score(candidates[$0]) < score(candidates[$1]) || (score(candidates[$0]) == score(candidates[$1]) && $0 > $1) }!
            let word = candidates.remove(at: best)
            picked.append(word)
            covered.formUnion(word.units.map(\.kana))
        }
        return picked
    }

    private func distinctCount(_ word: TripWord, in set: Set<String>) -> Int {
        Set(word.units.map(\.kana)).intersection(set).count
    }

    /// 자기 장면의 L로는 자격이 없었는데 지금 L로 자격이 생긴 단어인지.
    private func isNewlyReadable(_ word: TripWord, ownScene: TripScene) -> Bool {
        !Self.isEligible(word, learned: Self.learned(through: ownScene, library: library))
    }

    /// 정렬 키를 위에서부터 비교해 가장 앞서는 후보. 키가 모두 같으면 먼저 온 후보.
    private func best(_ candidates: [(word: TripWord, keys: [Int])]) -> TripWord? {
        candidates.enumerated().min { a, b in
            a.element.keys != b.element.keys ? a.element.keys.lexicographicallyPrecedes(b.element.keys) : a.offset < b.offset
        }?.element.word
    }

    /// (2) 직전 장면 단어 1개.
    private func previousSceneWord(_ previous: TripScene) -> TripWord? {
        let usedThere = Set(Self.thisSceneWords(previous, library: library).map(\.text))
        let candidates = previous.words.filter { Self.isEligible($0, learned: learned) }.map { word in
            (word, [
                -distinctCount(word, in: Set(review)),
                -distinctCount(word, in: Set(newKana)),
                isNewlyReadable(word, ownScene: previous) ? 0 : 1,
                usedThere.contains(word.text) ? 1 : 0,
            ])
        }
        return best(candidates)
    }

    /// (3) 지난 장면 단어 1개 (장면 5부터). 후보는 장면 1 ~ k−2.
    private func olderSceneWord() -> TripWord? {
        let older = library.scenes.filter { $0.order <= scene.order - 2 }
        var candidates: [(word: TripWord, keys: [Int])] = []
        for other in older {
            let usedThere = Set(Self.thisSceneWords(other, library: library).map(\.text))
            for word in other.words where Self.isEligible(word, learned: learned) {
                candidates.append((word, [
                    -distinctCount(word, in: Set(review)),
                    -distinctCount(word, in: Set(newKana)),
                    isNewlyReadable(word, ownScene: other) ? 0 : 1,
                    other.order == scene.order - 4 ? 0 : 1,
                    usedThere.contains(word.text) ? 1 : 0,
                ]))
            }
        }
        return best(candidates)
    }

    // MARK: - 오답 (4번)

    private func romaji(_ char: String) -> String {
        library.kana(char)?.romaji ?? char
    }

    /// 헷갈리는 짝 가운데 L에 있는 글자.
    func partners(of char: String) -> Set<String> {
        library.confusablePartners(of: char).intersection(learned)
    }

    /// (가)의 오답 3개: 헷갈리는 짝 → Q의 다른 글자 → L의 나머지. 같은 등급 안에서는 무작위.
    func charWrongs<R: RandomNumberGenerator>(for char: String, using rng: inout R) -> [QuizItem.Wrong] {
        let tiers = [partners(of: char), quizKana, learned].map { Array($0.subtracting([char])).sorted().shuffled(using: &rng) }
        var used: Set<String> = [romaji(char)]
        var result: [QuizItem.Wrong] = []
        for candidate in tiers.joined() where result.count < 3 {
            let r = romaji(candidate)
            guard !used.contains(r) else { continue }
            used.insert(r)
            result.append(QuizItem.Wrong(romaji: r, changedIndex: nil, original: nil))
        }
        assert(result.count == 3, "오답 후보가 모자람: \(char)")
        return result
    }

    /// (라)의 바꿀 칸 순서: 헷갈리는 짝이 L에 있는 칸 → Q에 드는 칸 → 나머지. 같은 등급 안에서는 왼쪽부터.
    func changeOrder(for word: TripWord) -> [Int] {
        let indices = Array(word.units.indices)
        let first = indices.filter { !partners(of: word.units[$0].kana).isEmpty }
        let second = indices.filter { !first.contains($0) && quizKana.contains(word.units[$0].kana) }
        let rest = indices.filter { !first.contains($0) && !second.contains($0) }
        return first + second + rest
    }

    /// (라)의 오답 3개. 칸 하나만 다른 글자로 바꾼 로마자이고, 어느 칸을 바꿨는지 함께 둔다.
    func wordWrongs<R: RandomNumberGenerator>(for word: TripWord, using rng: inout R) -> [QuizItem.Wrong] {
        let units = word.units
        let answer = units.map(\.romaji).joined()
        let order = changeOrder(for: word)
        guard !order.isEmpty else { return [] }
        var result: [QuizItem.Wrong] = []
        var usedAt: [Int: Set<String>] = [:]
        var slot = 0
        var attempts = 0
        while result.count < 3, attempts < order.count * 3 + 3 {
            let position = order[slot % order.count]
            slot += 1
            attempts += 1
            let original = units[position].kana
            let afterN = position > 0 && units[position - 1].kana == "ん"
            let tiers = [partners(of: original), quizKana, learned].map {
                Array($0.subtracting([original])).sorted().shuffled(using: &rng)
            }
            for candidate in tiers.joined() {
                guard candidate != "ん",
                      !(afterN && "あいうえおやゆよ".contains(candidate)),
                      romaji(candidate) != units[position].romaji,
                      !(usedAt[position]?.contains(candidate) ?? false)
                else { continue }
                var parts = units.map(\.romaji)
                parts[position] = romaji(candidate)
                let made = parts.joined()
                guard made != answer, !result.contains(where: { $0.romaji == made }) else { continue }
                usedAt[position, default: []].insert(candidate)
                result.append(QuizItem.Wrong(romaji: made, changedIndex: position, original: original))
                break
            }
        }
        return result
    }
}

extension ContentLibrary {
    /// 장면의 종합 퀴즈를 만든다. 복습 글자는 진도에서 고른 값(다시 하기면 빈 배열).
    func makeQuiz(for scene: TripScene, review: [String]) -> QuizProgress {
        var rng = SystemRandomNumberGenerator()
        return QuizBuilder(library: self, scene: scene, review: review).make(using: &rng)
    }

    /// 배우는 순서(1a → 8b, 단계 안 배우기 순서)의 자리. 복습 글자를 고를 때 쓴다.
    func learnOrder(of char: String) -> Int {
        steps.flatMap(\.kana).firstIndex(of: char) ?? .max
    }
}
