import Testing
@testable import KanaTrip

@Suite("장면 데이터")
struct SceneContentTests {
    private let library = ContentLibrary.shared

    @Test func everyStepKanaAppearsInItsWords() {
        for step in library.steps where step.hasContent {
            let used = Set(step.words.flatMap(\.kanaUnits).map(\.kana))
            let missing = step.kana.filter { !used.contains($0) }
            #expect(missing.isEmpty, "\(step.id): 단어에 안 나오는 새 글자 \(missing)")
        }
    }

    @Test func stepsAreOrderedAndNamed() {
        #expect(library.scenes.map(\.id) == ["sushi", "tonkatsu", "soba", "station", "shrine", "izakaya", "onsen", "ryokan"])
        #expect(library.steps.count == 16)
        for scene in library.scenes {
            #expect(scene.steps.map(\.id) == ["\(scene.id)-a", "\(scene.id)-b"])
        }
        #expect(Set(library.steps.flatMap(\.kana)).count == 46)
        #expect(library.steps.flatMap(\.kana).count == 46)
    }

    /// 3a는 전부 읽히는 단어가 없어 단어를 그대로 목표 단어로 보여 준다 (hiragana-allocation.md 8번).
    @Test func stepWithoutReadableWordsStillShowsWords() throws {
        let step = try #require(library.step(id: "soba-a"))
        #expect(library.wordGroups(for: step).goal.isEmpty)
        #expect(library.shownGoalWords(for: step).map(\.text) == ["うどん", "そば"])
    }

    @Test func kanjiUnitsAreNeverTaughtKana() {
        let taught = Set(library.steps.flatMap(\.kana))
        for scene in library.scenes {
            for word in scene.words {
                for unit in word.units where unit.isKanji {
                    #expect(!taught.contains(unit.kana), "\(word.text)의 \(unit.kana)가 가르치는 글자로 표시됨")
                    #expect(!unit.romaji.isEmpty, "\(word.text)의 \(unit.kana)에 발음이 없음")
                }
            }
        }
    }

    @Test func wordTextMatchesUnits() {
        for scene in library.scenes {
            for word in scene.words {
                #expect(word.units.map(\.kana).joined() == word.text, "\(word.text)의 칸이 표기와 다름")
            }
        }
    }

    /// 한자를 붙여 쓴 단어도 가나만 다 배우면 목표 단어가 된다. 한자는 배운 글자 수에 들지 않는다.
    @Test func kanjiDoesNotBlockGoalWord() throws {
        let step = try #require(library.steps.first { $0.words.contains { $0.text == "かつ丼" } })
        let word = try #require(step.words.first { $0.text == "かつ丼" })
        #expect(word.kanaUnits.count == 2)
        #expect(library.wordGroups(for: step).goal.contains { $0.text == "かつ丼" })
        #expect(word.count(in: library.kana(through: step)) == word.kanaUnits.count)
    }

    /// 단어 그림 이름: 그림이 있는 44개 단어에만 있다. ひのき는 word-ofuro를 같이 쓴다 (word-images.md, word-art.md 9.2).
    @Test func wordArtNames() {
        let words = library.steps.flatMap(\.words)
        #expect(words.count { $0.art != nil } == 44)
        let art = Dictionary(uniqueKeysWithValues: words.map { ($0.text, $0.art) })
        #expect(art["とんかつ"] == "tonkatsu")
        #expect(art["きつね"] == "kitsune")
        #expect(art["くつをぬいでください"] == "kutsuonuide")
        #expect(art["ひのき"] == "ofuro")
        #expect(art["おかわり"] == .some(nil))
    }
}

@Suite("세션 구조")
struct SessionStructureTests {
    private let library = ContentLibrary.shared

    @Test func everySceneHasTwoStepsAndAQuiz() {
        #expect(library.sessions.count == 24)
        for scene in library.scenes {
            #expect(library.sessions(in: scene).map(\.id) == ["\(scene.id)-a", "\(scene.id)-b", "\(scene.id)-quiz"])
        }
    }
}
