import Foundation

/// 장면에 실리는 단어 하나.
struct TripWord: Decodable, Identifiable {
    struct Unit: Decodable {
        let kana: String
        let romaji: String
    }

    let text: String
    /// 글자 하나씩의 발음. 아직 배우지 않은 글자 위에 표기할 때 쓴다.
    let units: [Unit]
    let reading: String
    let meaning: String
    /// 확인 후에 보이는 보조 설명(어디서 보는지, 장음 안내). 없는 단어도 있다.
    let note: String?

    var id: String { text }
}

/// 장면 하나. 단어가 없으면 아직 내용이 준비되지 않은 장면이다.
struct TripScene: Decodable, Identifiable {
    let id: String
    let order: Int
    let name: String
    /// SF Symbols 이름. 아직 정하지 않은 장면은 없다.
    let icon: String?
    let kana: [String]
    let words: [TripWord]

    var hasContent: Bool { !words.isEmpty }

    private enum CodingKeys: String, CodingKey {
        case id, order, name, icon, kana, words
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        order = try c.decode(Int.self, forKey: .order)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
        kana = try c.decode([String].self, forKey: .kana)
        words = try c.decodeIfPresent([TripWord].self, forKey: .words) ?? []
    }
}

/// 번들에 든 장면·글자 데이터. 앱이 켜질 때 한 번 읽는다.
final class ContentLibrary {
    static let shared = ContentLibrary()

    let sectionTitle: String
    let scenes: [TripScene]
    private let kanaByChar: [String: Kana]

    private struct File: Decodable {
        let title: String
        let scenes: [TripScene]
    }

    private init() {
        let all = KanaStrokeStore.loadHiragana()
        kanaByChar = Dictionary(all.map { ($0.char, $0) }, uniquingKeysWith: { first, _ in first })

        if let url = Bundle.main.url(forResource: "hiragana_scenes", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(File.self, from: data) {
            sectionTitle = file.title
            scenes = file.scenes.sorted { $0.order < $1.order }
        } else {
            assertionFailure("hiragana_scenes.json을 읽지 못함")
            sectionTitle = ""
            scenes = []
        }
    }

    func scene(id: String) -> TripScene? {
        scenes.first { $0.id == id }
    }

    func scene(after scene: TripScene) -> TripScene? {
        scenes.first { $0.order == scene.order + 1 }
    }

    func scene(before scene: TripScene) -> TripScene? {
        scenes.first { $0.order == scene.order - 1 }
    }

    func kana(_ char: String) -> Kana? {
        kanaByChar[char]
    }

    /// 장면의 새 글자를 획 데이터와 함께 돌려준다.
    func kana(for scene: TripScene) -> [Kana] {
        scene.kana.compactMap { kanaByChar[$0] }
    }

    /// 이 장면까지 배운 글자. 단어 위 발음 표기를 붙일지 정할 때 쓴다.
    func learnedKana(through scene: TripScene) -> Set<String> {
        Set(scenes.filter { $0.order <= scene.order }.flatMap(\.kana))
    }
}
