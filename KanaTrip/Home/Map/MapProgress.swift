import Foundation

// 지도의 칸 상태, 지금 칸, 돌아왔을 때의 깡충 계획 (docs/design/home-map.md 2.1, 2.2, 2.5, 4.1~4.4).
// SwiftUI와 ProgressStore에 의존하지 않는다. 입력은 끝낸 세션 id 집합뿐이라 테스트에서 바로 만든다.

/// 세션 칸의 상태 (2.1). 하던 중은 모양을 바꾸지 않으므로 따로 두지 않는다.
enum MapNodeState: Equatable {
    case locked, current, completed
}

/// 건물 칸의 상태 (2.2).
enum MapBuildingState: Equatable {
    case locked, open, completed
}

/// 기리가 밟는 자리: 세션 칸·지역 끝 표지, 또는 장면을 넘을 때 거치는 건물 앞 (7.1 "기리가 밟는 순서").
enum MapWaypoint: Equatable, Hashable {
    case node(String)
    case front(String)
}

/// 깡충 한 번.
struct MapHop: Equatable {
    enum Kind: Equatable {
        /// 같은 장면 안의 칸 이동, 지역 끝 표지로. 0.35초.
        case step
        /// 장면을 넘는 두 번 가운데 하나. 0.3초 (4.4).
        case scene
    }

    let to: MapWaypoint
    let kind: Kind
}

/// 보여 준 칸과 지금 칸을 비교한 결과 (4.1).
enum MapTransition: Equatable {
    /// 같음. 연출 없음.
    case none
    /// 너무 멀거나 뒤로 갔거나 보여 준 칸이 없음. 연출 없이 결과 상태.
    case jump
    /// 1~maxChainSessions칸 앞. 깡충들.
    case hops([MapHop])
}

/// 화면에 그리는 진행 정도. 평소에는 세 값이 모두 지금 칸의 순서와 같고, 연출 동안 따로 움직인다 (4.2~4.4).
/// 값은 세션 칸의 순서(0부터, 지역 끝 표지 = 세션 수).
struct MapDisplay: Equatable {
    /// 이보다 앞 칸은 완료로 그린다. 진행 선도 이 칸까지 실선.
    var markIndex: Int
    /// 지금 모양(채운 원)으로 그릴 칸.
    var currentIndex: Int
    /// a 칸의 순서가 이 값 이하인 장면의 건물은 열림으로 그린다.
    var buildingOpenIndex: Int

    init(index: Int) {
        markIndex = index
        currentIndex = index
        buildingOpenIndex = index
    }
}

/// 지도 한 지역의 길 순서. map.json에서 만든다.
struct MapRoute {
    let region: MapRegion
    /// 세션 칸을 구간 순서 → 구간 안 배열 순서로 이은 것.
    let sessionNodes: [MapNode]
    /// 모든 칸(출발, 건물, 세션, 끝)의 길 순서.
    private let routeOrder: [String: Int]
    private let sessionOrdinal: [String: Int]
    /// 세션 칸 id → 그 장면의 건물 id.
    private let buildingOfSession: [String: String]
    /// 건물 id → 그 장면 a 칸의 순서.
    private let firstOrdinalOfBuilding: [String: Int]
    private let lastOrdinalOfBuilding: [String: Int]
    /// 지역 끝 표지 id.
    let gateID: String?

    init(region: MapRegion) {
        self.region = region
        var sessions: [MapNode] = []
        var order: [String: Int] = [:]
        var ordinal: [String: Int] = [:]
        var building: [String: String] = [:]
        var first: [String: Int] = [:]
        var last: [String: Int] = [:]
        var gate: String?
        for section in region.sections {
            let buildingID = section.nodes.first { $0.kind == .building }?.id
            for node in section.nodes {
                order[node.id] = order.count
                if node.isSession {
                    ordinal[node.id] = sessions.count
                    if let buildingID {
                        building[node.id] = buildingID
                        if first[buildingID] == nil { first[buildingID] = sessions.count }
                        last[buildingID] = sessions.count
                    }
                    sessions.append(node)
                }
                if node.kind == .gate { gate = node.id }
            }
        }
        sessionNodes = sessions
        routeOrder = order
        sessionOrdinal = ordinal
        buildingOfSession = building
        firstOrdinalOfBuilding = first
        lastOrdinalOfBuilding = last
        gateID = gate
    }

