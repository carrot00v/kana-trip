import Testing
@testable import KanaTrip

/// 단어 블록의 줄 바꿈 단위: 읽기의 띄어 쓴 낱말과 글자 로마자가 맞아야 낱말 사이에서만 줄이 바뀐다.
struct WordBlockTests {
    @Test func everyWordGroupsByReading() {
        // 한 낱말 단어(띄어쓰기 없음)는 묶음이 하나든 글자마다든 줄 바꿈 결과가 같아서 띄어 쓴 단어만 본다.
        for word in ContentLibrary.shared.scenes.flatMap(\.words) where word.reading.contains(" ") {
            let groups = WordBlock.groups(word)
            let tokens = word.reading.split(separator: " ")
            #expect(groups.count == tokens.count, "\(word.text) \(word.reading) → \(groups)")
            #expect(groups.flatMap { $0 } == Array(word.units.indices))
        }
    }

    @Test func longPhraseBreaksBetweenWords() throws {
        let word = try #require(ContentLibrary.shared.scenes.flatMap(\.words).first { $0.text == "くつをぬいでください" })
        #expect(WordBlock.groups(word) == [[0, 1], [2], [3, 4, 5], [6, 7, 8, 9]])
    }
}
