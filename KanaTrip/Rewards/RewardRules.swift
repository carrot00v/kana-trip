import Foundation

// 엔 지급, 아이템 열림, 사기·입기 규칙 (docs/content/reward-system.md 2번, 5번, 6번).
// 저장과 화면에 의존하지 않는 순수 계산이다. ProgressStore가 부르고 결과를 한 번에 저장한다.

enum RewardRules {
    /// 세션(단계 a, 단계 b, 종합 퀴즈)을 처음 끝낼 때마다 받는 엔. 장면 하나에 300엔.
    static let sessionCoins = 100
    /// 히라가나 장면을 모두 끝냈을 때 더 받는 엔.
    static let hiraganaMilestoneCoins = 600

    static let hiraganaMilestoneKey = "milestone/hiragana"
    static let allMilestoneKey = "milestone/all"

    /// 세션의 지급 키는 세션 id 그대로다(`sushi-a`, `sushi-b`, `sushi-quiz`).
    static func sessionKey(_ sessionID: String) -> String { sessionID }

    /// 장면의 아이템이 열렸다는 표시. 장면의 마지막 세션(종합 퀴즈)을 처음 끝낼 때 넣는다. 엔은 붙지 않는다.
    static func sceneUnlockKey(_ sceneID: String) -> String { "scene/\(sceneID)" }

    // MARK: - 지급

    /// 끝낸 세션을 기준으로 아직 주지 않은 것을 모두 준다. `paid`에 이미 있는 지점에는 주지 않는다(다시 하기는 0엔).
    /// - 처음 끝낸 세션마다 `sessionCoins`엔 (키: 세션 id)
    /// - 장면의 모든 세션을 끝냈으면(종합 퀴즈 통과) 그 장면의 아이템이 열린다 (키: `scene/{장면 id}`)
    /// - 히라가나 장면을 모두 끝냈으면 마일스톤
    /// 세션을 끝낸 순간에도, 앱을 켤 때(이 기능 전에 끝낸 세션, reward-system.md 6.2 마지막 줄)에도 같은 함수를 쓴다.
    /// - Parameter completedSessions: 이번 완료를 반영한 뒤 끝낸 세션 id.
    static func settle(
        completedSessions: Set<String>,
        state: inout RewardState,
        catalog: RewardCatalog
    ) -> RewardGrant {
        var grant = RewardGrant()
        for (sceneID, sessions) in catalog.sceneSessions {
            for sessionID in sessions where completedSessions.contains(sessionID) {
                let key = sessionKey(sessionID)
                guard !state.paid.contains(key) else { continue }
                state.paid.append(key)
                state.coins += sessionCoins
                grant.coins += sessionCoins
            }
            let unlockKey = sceneUnlockKey(sceneID)
            if !sessions.isEmpty, sessions.allSatisfy(completedSessions.contains), !state.paid.contains(unlockKey) {
                state.paid.append(unlockKey)
                grant.unlockedItemIDs += catalog.items(forScene: sceneID).map(\.id)
            }
        }
        grantMilestones(completedScenes: catalog.completedScenes(completedSessions), state: &state, catalog: catalog, into: &grant)
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
        return state.paid.contains(sceneUnlockKey(sceneID))
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
