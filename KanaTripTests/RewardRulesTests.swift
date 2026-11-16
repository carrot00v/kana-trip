import Foundation
import Testing
@testable import KanaTrip

/// 장면 2개(히라가나) + 1개(가타카나)짜리 작은 목록으로 규칙을 본다. 장면마다 세션 3개(a, b, quiz).
private let testCatalog = RewardCatalog(
    items: [
        RewardItem(id: "chef_hat", slot: .top, kana: nil, nameKo: "요리사 모자", sceneID: nil, isDefault: true, price: 0),
        RewardItem(id: "plain_rice", slot: .rice, kana: nil, nameKo: "흰 밥", sceneID: nil, isDefault: true, price: 0),
        RewardItem(id: "a_bg", slot: .background, kana: "あ", nameKo: "가", sceneID: "a", isDefault: false, price: 300),
        RewardItem(id: "a_fill", slot: .filling, kana: "い", nameKo: "나", sceneID: "a", isDefault: false, price: 300),
        RewardItem(id: "b_top", slot: .top, kana: "う", nameKo: "다", sceneID: "b", isDefault: false, price: 300),
        RewardItem(id: "b_rice", slot: .rice, kana: "え", nameKo: "라", sceneID: "b", isDefault: false, price: 300),
        RewardItem(id: "k_fill", slot: .filling, kana: "ア", nameKo: "마", sceneID: "k", isDefault: false, price: 300,
                   layer: .front),
        RewardItem(id: "k_top", slot: .top, kana: "イ", nameKo: "바", sceneID: "k", isDefault: false, price: 300),
    ],
    hiraganaSceneIDs: ["a", "b"],
    katakanaSceneIDs: ["k"],
    sceneSessions: ["a", "b", "k"].map { ($0, ["\($0)-a", "\($0)-b", "\($0)-quiz"]) }
)

/// 세 세션을 차례로 끝낸 결과를 모은다.
private func completeScene(_ sceneID: String, done: inout Set<String>, state: inout RewardState,
                           catalog: RewardCatalog = testCatalog) -> [RewardGrant] {
    ["a", "b", "quiz"].map { suffix in
        done.insert("\(sceneID)-\(suffix)")
        return RewardRules.settle(completedSessions: done, state: &state, catalog: catalog)
    }
}

@Suite("리워드 규칙")
struct RewardRulesTests {
    @Test func firstCompletionPays100AndReplayPaysNothing() {
        var state = RewardState()
        let first = RewardRules.settle(completedSessions: ["a-a"], state: &state, catalog: testCatalog)
        #expect(first.coins == 100)
        #expect(first.balance == 100)
        #expect(first.unlockedItemIDs.isEmpty)
        #expect(state.paid == ["a-a"])

        let replay = RewardRules.settle(completedSessions: ["a-a"], state: &state, catalog: testCatalog)
        #expect(replay.coins == 0)
        #expect(replay.balance == 100)
        #expect(state.coins == 100)
        #expect(state.paid == ["a-a"])
    }

    @Test func quizCompletionUnlocksSceneItems() {
        var state = RewardState()
        var done: Set<String> = []
        let grants = completeScene("a", done: &done, state: &state)
        #expect(grants.map(\.coins) == [100, 100, 100])
        #expect(grants[0].unlockedItemIDs.isEmpty)
        #expect(grants[1].unlockedItemIDs.isEmpty)
        #expect(grants[2].unlockedItemIDs == ["a_bg", "a_fill"])
        #expect(state.coins == 300)
        #expect(state.paid.contains(RewardRules.sceneUnlockKey("a")))

        let items = testCatalog.items(forScene: "a")
        #expect(items.allSatisfy { RewardRules.isUnlocked($0, state: state) })
        #expect(!RewardRules.isUnlocked(testCatalog.item(id: "b_top")!, state: state))
        #expect(RewardRules.buyableItems(state: state, catalog: testCatalog).map(\.id) == ["a_bg", "a_fill"])

        // 퀴즈를 다시 해도 다시 열리거나 엔을 받지 않는다.
        let replay = RewardRules.settle(completedSessions: done, state: &state, catalog: testCatalog)
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

        let replay = RewardRules.settle(completedSessions: done, state: &state, catalog: testCatalog)
        #expect(replay.coins == 0)
        #expect(state.coins == 1_200)
    }

