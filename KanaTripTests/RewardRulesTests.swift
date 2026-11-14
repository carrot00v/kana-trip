import Foundation
import Testing
@testable import KanaTrip

/// 장면 2개(히라가나) + 1개(가타카나)짜리 작은 목록으로 규칙을 본다.
private let testCatalog = RewardCatalog(
    items: [
        RewardItem(id: "chef_hat", slot: .hat, kana: nil, nameKo: "요리사 모자", sceneID: nil, isDefault: true, price: 0),
        RewardItem(id: "red_scarf", slot: .scarf, kana: nil, nameKo: "빨간 두건", sceneID: nil, isDefault: true, price: 0),
        RewardItem(id: "a_bg", slot: .background, kana: "あ", nameKo: "가", sceneID: "a", isDefault: false, price: 300),
        RewardItem(id: "a_hand", slot: .hand, kana: "い", nameKo: "나", sceneID: "a", isDefault: false, price: 300),
        RewardItem(id: "b_hat", slot: .hat, kana: "う", nameKo: "다", sceneID: "b", isDefault: false, price: 300),
        RewardItem(id: "b_scarf", slot: .scarf, kana: "え", nameKo: "라", sceneID: "b", isDefault: false, price: 300),
        RewardItem(id: "k_hand", slot: .hand, kana: "ア", nameKo: "마", sceneID: "k", isDefault: false, price: 300),
        RewardItem(id: "k_hat", slot: .hat, kana: "イ", nameKo: "바", sceneID: "k", isDefault: false, price: 300),
    ],
    hiraganaSceneIDs: ["a", "b"],
    katakanaSceneIDs: ["k"]
)

/// 세 세션을 차례로 끝낸 결과를 모은다.
private func completeScene(_ sceneID: String, done: inout Set<String>, state: inout RewardState,
                           catalog: RewardCatalog = testCatalog) -> [RewardGrant] {
    SessionKind.allCases.map { kind in
        if kind == .words { done.insert(sceneID) }
        return RewardRules.grantSession(kind, sceneID: sceneID, completedScenes: done, state: &state, catalog: catalog)
    }
}

@Suite("리워드 규칙")
struct RewardRulesTests {
    @Test func firstCompletionPays100AndReplayPaysNothing() {
        var state = RewardState()
        let first = RewardRules.grantSession(.learn, sceneID: "a", completedScenes: [], state: &state, catalog: testCatalog)
        #expect(first.coins == 100)
        #expect(first.balance == 100)
        #expect(first.unlockedItemIDs.isEmpty)
        #expect(state.paid == ["a/learn"])

        let replay = RewardRules.grantSession(.learn, sceneID: "a", completedScenes: [], state: &state, catalog: testCatalog)
        #expect(replay.coins == 0)
        #expect(replay.balance == 100)
        #expect(state.coins == 100)
        #expect(state.paid == ["a/learn"])
    }

    @Test func sceneCompletionUnlocksItsTwoItems() {
        var state = RewardState()
        var done: Set<String> = []
        let grants = completeScene("a", done: &done, state: &state)
        #expect(grants.map(\.coins) == [100, 100, 100])
        #expect(grants[2].unlockedItemIDs == ["a_bg", "a_hand"])
        #expect(state.coins == 300)

        let items = testCatalog.items(forScene: "a")
        #expect(items.allSatisfy { RewardRules.isUnlocked($0, state: state) })
        #expect(!RewardRules.isUnlocked(testCatalog.item(id: "b_hat")!, state: state))
        #expect(RewardRules.buyableItems(state: state, catalog: testCatalog).map(\.id) == ["a_bg", "a_hand"])

        // 단어 읽기를 다시 해도 다시 열리거나 엔을 받지 않는다.
        let replay = RewardRules.grantSession(.words, sceneID: "a", completedScenes: done, state: &state, catalog: testCatalog)
        #expect(replay == RewardGrant(balance: 300))
    }

