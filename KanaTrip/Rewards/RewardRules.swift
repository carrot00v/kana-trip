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

    /// 슬롯을 비운다. 머리는 빈 문자열로 남겨 "키 없음 = 기본 모자"와 구분한다.
    /// 밥은 비울 수 없어 흰 밥으로 돌린다 (reward-system.md 5.1).
    static func clear(_ slot: RewardSlot, state: inout RewardState) {
        switch slot {
        case .rice:
            state.equipped[slot.rawValue] = slot.defaultItemID
        case .top:
            state.equipped[slot.rawValue] = RewardState.emptyMark
        case .filling, .background:
            state.equipped[slot.rawValue] = nil
        }
    }

    /// "기본 차림으로"가 되돌리는 슬롯. 권장안(app-skin.md 5.5)대로면 스킨은 빠진다.
    static var outfitSlots: [RewardSlot] {
        RewardSlot.allCases.filter { !(SkinPolicy.resetOutfitKeepsSkin && $0 == SkinPolicy.slot) }
    }

    /// 차림 슬롯을 기본 차림(요리사 모자, 속재료 없음, 흰 밥)으로 되돌린다. 스킨은 `outfitSlots`에 없으면 그대로 둔다.
    static func resetOutfit(state: inout RewardState, catalog: RewardCatalog) {
        let kept = RewardSlot.allCases.filter { !outfitSlots.contains($0) }
        var equipped = catalog.defaultOutfit
        for slot in kept {
            equipped[slot.rawValue] = state.equipped[slot.rawValue]
        }
        state.equipped = equipped
    }

    /// 불러온 리워드 상태를 아이템 목록에 맞춘다 (reward-system.md 6.4). 환불·이전은 하지 않는다.
    /// - `owned`: 목록에 없는 id, 기본 아이템, 중복을 버린다.
    /// - `equipped`: 슬롯 id가 아닌 키(옛 `hat`, `scarf`, `hand` 등)는 버린다. 목록에 없거나 그 슬롯의 아이템이 아니거나
    ///   가지지 않은 아이템을 입은 슬롯은 기본으로 둔다. 머리를 비운 표시(빈 문자열)는 남긴다.
    ///   결과는 기본이 있는 슬롯(top, rice)에 키를 늘 두고, 빈 슬롯(filling, background)은 키를 지운 꼴이다.
    /// - `coins`, `paid`는 그대로 둔다.
    static func sanitized(_ state: RewardState, catalog: RewardCatalog) -> RewardState {
        var result = state
        var seen: Set<String> = []
        result.owned = state.owned.filter { id in
            guard let item = catalog.item(id: id), !item.isDefault else { return false }
            return seen.insert(id).inserted
        }
        var equipped: [String: String] = [:]
        for slot in RewardSlot.allCases {
            let key = slot.rawValue
            var value = slot.defaultItemID
            if let raw = state.equipped[key] {
                if raw == RewardState.emptyMark {
                    if slot.canBeEmpty { value = nil }
                } else if let item = catalog.item(id: raw), item.slot == slot, isOwned(item, state: result) {
                    value = raw
                }
            }
            if let value {
                equipped[key] = value
            } else if slot.defaultItemID != nil {
                // 기본이 있는 슬롯(머리)을 비웠다.
                equipped[key] = RewardState.emptyMark
            }
        }
        result.equipped = equipped
        result.version = RewardState.currentVersion
        return result
    }
}
