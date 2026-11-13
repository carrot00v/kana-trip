import Testing
@testable import KanaTrip

@Suite("장면 데이터")
struct SceneContentTests {
    private let library = ContentLibrary.shared

    @Test func everySceneKanaAppearsInItsWords() {
        for scene in library.scenes where scene.hasContent {
            let used = Set(scene.words.flatMap(\.kanaUnits).map(\.kana))
            let missing = scene.kana.filter { !used.contains($0) }
            #expect(missing.isEmpty, "\(scene.name): 단어에 안 나오는 새 글자 \(missing)")
        }
    }

    @Test func kanjiUnitsAreNeverTaughtKana() {
        let taught = Set(library.scenes.flatMap(\.kana))
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
        let scene = try #require(library.scenes.first { $0.words.contains { $0.text == "かつ丼" } })
        let word = try #require(scene.words.first { $0.text == "かつ丼" })
        #expect(word.kanaUnits.count == 2)
        #expect(library.wordGroups(for: scene).goal.contains { $0.text == "かつ丼" })
        #expect(word.count(in: library.learnedKana(through: scene)) == word.kanaUnits.count)
    }
}