    @Test func hiraganaMilestonePays600Once() {
        var state = RewardState()
        var done: Set<String> = []
        _ = completeScene("a", done: &done, state: &state)
        let b = completeScene("b", done: &done, state: &state)
        #expect(b[0].milestoneCoins == 0)
        #expect(b[2].coins == 700)
        #expect(b[2].milestoneCoins == 600)
        #expect(state.coins == 1_200)
        #expect(state.paid.contains(RewardRules.hiraganaMilestoneKey))
        // 전체 완료는 가타카나 장면이 남아 아직 아니다.
        #expect(b[2].grantedItemIDs.isEmpty)

        let replay = RewardRules.grantSession(.words, sceneID: "b", completedScenes: done, state: &state, catalog: testCatalog)
        #expect(replay.coins == 0)
        #expect(state.coins == 1_200)
    }

    @Test func allScenesGrantEveryUnboughtItemWithoutEquipping() {
        var state = RewardState()
        var done: Set<String> = []
        _ = completeScene("a", done: &done, state: &state)
        #expect(RewardRules.purchase(testCatalog.item(id: "a_hand")!, state: &state) == .bought)
        _ = completeScene("b", done: &done, state: &state)
        let k = completeScene("k", done: &done, state: &state)
        #expect(k[2].grantedItemIDs == ["a_bg", "b_hat", "b_scarf", "k_hand", "k_hat"])
        #expect(Set(state.owned) == ["a_hand", "a_bg", "b_hat", "b_scarf", "k_hand", "k_hat"])
        #expect(state.owned.count == 6)
        // 받은 아이템은 입히지 않는다. 산 손 아이템만 입고 있다.
        #expect(state.equipped == ["hat": "chef_hat", "scarf": "red_scarf", "hand": "a_hand"])
        #expect(state.paid.contains(RewardRules.allMilestoneKey))
    }

    @Test func noAllMilestoneWithoutKatakanaScenes() {
        let hiraganaOnly = RewardCatalog(items: testCatalog.items, hiraganaSceneIDs: ["a", "b"], katakanaSceneIDs: [])
        var state = RewardState()
        var done: Set<String> = []
        _ = completeScene("a", done: &done, state: &state, catalog: hiraganaOnly)
        let b = completeScene("b", done: &done, state: &state, catalog: hiraganaOnly)
        #expect(b[2].milestoneCoins == 600)
        #expect(b[2].grantedItemIDs.isEmpty)
        #expect(state.owned.isEmpty)
    }

    @Test func purchaseRules() throws {
        var state = RewardState()
        let bg = try #require(testCatalog.item(id: "a_bg"))
        let hand = try #require(testCatalog.item(id: "a_hand"))
        let chef = try #require(testCatalog.item(id: "chef_hat"))

        #expect(RewardRules.purchase(bg, state: &state) == .locked)
        #expect(RewardRules.purchase(chef, state: &state) == .alreadyOwned)

        var done: Set<String> = []
        _ = RewardRules.grantSession(.learn, sceneID: "a", completedScenes: done, state: &state, catalog: testCatalog)
        _ = RewardRules.grantSession(.quiz, sceneID: "a", completedScenes: done, state: &state, catalog: testCatalog)
        state.coins = 0
        done.insert("a")
        _ = RewardRules.grantSession(.words, sceneID: "a", completedScenes: done, state: &state, catalog: testCatalog)
        #expect(state.coins == 100)
        let before = state
        #expect(RewardRules.purchase(bg, state: &state) == .notEnoughCoins(short: 200))
        #expect(state == before)

        state.coins = 300
        #expect(RewardRules.purchase(bg, state: &state) == .bought)
        #expect(state.coins == 0)
        #expect(state.owned == ["a_bg"])
        #expect(state.equippedID(.background) == "a_bg")
        #expect(RewardRules.purchase(bg, state: &state) == .alreadyOwned)
        #expect(RewardRules.buyableItems(state: state, catalog: testCatalog).isEmpty)
        #expect(RewardRules.isForSale(hand, state: state))
    }