    @Test func allScenesGrantEveryUnboughtItemWithoutEquipping() {
        var state = RewardState()
        var done: Set<String> = []
        _ = completeScene("a", done: &done, state: &state)
        #expect(RewardRules.purchase(testCatalog.item(id: "a_fill")!, state: &state) == .bought)
        _ = completeScene("b", done: &done, state: &state)
        let k = completeScene("k", done: &done, state: &state)
        #expect(k[2].grantedItemIDs == ["a_bg", "b_top", "b_rice", "k_fill", "k_top"])
        #expect(Set(state.owned) == ["a_fill", "a_bg", "b_top", "b_rice", "k_fill", "k_top"])
        #expect(state.owned.count == 6)
        #expect(state.equipped == ["top": "chef_hat", "rice": "plain_rice", "filling": "a_fill"])
        #expect(state.paid.contains(RewardRules.allMilestoneKey))
    }

    @Test func noAllMilestoneWithoutKatakanaScenes() {
        let hiraganaOnly = RewardCatalog(items: testCatalog.items, hiraganaSceneIDs: ["a", "b"], katakanaSceneIDs: [],
                                         sceneSessions: Array(testCatalog.sceneSessions.prefix(2)))
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
        let filling = try #require(testCatalog.item(id: "a_fill"))
        let chef = try #require(testCatalog.item(id: "chef_hat"))

        #expect(RewardRules.purchase(bg, state: &state) == .locked)
        #expect(RewardRules.purchase(chef, state: &state) == .alreadyOwned)

        _ = RewardRules.settle(completedSessions: ["a-a", "a-b"], state: &state, catalog: testCatalog)
        state.coins = 0
        _ = RewardRules.settle(completedSessions: ["a-a", "a-b", "a-quiz"], state: &state, catalog: testCatalog)
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
        #expect(RewardRules.isForSale(filling, state: state))
    }

    @Test func equipClearAndReset() throws {
        var state = RewardState()
        let filling = try #require(testCatalog.item(id: "a_fill"))
        #expect(!RewardRules.equip(filling, state: &state))
        state.owned = ["a_fill"]
        #expect(RewardRules.equip(filling, state: &state))
        #expect(state.equippedID(.filling) == "a_fill")
        RewardRules.clear(.top, state: &state)
        RewardRules.clear(.filling, state: &state)
        // 머리를 비운 상태는 빈 문자열로 남아 "키 없음 = 기본 모자"와 구분된다.
        #expect(state.equipped == ["top": "", "rice": "plain_rice"])
        #expect(state.equippedID(.top) == nil)
        #expect(state.equippedID(.filling) == nil)
        #expect(!state.isDefaultOutfit)
        // 밥은 비울 수 없어 흰 밥으로 돌아간다.
        RewardRules.clear(.rice, state: &state)
        #expect(state.equippedID(.rice) == "plain_rice")
        RewardRules.resetOutfit(state: &state, catalog: testCatalog)
        #expect(state.equipped == ["top": "chef_hat", "rice": "plain_rice"])
        #expect(state.isDefaultOutfit)
        #expect(state.owned == ["a_fill"])
    }