    /// 세션 칸 수. 지역 끝 표지의 순서이기도 하다.
    var count: Int { sessionNodes.count }

    /// 세션 칸 또는 지역 끝 표지의 순서.
    func ordinal(of nodeID: String) -> Int? {
        if let i = sessionOrdinal[nodeID] { return i }
        if nodeID == gateID { return count }
        return nil
    }

    /// 순서에 있는 칸 id. 세션 수면 지역 끝 표지.
    func nodeID(at ordinal: Int) -> String? {
        if sessionNodes.indices.contains(ordinal) { return sessionNodes[ordinal].id }
        return ordinal == count ? gateID : nil
    }

    func building(ofSession nodeID: String) -> String? {
        buildingOfSession[nodeID]
    }

    // MARK: 지금 칸

    /// 지금 칸: 처음으로 끝내지 않은 세션 칸. 모두 끝냈으면 지역 끝 표지 (4.1).
    /// 세션은 한 줄로 열리므로 `ProgressStore.homeTarget`의 세션과 같다.
    func currentNodeID(completed: Set<String>) -> String? {
        sessionNodes.first { !completed.contains($0.session ?? $0.id) }?.id ?? gateID
    }

    // MARK: 상태

    func state(ofSession nodeID: String, display: MapDisplay) -> MapNodeState {
        guard let i = sessionOrdinal[nodeID] else { return .locked }
        if i < display.markIndex { return .completed }
        if i == display.currentIndex { return .current }
        return .locked
    }

    /// 건물: 장면 완료는 진도 그대로(연출 전에도 결과 상태, 4.2), 열림은 연출이 정한다.
    func state(ofBuilding buildingID: String, display: MapDisplay, completed: Set<String>) -> MapBuildingState {
        guard let first = firstOrdinalOfBuilding[buildingID], let last = lastOrdinalOfBuilding[buildingID] else { return .locked }
        let sessions = sessionNodes[first...last].map { $0.session ?? $0.id }
        if sessions.allSatisfy(completed.contains) { return .completed }
        return first <= display.buildingOpenIndex ? .open : .locked
    }

    /// 길 조각이 지난 길(실선)인지: 조각의 끝 칸이 진행 선 끝(markIndex 칸)보다 앞이거나 같다 (2.5).
    func isPassed(_ path: MapPath, display: MapDisplay) -> Bool {
        guard let end = nodeID(at: display.markIndex), let endOrder = routeOrder[end],
              let toOrder = routeOrder[path.to]
        else { return false }
        return toOrder <= endOrder
    }

    // MARK: 연출 계획

    /// 보여 준 칸에서 지금 칸까지의 깡충 (4.1, 4.3, 4.4).
    func transition(from shownID: String?, to currentID: String, maxChain: Int) -> MapTransition {
        guard let to = ordinal(of: currentID) else { return .jump }
        guard let shownID, let from = ordinal(of: shownID) else { return .jump }
        let distance = to - from
        if distance == 0 { return .none }
        guard (1...maxChain).contains(distance) else { return .jump }
        var hops: [MapHop] = []
        for i in from..<to {
            let next = i + 1
            guard let nextID = nodeID(at: next), let fromID = nodeID(at: i) else { return .jump }
            let nextBuilding = buildingOfSession[nextID]
            if let nextBuilding, nextBuilding != buildingOfSession[fromID] {
                hops.append(MapHop(to: .front(nextBuilding), kind: .scene))
                hops.append(MapHop(to: .node(nextID), kind: .scene))
            } else {
                hops.append(MapHop(to: .node(nextID), kind: .step))
            }
        }
        return .hops(hops)
    }
}