    @Test func equipClearAndReset() throws {
        var state = RewardState()
        let hand = try #require(testCatalog.item(id: "a_hand"))
        #expect(!RewardRules.equip(hand, state: &state))
        state.owned = ["a_hand"]
        #expect(RewardRules.equip(hand, state: &state))
        RewardRules.clear(.hat, state: &state)
        RewardRules.clear(.scarf, state: &state)
        #expect(state.equipped == ["hand": "a_hand"])
        RewardRules.resetOutfit(state: &state, catalog: testCatalog)
        #expect(state.equipped == ["hat": "chef_hat", "scarf": "red_scarf"])
        #expect(state.owned == ["a_hand"])
    }

    @Test func reconcilePaysCompletedButUnpaidSessions() {
        var state = RewardState()
        state.paid = ["a/learn"]
        state.coins = 100
        let grant = RewardRules.reconcile(
            completedSessions: ["a": [.learn, .quiz, .words], "b": [.learn]],
            state: &state,
            catalog: testCatalog
        )
        #expect(grant.coins == 300)
        #expect(state.coins == 400)
        #expect(grant.unlockedItemIDs == ["a_bg", "a_hand"])
        #expect(Set(state.paid) == ["a/learn", "a/quiz", "a/words", "b/learn"])

        let again = RewardRules.reconcile(completedSessions: ["a": [.learn, .quiz, .words], "b": [.learn]], state: &state, catalog: testCatalog)
        #expect(again.coins == 0)
    }

    @Test func sanitizeRevertsUnknownOrUnownedItems() {
        var state = RewardState()
        state.equipped = ["hat": "gone_item", "scarf": "b_scarf", "hand": "a_hand", "wings": "x"]
        state.owned = ["a_hand", "gone_item"]
        let clean = RewardRules.sanitized(state, catalog: testCatalog)
        #expect(clean.equipped == ["hat": "chef_hat", "scarf": "red_scarf", "hand": "a_hand"])
    }
}

@Suite("리워드 데이터")
struct RewardDataTests {
    private let catalog = RewardCatalog.bundled(hiraganaSceneIDs: ContentLibrary.shared.scenes.map(\.id))

    @Test func hiraganaItemsMatchDocument() {
        let sold = catalog.items.filter { !$0.isDefault }
        #expect(sold.count == 16)
        #expect(sold.allSatisfy { $0.price == 300 })
        #expect(Set(catalog.items.map(\.id)).count == catalog.items.count)
        #expect(catalog.defaultOutfit == ["hat": "chef_hat", "scarf": "red_scarf"])
        #expect(catalog.defaultOutfit == RewardState.defaultOutfit)

        var bySlot: [RewardSlot: Int] = [:]
        for item in sold { bySlot[item.slot, default: 0] += 1 }
        #expect(bySlot == [.background: 5, .hand: 5, .hat: 3, .scarf: 3])
    }

    @Test func everySceneHasTwoItemsInDifferentSlots() {
        for scene in ContentLibrary.shared.scenes {
            let items = catalog.items(forScene: scene.id)
            #expect(items.count == 2, "\(scene.name)의 아이템 \(items.count)개")
            #expect(Set(items.map(\.slot)).count == items.count, "\(scene.name)의 아이템이 같은 슬롯")
        }
    }

    @Test func unitsSpellTheName() {
        for item in catalog.items where !item.isDefault {
            #expect(item.units.map(\.kana).joined() == item.kana, "\(item.id)의 칸이 표기와 다름")
            #expect(item.units.allSatisfy { !$0.romaji.isEmpty }, "\(item.id)에 발음이 빈 칸")
        }
    }
}

/// 메모리에만 저장하는 저장소.
private final class MemoryStorage: ProgressStorage {
    var saved: ProgressState?
    var raw: Data?

    func load() -> ProgressState? {
        if let raw { return try? JSONDecoder().decode(ProgressState.self, from: raw) }
        return saved
    }

    func save(_ state: ProgressState) { saved = state }
}

