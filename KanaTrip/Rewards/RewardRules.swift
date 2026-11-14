import Foundation

// 엔 지급, 아이템 열림, 사기·입기 규칙 (docs/content/reward-system.md 2번, 5번, 6번).
// 저장과 화면에 의존하지 않는 순수 계산이다. ProgressStore가 부르고 결과를 한 번에 저장한다.

enum RewardRules {
    /// 세션을 처음 끝낼 때마다 받는 엔.
    static let sessionCoins = 100
    /// 히라가나 장면을 모두 끝냈을 때 더 받는 엔.
    static let hiraganaMilestoneCoins = 600

    static let hiraganaMilestoneKey = "milestone/hiragana"
    static let allMilestoneKey = "milestone/all"

    static func sessionKey(sceneID: String, kind: SessionKind) -> String {
        "\(sceneID)/\(kind.rawValue)"
    }

    // MARK: - 지급

    /// 세션 하나를 끝낸 순간의 지급. `paid`에 이미 있는 지점에는 주지 않는다(다시 하기는 0엔).
    /// - Parameter completedScenes: 이번 완료를 반영한 뒤, 세 세션을 모두 끝낸 장면 id.
    static func grantSession(
        _ kind: SessionKind,
        sceneID: String,
        completedScenes: Set<String>,
        state: inout RewardState,
        catalog: RewardCatalog
    ) -> RewardGrant {
        var grant = RewardGrant()
        let key = sessionKey(sceneID: sceneID, kind: kind)
        if !state.paid.contains(key) {
            state.paid.append(key)
            state.coins += sessionCoins
            grant.coins += sessionCoins
            if kind == .words {
                grant.unlockedItemIDs = catalog.items(forScene: sceneID).map(\.id)
            }
        }
        grantMilestones(completedScenes: completedScenes, state: &state, catalog: catalog, into: &grant)
        grant.balance = state.coins
        return grant
    }

    /// 앱을 켤 때 한 번: 완료 상태인데 `paid`에 없는 지점에 지급한다 (reward-system.md 6.2 마지막 줄).
    /// 이 기능 전에 끝낸 세션도 여기서 받는다. 화면에 알리지 않는다.
    static func reconcile(
        completedSessions: [String: Set<SessionKind>],
        state: inout RewardState,
        catalog: RewardCatalog
    ) -> RewardGrant {
        var grant = RewardGrant()
        for sceneID in completedSessions.keys.sorted() {
            for kind in SessionKind.allCases where completedSessions[sceneID]?.contains(kind) == true {
                let key = sessionKey(sceneID: sceneID, kind: kind)
                guard !state.paid.contains(key) else { continue }
                state.paid.append(key)
                state.coins += sessionCoins
                grant.coins += sessionCoins
                if kind == .words {
                    grant.unlockedItemIDs += catalog.items(forScene: sceneID).map(\.id)
                }
            }
        }
        let completedScenes = Set(completedSessions.filter { $0.value.count == SessionKind.allCases.count }.keys)
        grantMilestones(completedScenes: completedScenes, state: &state, catalog: catalog, into: &grant)
        grant.balance = state.coins
        return grant
    }

    private static func grantMilestones(
        completedScenes: Set<String>,
        state: inout RewardState,
        catalog: RewardCatalog,
        into grant: inout RewardGrant
    ) {
        let hiragana = catalog.hiraganaSceneIDs
        if !hiragana.isEmpty, hiragana.allSatisfy(completedScenes.contains), !state.paid.contains(hiraganaMilestoneKey) {
            state.paid.append(hiraganaMilestoneKey)
            state.coins += hiraganaMilestoneCoins
            grant.coins += hiraganaMilestoneCoins
            grant.milestoneCoins += hiraganaMilestoneCoins
        }
        // 가타카나 장면이 앱에 없으면 전체 완료는 오지 않는다.
        let all = hiragana + catalog.katakanaSceneIDs
        if !catalog.katakanaSceneIDs.isEmpty, all.allSatisfy(completedScenes.contains), !state.paid.contains(allMilestoneKey) {
            state.paid.append(allMilestoneKey)
            // 안 산 아이템을 모두 준다. 입히지는 않는다 (reward-system.md 5.1).
            let rest = catalog.items.filter { !$0.isDefault && !state.owned.contains($0.id) }.map(\.id)
            state.owned += rest
            grant.grantedItemIDs += rest
        }
    }

    // MARK: - 조회

    static func isUnlocked(_ item: RewardItem, state: RewardState) -> Bool {
        if item.isDefault { return true }
        guard let sceneID = item.sceneID else { return false }
        return state.paid.contains(sessionKey(sceneID: sceneID, kind: .words))
    }

    static func isOwned(_ item: RewardItem, state: RewardState) -> Bool {
        item.isDefault || state.owned.contains(item.id)
    }

    /// 열렸고 아직 안 가진 아이템인지. 엔이 모자란지는 따지지 않는다.
    static func isForSale(_ item: RewardItem, state: RewardState) -> Bool {
        isUnlocked(item, state: state) && !isOwned(item, state: state)
    }

    static func canAfford(_ item: RewardItem, state: RewardState) -> Bool {
        state.coins >= item.price
    }

    /// 지금 살 수 있는 아이템 (열림, 안 가짐, 잔액 ≥ 값). 저장하지 않고 계산한다 (reward-system.md 3.2).
    static func buyableItems(state: RewardState, catalog: RewardCatalog) -> [RewardItem] {
        catalog.items.filter { isForSale($0, state: state) && canAfford($0, state: state) }
    }

    // MARK: - 사기와 입기

    enum PurchaseResult: Equatable {
        case bought
        case locked
        case alreadyOwned
        case notEnoughCoins(short: Int)
    }

    /// 잔액 차감, `owned` 추가, 그 슬롯에 입히기를 함께 한다. 실패하면 상태를 바꾸지 않는다.
    static func purchase(_ item: RewardItem, state: inout RewardState) -> PurchaseResult {
        guard !isOwned(item, state: state) else { return .alreadyOwned }
        guard isUnlocked(item, state: state) else { return .locked }
        guard canAfford(item, state: state) else { return .notEnoughCoins(short: item.price - state.coins) }
        state.coins -= item.price
        state.owned.append(item.id)
        state.equipped[item.slot.rawValue] = item.id
        return .bought
    }

    /// 가진 아이템만 입는다. 입었으면 true.
    @discardableResult
    static func equip(_ item: RewardItem, state: inout RewardState) -> Bool {
        guard isOwned(item, state: state) else { return false }
        state.equipped[item.slot.rawValue] = item.id
        return true
    }

    static func clear(_ slot: RewardSlot, state: inout RewardState) {
        state.equipped[slot.rawValue] = nil
    }

    static func resetOutfit(state: inout RewardState, catalog: RewardCatalog) {
        state.equipped = catalog.defaultOutfit
    }

    /// 불러온 착용 상태를 아이템 목록에 맞춘다. 목록에 없거나 가지지 않은 아이템을 입은 슬롯은
    /// 기본 차림으로 되돌린다 (reward-system.md 6.3 마지막 줄). 모르는 슬롯 키는 지운다.
    static func sanitized(_ state: RewardState, catalog: RewardCatalog) -> RewardState {
        var result = state
        let defaults = catalog.defaultOutfit
        for (key, id) in state.equipped {
            guard let slot = RewardSlot(rawValue: key) else {
                result.equipped[key] = nil
                continue
            }
            if let item = catalog.item(id: id), item.slot == slot, isOwned(item, state: state) { continue }
            result.equipped[key] = defaults[key]
        }
        return result
    }
}