    /// 기본 차림: 머리 = 요리사 모자, 밥 = 흰 밥, 속재료·배경 = 없음 (reward-system.md 1.4).
    @Test func defaultOutfitIsChefHatAndPlainRice() {
        let state = RewardState()
        #expect(state.equipped == ["top": "chef_hat", "rice": "plain_rice"])
        #expect(state.equippedID(.top) == "chef_hat")
        #expect(state.equippedID(.rice) == "plain_rice")
        #expect(state.equippedID(.filling) == nil)
        #expect(state.equippedID(.background) == nil)
        #expect(state.isDefaultOutfit)
        #expect(testCatalog.defaultOutfit == RewardState.defaultOutfit)
        #expect(GiriOutfit(state: state, catalog: testCatalog) == .standard)
        // 키가 없으면 그 슬롯의 기본으로 읽는다. 밥은 키가 없어도 흰 밥이다.
        var empty = RewardState()
        empty.equipped = [:]
        #expect(empty.equippedID(.top) == "chef_hat")
        #expect(empty.equippedID(.rice) == "plain_rice")
        #expect(empty.isDefaultOutfit)
    }

    /// 밥을 바꾸면 본체가 바뀌고, 속재료는 데이터의 layer 값대로 그린다.
    @Test func outfitCarriesRiceAndFillingLayer() throws {
        var state = RewardState()
        state.owned = ["b_rice", "k_fill"]
        #expect(RewardRules.equip(try #require(testCatalog.item(id: "b_rice")), state: &state))
        #expect(RewardRules.equip(try #require(testCatalog.item(id: "k_fill")), state: &state))
        let outfit = GiriOutfit(state: state, catalog: testCatalog)
        #expect(outfit.rice == "b_rice")
        #expect(outfit.filling == "k_fill")
        #expect(outfit.fillingLayer == .front)
        #expect(outfit.top == "chef_hat")
        #expect(outfit.labels["k_fill"] == "ア")
        // 미리 보기는 그 슬롯만 바꾼다.
        let trying = try #require(testCatalog.item(id: "a_fill"))
        let preview = GiriOutfit(state: state, catalog: testCatalog, trying: trying)
        #expect(preview.filling == "a_fill" && preview.fillingLayer == .back && preview.rice == "b_rice")
    }

    @Test func settlePaysCompletedButUnpaidSessions() {
        var state = RewardState()
        state.paid = ["a-a"]
        state.coins = 100
        let done: Set<String> = ["a-a", "a-b", "a-quiz", "b-a"]
        let grant = RewardRules.settle(completedSessions: done, state: &state, catalog: testCatalog)
        #expect(grant.coins == 300)
        #expect(state.coins == 400)
        #expect(grant.unlockedItemIDs == ["a_bg", "a_fill"])
        #expect(Set(state.paid) == ["a-a", "a-b", "a-quiz", "scene/a", "b-a"])

        let again = RewardRules.settle(completedSessions: done, state: &state, catalog: testCatalog)
        #expect(again.coins == 0)
    }

    @Test func sanitizeRevertsUnknownOrUnownedItems() {
        var state = RewardState()
        state.equipped = ["top": "gone_item", "rice": "b_rice", "filling": "a_fill", "wings": "x"]
        state.owned = ["a_fill", "gone_item"]
        let clean = RewardRules.sanitized(state, catalog: testCatalog)
        #expect(clean.equipped == ["top": "chef_hat", "rice": "plain_rice", "filling": "a_fill"])
        #expect(clean.owned == ["a_fill"])
    }

    /// 꾸미기 개편(2026-11-16) 전의 저장: 옛 슬롯 키(hat, scarf, hand)와 목록에 없는 id는 버리고,
    /// 엔과 지급 기록은 그대로, 환불은 없다 (reward-system.md 6.4).
    @Test func sanitizeDropsOldSlotKeysAndUnknownIDs() {
        var state = RewardState()
        state.version = 1
        state.coins = 200
        state.paid = ["a-a", "a-b", "a-quiz", "scene/a"]
        state.owned = ["sushi", "a_bg", "kitsune", "a_bg", "chef_hat"]
        state.equipped = ["hat": "ohitsu", "scarf": "red_scarf", "hand": "sushi", "background": "a_bg"]
        let clean = RewardRules.sanitized(state, catalog: testCatalog)
        #expect(clean.version == RewardState.currentVersion)
        #expect(clean.coins == 200)
        #expect(clean.paid == state.paid)
        #expect(clean.owned == ["a_bg"])
        #expect(clean.equipped == ["top": "chef_hat", "rice": "plain_rice", "background": "a_bg"])
    }