@Suite("진도와 리워드 저장")
struct RewardStorageTests {
    @Test func completeSessionSavesGrantInSameState() {
        let storage = MemoryStorage()
        let store = ProgressStore(storage: storage, rewardCatalog: testCatalog)
        let grant = store.completeSession(.learn, sceneID: "a")
        #expect(grant.coins == 100)
        #expect(storage.saved?.rewards.coins == 100)
        #expect(storage.saved?.scenes["a"]?.completed == [.learn])

        _ = store.beginSession(.learn, sceneID: "a", kana: [])
        let replay = store.completeSession(.learn, sceneID: "a")
        #expect(replay.coins == 0)
        #expect(store.rewards.coins == 100)
    }

    @Test func buySavesCoinsOwnedAndEquippedTogether() throws {
        let storage = MemoryStorage()
        let store = ProgressStore(storage: storage, rewardCatalog: testCatalog)
        for kind in SessionKind.allCases { store.completeSession(kind, sceneID: "a") }
        #expect(store.canBuyAnyItem)
        let hand = try #require(testCatalog.item(id: "a_hand"))
        #expect(store.buy(hand) == .bought)
        let saved = try #require(storage.saved?.rewards)
        #expect(saved.coins == 0)
        #expect(saved.owned == ["a_hand"])
        #expect(saved.equippedID(.hand) == "a_hand")
        #expect(!store.canBuyAnyItem)
    }

    /// 리워드가 들어가기 전의 저장 파일: 진도는 그대로 읽고, 끝낸 세션의 엔을 맞추기로 준다.
    @Test func oldFileWithoutRewardsKeepsProgressAndIsReconciled() {
        let storage = MemoryStorage()
        storage.raw = Data("""
        {"version": \(ProgressState.currentVersion), "soundOn": true,
         "scenes": {"a": {"completed": ["learn", "quiz", "words"], "learnDone": [], "wordsDone": [], "wrongKana": []}}}
        """.utf8)
        let store = ProgressStore(storage: storage, rewardCatalog: testCatalog)
        #expect(store.soundOn)
        #expect(store.isSceneCompleted(sceneID: "a"))
        #expect(store.rewards.coins == 300)
        #expect(store.rewards.equipped == RewardState.defaultOutfit)
        #expect(storage.saved?.rewards.coins == 300)
    }

    /// 저장 형식 버전이 바뀌면 진도는 비우고 엔·아이템·착용·지급 기록은 남긴다.
    @Test func versionChangeKeepsRewards() {
        let storage = MemoryStorage()
        storage.raw = Data("""
        {"version": 1, "soundOn": false,
         "scenes": {"old_scene": {"completed": ["learn"], "learnDone": [], "wordsDone": [], "wrongKana": []}},
         "rewards": {"coins": 200, "paid": ["old_scene/learn", "a/words"], "owned": ["a_hand"], "equipped": {"hand": "a_hand"}}}
        """.utf8)
        let store = ProgressStore(storage: storage, rewardCatalog: testCatalog)
        #expect(store.state.scenes.isEmpty)
        #expect(store.rewards.coins == 200)
        #expect(store.rewards.owned == ["a_hand"])
        #expect(store.rewards.equipped == ["hand": "a_hand"])
        #expect(store.rewards.paid.contains("a/words"))
    }

    /// 진도 부분을 읽지 못해도 엔과 아이템은 남는다.
    @Test func unreadableProgressKeepsRewards() {
        let storage = MemoryStorage()
        storage.raw = Data("""
        {"version": \(ProgressState.currentVersion), "scenes": {"a": {"completed": "broken"}},
         "rewards": {"coins": 500, "paid": [], "owned": [], "equipped": {"hat": "chef_hat"}}}
        """.utf8)
        let store = ProgressStore(storage: storage, rewardCatalog: testCatalog)
        #expect(store.state.scenes.isEmpty)
        #expect(store.rewards.coins == 500)
        #expect(store.rewards.equipped == ["hat": "chef_hat"])
    }
}
