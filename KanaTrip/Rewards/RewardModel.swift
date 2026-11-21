import Foundation

// 리워드(기리 꾸미기)의 데이터 모델 (docs/content/reward-system.md 1.2, 1.4, 6.4, 7번).
// SwiftUI에 의존하지 않는다. 지급·사기 규칙은 RewardRules.swift에 있다.

/// 꾸미기 종류 (docs/content/reward-system.md 1.2). 선언 순서가 꾸미기 화면의 탭 순서다
/// (기리를 작게 바꾸는 것에서 크게 바꾸는 것: 머리 → 속재료 → 밥 → 배경, reward-flow.md 3.0).
enum RewardSlot: String, Codable, CaseIterable {
    /// 머리 위에 쓰거나 얹는 것 (모자류, 토핑). 기본은 요리사 모자.
    case top
    /// 몸 왼쪽 옆구리로 삐져나온 속재료. 기본은 없음.
    case filling
    /// 몸(밥)의 색과 무늬. 기본은 흰 밥이고 비울 수 없다.
    case rice
    /// 앱 스킨. 아이템 id로 skins.json의 스킨을 찾는다. 키가 없으면 기본 스킨 (app-skin.md 8.1).
    /// 아이템 그림은 꾸미기 화면 미리보기의 기리 뒤에만 그린다. 저장 키 `background`는 그대로 둔다.
    case background

    /// 기본 차림의 아이템 (reward-system.md 1.4). 없으면 기본이 빈 슬롯이다.
    var defaultItemID: String? {
        switch self {
        case .top: "chef_hat"
        case .rice: "plain_rice"
        case .filling, .background: nil
        }
    }

    /// "없음" 칸이 있는지. 밥은 몸 자체라 비울 수 없다 (reward-system.md 5.1).
    var canBeEmpty: Bool { self != .rice }
}

/// 속재료를 본체 뒤와 앞 가운데 어디에 그리는지 (item-art/brief.md 2.3.1).
enum FillingLayer: String, Codable {
    /// 본체 뒤. 몸 밖으로 나온 부분만 보인다. 기본.
    case back
    /// 본체(빨간 두건) 다음, 머리·얼굴 전.
    case front
}

/// 아이템 하나. 번들의 `rewards.json`에서 읽는다.
struct RewardItem: Decodable, Identifiable, Equatable {
    /// 이름의 글자 칸 하나와 그 발음. 단어 데이터의 `units`와 같은 꼴이다.
    /// 요음(しゃ, じゅ)은 두 글자를 한 칸으로 묶는다 (PLAN.md 8번 임시 규칙).
    struct Unit: Decodable, Equatable {
        let kana: String
        let romaji: String
        /// 붙여 쓴 한자(えび天의 天).
        let kanji: Bool?

        init(kana: String, romaji: String, kanji: Bool? = nil) {
            self.kana = kana
            self.romaji = romaji
            self.kanji = kanji
        }

        var isKanji: Bool { kanji == true }

        /// 요음의 작은 글자.
        private static let smallYouon: Set<Character> = ["ゃ", "ゅ", "ょ", "ャ", "ュ", "ョ"]

        /// 배운 글자로 읽을 수 있는 칸인지. 읽을 수 없는 칸에는 발음을 표기한다 (reward-system.md 4.7).
        /// 탁음·반탁음·작은 글자는 배운 글자 목록에 없으므로 읽을 수 없는 칸이 된다. 한자도 읽을 수 없다.
        /// 요음(しゃ)은 한 칸으로 두고, 앞 글자(し)를 배웠으면 읽을 수 있는 칸으로 센다 (PLAN.md 8번 임시 규칙).
        func isReadable(learned: Set<String>) -> Bool {
            if isKanji { return false }
            if learned.contains(kana) { return true }
            let chars = Array(kana)
            if chars.count == 2, Self.smallYouon.contains(chars[1]) {
                return learned.contains(String(chars[0]))
            }
            return false
        }
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
    /// 속재료를 그리는 자리. 속재료가 아니면 nil.
    let layer: FillingLayer?

    /// 그림이 아직 없을 때 임시 표시에 넣는 글자: 가나 이름의 첫 칸(요음은 한 칸). 가나 이름이 없으면 한국어 이름 첫 글자.
    var placeholderLabel: String {
        units.first?.kana ?? kana.map { String($0.prefix(1)) } ?? String(nameKo.prefix(1))
    }

    private enum CodingKeys: String, CodingKey {
        case id, slot, kana, nameKo, sceneID, isDefault, price, units, layer
    }