    /// 머리를 비운 상태는 다시 읽어도 비운 채로 남는다. 밥의 빈 값은 흰 밥, 다른 슬롯의 아이템은 그 슬롯을 기본으로 돌린다.
    @Test func sanitizeKeepsEmptyTop() {
        var state = RewardState()
        state.owned = ["b_top"]
        state.equipped = ["top": "", "rice": "", "background": "b_top"]
        let clean = RewardRules.sanitized(state, catalog: testCatalog)
        #expect(clean.equipped == ["top": "", "rice": "plain_rice"])
        #expect(clean.equippedID(.top) == nil)
        #expect(clean.equippedID(.background) == nil)
    }
}

/// 아이템 이름의 글자 칸 읽기 (reward-system.md 4.7, PLAN.md 8번 요음 임시 규칙).
@Suite("아이템 이름 칸")
struct RewardItemUnitTests {
    @Test func youonUnitIsReadableWhenFirstKanaIsLearned() {
        let sha = RewardItem.Unit(kana: "しゃ", romaji: "sha")
        #expect(sha.isReadable(learned: ["し"]))
        #expect(!sha.isReadable(learned: ["け"]))
        // じゅ: 앞 글자 じ가 탁음이라 배운 글자 목록에 없다.
        let ju = RewardItem.Unit(kana: "じゅ", romaji: "ju")
        #expect(!ju.isReadable(learned: ["し", "ゆ"]))
    }

    @Test func dakutenSmallKanaAndKanjiAreNotReadable() {
        #expect(!RewardItem.Unit(kana: "ご", romaji: "go").isReadable(learned: ["こ"]))
        #expect(!RewardItem.Unit(kana: "ゃ", romaji: "ya").isReadable(learned: ["や"]))
        #expect(!RewardItem.Unit(kana: "天", romaji: "ten", kanji: true).isReadable(learned: ["天"]))
        #expect(RewardItem.Unit(kana: "け", romaji: "ke").isReadable(learned: ["け"]))
    }

    /// 번들 데이터의 しゃけ: 스시집(し)과 소바·우동집(け) 글자를 배우면 발음 표기 없이 읽힌다.
    @Test func bundledShakeIsReadableAfterLearningShiAndKe() throws {
        let catalog = RewardCatalog.bundled(hiraganaScenes: [])
        let shake = try #require(catalog.item(id: "shake"))
        #expect(shake.units.map(\.kana) == ["しゃ", "け"])
        #expect(shake.units.allSatisfy { $0.isReadable(learned: ["し", "け"]) })
        #expect(!shake.units[0].isReadable(learned: ["け"]))
        let manjuu = try #require(catalog.item(id: "manjuu"))
        #expect(manjuu.units.map(\.kana) == ["ま", "ん", "じゅ", "う"])
        #expect(manjuu.units.map { $0.isReadable(learned: ["ま", "ん", "し", "ゆ", "う"]) } == [true, true, false, true])
        let ebiten = try #require(catalog.item(id: "ebiten"))
        #expect(ebiten.units.last?.isKanji == true)
    }
}

@Suite("리워드 데이터")
struct RewardDataTests {
    private let catalog = RewardCatalog.bundled(hiraganaScenes: ContentLibrary.shared.scenes.map { scene in
        (scene.id, ContentLibrary.shared.sessions(in: scene).map(\.id))
    })

