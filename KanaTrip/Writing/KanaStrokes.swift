import CoreGraphics
import Foundation

/// 가나 한 글자와 그 획. 획 좌표는 KanjiVG의 109x109 좌표계이고, 점 순서가 쓰는 방향이다.
struct Kana: Identifiable {
    let char: String
    let romaji: String
    let strokes: [[CGPoint]]
    /// 이 글자를 쓸 때의 주요 포인트. 없는 글자도 있다.
    let tip: String?

    var id: String { char }
}

enum KanaStrokeStore {
    /// 획 좌표계의 한 변 길이.
    static let viewBox: CGFloat = 109

    static func loadHiragana() -> [Kana] {
        load(resource: "hiragana_strokes", tips: "hiragana_tips")
    }

    private struct File: Decodable {
        struct Entry: Decodable {
            let char: String
            let romaji: String
            let strokes: [[[Double]]]
        }
        let kana: [Entry]
    }

    private static func load(resource: String, tips tipsResource: String) -> [Kana] {
        var tips: [String: String] = [:]
        if let url = Bundle.main.url(forResource: tipsResource, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            tips = decoded
        }
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            assertionFailure("\(resource).json을 읽지 못함")
            return []
        }
        return file.kana.map { entry in
            Kana(
                char: entry.char,
                romaji: entry.romaji,
                strokes: entry.strokes.map { $0.map { CGPoint(x: $0[0], y: $0[1]) } },
                tip: tips[entry.char]
            )
        }
    }
}