    init(id: String, slot: RewardSlot, kana: String?, nameKo: String, sceneID: String?,
         isDefault: Bool, price: Int, units: [Unit] = [], layer: FillingLayer? = nil) {
        self.id = id
        self.slot = slot
        self.kana = kana
        self.nameKo = nameKo
        self.sceneID = sceneID
        self.isDefault = isDefault
        self.price = price
        self.units = units
        self.layer = slot == .filling ? (layer ?? .back) : nil
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
        let layer = try c.decodeIfPresent(FillingLayer.self, forKey: .layer)
        self.layer = slot == .filling ? (layer ?? .back) : nil
    }
}

/// 저장하는 리워드 상태 (reward-system.md 7번). 진도(`sessions`)와 따로 읽어
/// 진도 저장 형식이 바뀌거나 진도를 읽지 못해도 남는다.
struct RewardState: Codable, Equatable {
    /// 리워드 저장 형식 버전. 진도 버전(`ProgressState.version`)과 따로 둔다.
    /// 진도 버전을 올리면 장면 진도가 비워지므로, 꾸미기 개편은 이 버전만 올린다 (reward-system.md 6.4, 7번).
    /// 1: 모자·두건·손·배경 슬롯 (2026-11-13, 이 필드가 없던 때).
    /// 2: 머리·속재료·밥·배경 슬롯 (2026-11-16). 머리를 비운 상태는 빈 문자열로 저장한다.
    static let currentVersion = 2

    var version = RewardState.currentVersion
    /// 엔 잔액.
    var coins = 0
    /// 엔을 이미 준 지점. 세션 id("sushi-a", "sushi-quiz"), "scene/{장면 id}"(아이템 열림), "milestone/hiragana", "milestone/all".
    /// "scene/{장면 id}"가 있으면 그 장면의 아이템이 열린 것이다.
    var paid: [String] = []
    /// 산 아이템과 전체 완료로 받은 아이템 id. 받은 순서대로, 중복 없음. 기본 차림 아이템은 넣지 않는다.
    var owned: [String] = []
    /// 슬롯(RewardSlot.rawValue) → 입은 아이템 id.
    /// - 키가 없으면 그 슬롯의 기본(top = chef_hat, rice = plain_rice, 나머지는 비움).
    /// - 값이 빈 문자열(`emptyMark`)이면 비운 슬롯. 기본이 있는 머리를 비운 상태를 "키 없음 = 기본"과 구분하려고 쓴다.
    /// 불러올 때 `RewardRules.sanitized`가 기본이 있는 슬롯(top, rice)은 키를 늘 두고, 빈 슬롯(filling, background)은 키를 지운 꼴로 맞춘다.
    var equipped: [String: String] = RewardState.defaultOutfit

    static let defaultOutfit = ["top": "chef_hat", "rice": "plain_rice"]
    /// 비운 슬롯의 값.
    static let emptyMark = ""

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, coins, paid, owned, equipped
    }

    /// 나중에 필드를 더해도 예전 파일을 읽을 수 있게 키마다 따로 읽는다. 버전이 없으면 1(옛 슬롯)이다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        coins = (try? c.decodeIfPresent(Int.self, forKey: .coins)) ?? 0
        paid = (try? c.decodeIfPresent([String].self, forKey: .paid)) ?? []
        owned = (try? c.decodeIfPresent([String].self, forKey: .owned)) ?? []
        equipped = (try? c.decodeIfPresent([String: String].self, forKey: .equipped)) ?? RewardState.defaultOutfit
    }

    /// 그 슬롯에 입은 아이템 id. 비어 있으면 nil. 키가 없으면 그 슬롯의 기본 아이템.
    func equippedID(_ slot: RewardSlot) -> String? {
        guard let id = equipped[slot.rawValue] else { return slot.defaultItemID }
        return id == Self.emptyMark ? (slot.canBeEmpty ? nil : slot.defaultItemID) : id
    }

    /// 차림 슬롯이 모두 기본 차림인지. "기본 차림으로" 버튼을 끌 때 쓴다.
    /// 스킨은 기리의 차림이 아니라 보지 않는다 (app-skin.md 5.5, `SkinPolicy.resetOutfitKeepsSkin`).
    var isDefaultOutfit: Bool {
        RewardRules.outfitSlots.allSatisfy { equippedID($0) == $0.defaultItemID }
    }
}