    @Test func hiraganaItemsMatchDocument() {
        let sold = catalog.items.filter { !$0.isDefault }
        #expect(catalog.items.count == 18)
        #expect(sold.count == 16)
        #expect(sold.allSatisfy { $0.price == 300 })
        #expect(Set(catalog.items.map(\.id)).count == catalog.items.count)
        #expect(catalog.defaultOutfit == ["top": "chef_hat", "rice": "plain_rice"])
        #expect(catalog.defaultOutfit == RewardState.defaultOutfit)
        #expect(catalog.item(id: "red_scarf") == nil)

        var bySlot: [RewardSlot: Int] = [:]
        for item in sold { bySlot[item.slot, default: 0] += 1 }
        #expect(bySlot == [.background: 4, .top: 7, .filling: 3, .rice: 2])
        // 속재료만 layer가 있고, 지금 목록은 모두 뒤 레이어다 (item-art/brief.md 2.3.6).
        #expect(catalog.items.allSatisfy { ($0.slot == .filling) == ($0.layer != nil) })
        #expect(catalog.items(in: .filling).allSatisfy { $0.layer == .back })
        // 탭 칸 순서 (reward-flow.md 3.5): 기본 아이템이 앞, 나머지는 장면 순서.
        #expect(catalog.items(in: .top).map(\.id) == ["chef_hat", "tamago", "tonkatsu_slice", "chikuwa", "omen",
                                                       "hachimaki", "tenugui", "manjuu"])
        #expect(catalog.items(in: .rice).map(\.id) == ["plain_rice", "goma", "yakionigiri"])
    }

    /// 장면마다 아이템 2개, 장면 안에서 슬롯이 겹치지 않는다. 모든 아이템은 앱의 장면에 묶인다 (reward-system.md "개편안 B 반영").
    @Test func everySceneHasTwoItemsInDifferentSlots() {
        let scenes = ContentLibrary.shared.scenes
        #expect(Set(catalog.items.compactMap(\.sceneID)) == Set(scenes.map(\.id)))
        for scene in scenes {
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
    private var library: ContentLibrary { .shared }

    /// 장면 1(sushi)을 세션 3개로 끝내며 엔과 아이템을 확인한다. 다시 하면 엔이 0이다.
    @Test func sessionCompletionPaysByIDAndReplayPaysNothing() throws {
        let storage = MemoryStorage()
        let store = ProgressStore(storage: storage)
        let start = store.rewards.coins
        let sushi = try #require(library.scene(id: "sushi"))
        let sessions = library.sessions(in: sushi)
        #expect(sessions.map(\.id) == ["sushi-a", "sushi-b", "sushi-quiz"])

        let a = SessionRun(session: sessions[0], store: store).complete()
        #expect(a.coins == 100)
        #expect(storage.saved?.sessions["sushi-a"]?.completed == true)
        #expect(storage.saved?.rewards.paid.contains("sushi-a") == true)
        #expect(store.isUnlocked(sessions[1]))
        #expect(!store.isUnlocked(sessions[2]))

        let replay = SessionRun(session: sessions[0], store: store)
        #expect(replay.isReplay)
        #expect(replay.complete().coins == 0)

        _ = SessionRun(session: sessions[1], store: store).complete()
        let quiz = SessionRun(session: sessions[2], store: store).complete()
        #expect(quiz.coins == 100)
        #expect(Set(quiz.unlockedItemIDs) == Set(store.rewardCatalog.items(forScene: "sushi").map(\.id)))
        #expect(store.isSceneCompleted(sushi))
        #expect(store.rewards.coins == start + 300)
        let tonkatsu = try #require(library.scene(id: "tonkatsu"))
        #expect(store.isSceneUnlocked(tonkatsu))
    }

    /// 버전 3 파일: 진도는 비우고 엔·지급 기록과 소리 설정은 남긴다. 옛 슬롯의 아이템은 버린다.
    @Test func versionChangeKeepsRewards() {
        let storage = MemoryStorage()
        storage.raw = Data("""
        {"version": 3, "soundOn": true,
         "scenes": {"old_scene": {"completed": ["learn"], "learnDone": [], "wordsDone": [], "wrongKana": []}},
         "rewards": {"coins": 200, "paid": ["old_scene/learn"], "owned": ["sushi"], "equipped": {"hand": "sushi"}}}
        """.utf8)
        let store = ProgressStore(storage: storage)
        #expect(store.state.version == ProgressState.currentVersion)
        #expect(store.state.sessions.isEmpty)
        #expect(store.soundOn)
        #expect(store.rewards.coins == 200)
        #expect(store.rewards.paid == ["old_scene/learn"])
        #expect(store.rewards.owned.isEmpty)
        #expect(store.rewards.equipped == RewardState.defaultOutfit)
    }

    /// 꾸미기 개편(2026-11-16) 전의 저장(리워드 버전 없음 = 1): 옛 키(hat, scarf, hand)와 목록에 없는 id는 버리고
    /// coins·paid는 유지, 환불 없음. 장면 진도는 비우지 않는다. 남은 목록의 아이템(noren)은 그대로 쓴다 (reward-system.md 6.4).
    @Test func oldSlotSaveIsCleanedOnLoad() throws {
        let storage = MemoryStorage()
        let done = #"{"completed": true, "learnDone": [], "wordsDone": [], "quizWrong": []}"#
        storage.raw = Data("""
        {"version": \(ProgressState.currentVersion), "sessions": {
            "sushi-a": \(done), "sushi-b": \(done), "sushi-quiz": \(done),
            "tonkatsu-a": \(done), "tonkatsu-b": \(done), "tonkatsu-quiz": \(done)},
         "rewards": {"coins": 300, "paid": ["sushi-a", "sushi-b", "sushi-quiz", "scene/sushi",
                                            "tonkatsu-a", "tonkatsu-b", "tonkatsu-quiz", "scene/tonkatsu"],
                     "owned": ["sushi", "oshinko", "noren"],
                     "equipped": {"hat": "chef_hat", "scarf": "red_scarf", "hand": "sushi", "background": "noren"}}}
        """.utf8)
        let store = ProgressStore(storage: storage)
        let catalog = store.rewardCatalog
        #expect(store.state.sessions.count == 6)
        #expect(store.rewards.coins == 300)
        #expect(store.rewards.paid.count == 8)
        #expect(store.rewards.owned == ["noren"])
        #expect(store.rewards.version == RewardState.currentVersion)
        #expect(store.rewards.equipped == ["top": "chef_hat", "rice": "plain_rice", "background": "noren"])
        #expect(store.giriOutfit == GiriOutfit(background: "noren"))
        // 고친 상태를 바로 저장해 옛 키가 남지 않는다.
        #expect(storage.saved?.rewards.equipped["hand"] == nil)
        #expect(storage.saved?.rewards.version == RewardState.currentVersion)
        // 열린 장면의 새 아이템은 살 수 있다.
        #expect(Set(RewardRules.buyableItems(state: store.rewards, catalog: catalog).map(\.id))
                == ["tamago", "tonkatsu_slice", "goma"])
    }

    /// 머리를 비우고 저장한 뒤 다시 읽어도 비운 채다(키 없음 = 기본 모자와 구분).
    @Test func emptyTopSurvivesReload() throws {
        let storage = MemoryStorage()
        let store = ProgressStore(storage: storage)
        store.clearSlot(.top)
        #expect(store.rewards.equippedID(.top) == nil)
        let reloaded = ProgressStore(storage: storage)
        #expect(reloaded.rewards.equippedID(.top) == nil)
        #expect(reloaded.giriOutfit.top == nil)
        #expect(reloaded.rewards.equippedID(.rice) == "plain_rice")
        reloaded.resetOutfit()
        #expect(reloaded.rewards.isDefaultOutfit)
    }

    /// 진도 부분을 읽지 못해도 엔과 아이템은 남는다.
    @Test func unreadableProgressKeepsRewards() {
        let storage = MemoryStorage()
        storage.raw = Data("""
        {"version": \(ProgressState.currentVersion), "sessions": {"sushi-a": {"completed": "broken"}},
         "rewards": {"version": 2, "coins": 500, "paid": [], "owned": [], "equipped": {"top": "chef_hat"}}}
        """.utf8)
        let store = ProgressStore(storage: storage)
        #expect(store.state.sessions.isEmpty)
        #expect(store.rewards.coins == 500)
        #expect(store.rewards.equipped == RewardState.defaultOutfit)
    }
}
