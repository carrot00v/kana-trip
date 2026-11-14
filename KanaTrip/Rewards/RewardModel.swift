import Foundation

// 리워드(기리 꾸미기)의 데이터 모델 (docs/content/reward-system.md 1.3, 7번).
// SwiftUI에 의존하지 않는다. 지급·사기 규칙은 RewardRules.swift에 있다.

/// 꾸미는 자리. 선언 순서가 꾸미기 화면의 슬롯 버튼 순서다.
enum RewardSlot: String, Codable, CaseIterable {
    case hat, scarf, hand, background
}

/// 아이템 하나. 번들의 `rewards.json`에서 읽는다.
struct RewardItem: Decodable, Identifiable, Equatable {
    /// 이름의 글자 하나와 그 발음. 단어 데이터의 `units`와 같은 꼴이다.
    struct Unit: Decodable, Equatable {
        let kana: String
        let romaji: String
    }

    let id: String
    let slot: RewardSlot
    /// 가나 이름. 기본 차림 아이템에는 없다 (reward-system.md 1.4).
    let kana: String?
    let nameKo: String
    /// 이 장면을 처음 끝내면 열린다. 기본 차림 아이템에는 없다.
    let sceneID: String?
    let isDefault: Bool
    let price: Int
    let units: [Unit]

    private enum CodingKeys: String, CodingKey {
        case id, slot, kana, nameKo, sceneID, isDefault, price, units
    }

    init(id: String, slot: RewardSlot, kana: String?, nameKo: String, sceneID: String?,
         isDefault: Bool, price: Int, units: [Unit] = []) {
        self.id = id
        self.slot = slot
        self.kana = kana
        self.nameKo = nameKo
        self.sceneID = sceneID
        self.isDefault = isDefault
        self.price = price
        self.units = units
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        slot = try c.decode(RewardSlot.self, forKey: .slot)
        kana = try c.decodeIfPresent(String.self, forKey: .kana)
        nameKo = try c.decode(String.self, forKey: .nameKo)
        sceneID = try c.decodeIfPresent(String.self, forKey: .sceneID)
        isDefault = try c.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        price = try c.decodeIfPresent(Int.self, forKey: .price) ?? 0
        units = try c.decodeIfPresent([Unit].self, forKey: .units) ?? []
    }
}

/// 저장하는 리워드 상태 (reward-system.md 7번). 진도(`scenes`)와 따로 읽어
/// 진도 저장 형식이 바뀌거나 진도를 읽지 못해도 남는다.
struct RewardState: Codable, Equatable {
    /// 엔 잔액.
    var coins = 0
    /// 엔을 이미 준 지점. "{장면 id}/{learn|quiz|words}", "milestone/hiragana", "milestone/all".
    /// "{장면 id}/words"가 있으면 그 장면의 아이템이 열린 것이다.
    var paid: [String] = []
    /// 산 아이템과 전체 완료로 받은 아이템 id. 받은 순서대로, 중복 없음. 기본 차림 아이템은 넣지 않는다.
    var owned: [String] = []
    /// 슬롯(RewardSlot.rawValue) → 입은 아이템 id. 키가 없으면 빈 슬롯.
    var equipped: [String: String] = RewardState.defaultOutfit

    static let defaultOutfit = ["hat": "chef_hat", "scarf": "red_scarf"]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case coins, paid, owned, equipped
    }

    /// 나중에 필드를 더해도 예전 파일을 읽을 수 있게 키마다 따로 읽는다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = (try? c.decodeIfPresent(Int.self, forKey: .coins)) ?? 0
        paid = (try? c.decodeIfPresent([String].self, forKey: .paid)) ?? []
        owned = (try? c.decodeIfPresent([String].self, forKey: .owned)) ?? []
        equipped = (try? c.decodeIfPresent([String: String].self, forKey: .equipped)) ?? RewardState.defaultOutfit
    }

    func equippedID(_ slot: RewardSlot) -> String? {
        equipped[slot.rawValue]
    }
}

/// 세션을 완료로 바꾸는 저장이 돌려주는 이번 지급 결과 (reward-flow.md 11.2). 저장하지 않는다.
struct RewardGrant: Hashable {
    /// 이번에 받은 엔. 마일스톤 엔을 포함한다. 다시 한 세션이면 0.
    var coins = 0
    /// 그중 마일스톤(히라가나 완료)으로 받은 엔.
    var milestoneCoins = 0
    /// 이번에 열린 아이템 (장면 완료 때).
    var unlockedItemIDs: [String] = []
    /// 16장면 완료로 받은 아이템.
    var grantedItemIDs: [String] = []
    /// 지급 뒤 잔액.
    var balance = 0
}

/// 아이템 목록과 마일스톤을 따지는 장면 목록.
struct RewardCatalog {
    /// 데이터 순서(장면 순서) 그대로.
    let items: [RewardItem]
    /// 히라가나 장면 id. 모두 끝내면 히라가나 마일스톤.
    let hiraganaSceneIDs: [String]
    /// 가타카나 장면 id. 비어 있으면(1차 버전) 전체 완료 마일스톤은 오지 않는다.
    let katakanaSceneIDs: [String]

    func item(id: String) -> RewardItem? {
        items.first { $0.id == id }
    }

    func items(in slot: RewardSlot) -> [RewardItem] {
        items.filter { $0.slot == slot }
    }

    func items(forScene sceneID: String) -> [RewardItem] {
        items.filter { $0.sceneID == sceneID }
    }

    /// 기본 차림: 슬롯 → 기본 아이템 id.
    var defaultOutfit: [String: String] {
        Dictionary(items.filter(\.isDefault).map { ($0.slot.rawValue, $0.id) }, uniquingKeysWith: { first, _ in first })
    }
}

extension RewardCatalog {
    private struct File: Decodable {
        let items: [RewardItem]
    }

    /// 번들의 `rewards.json`과 장면 데이터로 만든다.
    static func bundled(hiraganaSceneIDs: [String], bundle: Bundle = .main) -> RewardCatalog {
        guard let url = bundle.url(forResource: "rewards", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            assertionFailure("rewards.json을 읽지 못함")
            return RewardCatalog(items: [], hiraganaSceneIDs: hiraganaSceneIDs, katakanaSceneIDs: [])
        }
        return RewardCatalog(items: file.items, hiraganaSceneIDs: hiraganaSceneIDs, katakanaSceneIDs: [])
    }
}