/// 기리를 그릴 때 쓰는 차림. 슬롯마다 아이템 id 하나와, 속재료를 그리는 자리.
/// 화면(GiriView)은 저장 형식(`RewardState.equipped`)을 직접 읽지 않고 이 값만 받는다.
struct GiriOutfit: Equatable {
    var top: String? = RewardSlot.top.defaultItemID
    var filling: String?
    var fillingLayer: FillingLayer = .back
    var rice: String = RewardSlot.rice.defaultItemID ?? "plain_rice"
    var background: String?
    /// 아이템 id → 임시 표시 글자 (`RewardItem.placeholderLabel`). 그림 에셋이 없는 아이템에만 쓰인다.
    var labels: [String: String] = [:]

    /// 기본 차림 (요리사 모자 + 흰 밥).
    static let standard = GiriOutfit()

    init(top: String? = RewardSlot.top.defaultItemID, filling: String? = nil, fillingLayer: FillingLayer = .back,
         rice: String = RewardSlot.rice.defaultItemID ?? "plain_rice", background: String? = nil) {
        self.top = top
        self.filling = filling
        self.fillingLayer = fillingLayer
        self.rice = rice
        self.background = background
    }

    /// 저장된 착용 상태로 만든다. `trying`이 있으면 그 슬롯만 미리 보는 아이템으로 바꾼다(꾸미기 화면).
    init(state: RewardState, catalog: RewardCatalog, trying: RewardItem? = nil) {
        func id(_ slot: RewardSlot) -> String? {
            if let trying, trying.slot == slot { return trying.id }
            return state.equippedID(slot)
        }
        top = id(.top)
        filling = id(.filling)
        fillingLayer = filling.flatMap { catalog.item(id: $0)?.layer } ?? .back
        rice = id(.rice) ?? RewardSlot.rice.defaultItemID ?? "plain_rice"
        background = id(.background)
        for itemID in [top, filling, background].compactMap({ $0 }) {
            labels[itemID] = catalog.item(id: itemID)?.placeholderLabel
        }
    }

    /// 차림이 같은지는 아이템과 자리로만 본다. `labels`는 id에서 나오는 값이다.
    static func == (a: GiriOutfit, b: GiriOutfit) -> Bool {
        a.top == b.top && a.filling == b.filling && a.fillingLayer == b.fillingLayer
            && a.rice == b.rice && a.background == b.background
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
    /// 장면 id와 그 장면의 세션 id(순서대로). 장면 순서. 세션을 모두 끝내면 장면 완료다.
    let sceneSessions: [(sceneID: String, sessionIDs: [String])]

    init(items: [RewardItem], hiraganaSceneIDs: [String], katakanaSceneIDs: [String], sceneSessions: [(sceneID: String, sessionIDs: [String])]) {
        self.items = items
        self.hiraganaSceneIDs = hiraganaSceneIDs
        self.katakanaSceneIDs = katakanaSceneIDs
        self.sceneSessions = sceneSessions
    }

    /// 모든 세션을 끝낸 장면 id.
    func completedScenes(_ completedSessions: Set<String>) -> Set<String> {
        Set(sceneSessions.filter { !$0.sessionIDs.isEmpty && $0.sessionIDs.allSatisfy(completedSessions.contains) }.map(\.sceneID))
    }

    func item(id: String) -> RewardItem? {
        items.first { $0.id == id }
    }

    func items(in slot: RewardSlot) -> [RewardItem] {
        items.filter { $0.slot == slot }
    }

    func items(forScene sceneID: String) -> [RewardItem] {
        items.filter { $0.sceneID == sceneID }
    }

    /// 기본 차림: 슬롯 → 기본 아이템 id (top = chef_hat, rice = plain_rice).
    var defaultOutfit: [String: String] {
        Dictionary(items.filter(\.isDefault).map { ($0.slot.rawValue, $0.id) }, uniquingKeysWith: { first, _ in first })
    }
}

extension RewardCatalog {
    private struct File: Decodable {
        let items: [RewardItem]
    }

    /// 번들의 `rewards.json`과 장면 데이터(장면 id → 세션 id)로 만든다.
    static func bundled(hiraganaScenes: [(sceneID: String, sessionIDs: [String])], bundle: Bundle = .main) -> RewardCatalog {
        let ids = hiraganaScenes.map(\.sceneID)
        guard let url = bundle.url(forResource: "rewards", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            assertionFailure("rewards.json을 읽지 못함")
            return RewardCatalog(items: [], hiraganaSceneIDs: ids, katakanaSceneIDs: [], sceneSessions: hiraganaScenes)
        }
        return RewardCatalog(items: file.items, hiraganaSceneIDs: ids, katakanaSceneIDs: [], sceneSessions: hiraganaScenes)
    }
}
