import SwiftUI

/// 말풍선과 시작 버튼 문구. 세션을 열 때 붙잡아 두었다가, 돌아와 연출하는 동안 "떠날 때 그 자리"의 것으로 보여 준다 (4.2).
struct MapLabels: Equatable {
    var bubble: String
    var buttonTitle: String?
}

/// 지도 화면 상태와 돌아왔을 때의 연출 (docs/design/home-map.md 4번).
/// 순서: 칸 완료 표시(0.2) → 기리 깡충(0.35, 장면을 넘으면 0.3 × 2) → 착지(표정·말풍선·새 칸·시작 버튼 문구, 0.25) → 보여 준 칸 저장.
@MainActor
@Observable
final class MapScreenModel {
    let definition: MapDefinition
    let route: MapRoute

    /// 지도가 마지막으로 보여 준 칸 (4.1). 저장소 값을 따라간다.
    private(set) var shownNodeID: String?
    /// 연출 동안 그리는 진행 정도. nil이면 `baselineDisplay`.
    private(set) var sequenceDisplay: MapDisplay?
    /// 기리가 밟는 자리들. 비어 있으면 기본 자리(`giriNodeID`)에 서 있다.
    private(set) var giriPath: [MapWaypoint] = []
    /// `giriPath`의 몇 번째 자리까지 왔는지(실수). 깡충 한 번이 1씩 움직인다.
    private(set) var giriProgress: Double = 0
    private(set) var giriPose: GiriPose = .talk
    private(set) var giriOpacity: Double = 1
    private(set) var bubbleHidden = false
    /// 세션을 열 때 붙잡은 문구. 착지할 때 놓는다.
    private(set) var frozenLabels: MapLabels?
    private(set) var isRunning = false

    @ObservationIgnored private let shownStore: MapShownStore
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var finishTarget: String?

    init(definition: MapDefinition, shownStore: MapShownStore) {
        self.definition = definition
        route = MapRoute(region: definition.regions[0])
        self.shownStore = shownStore
        shownNodeID = shownStore.shownNodeID
    }

    var motion: MapMotion { definition.motion }
    var metrics: MapMetrics { definition.metrics }

    // MARK: 그릴 상태

    func transition(to current: String) -> MapTransition {
        route.transition(from: shownNodeID, to: current, maxChain: motion.maxChainSessions)
    }

    /// 돌아와 연출을 기다리는 중인지(보여 준 칸 기준으로 그린다, 4.2).
    func isPending(current: String) -> Bool {
        if case .hops = transition(to: current) { return true }
        return false
    }

    /// 연출하지 않을 때의 기준 칸: 연출을 기다리면 보여 준 칸, 아니면 지금 칸.
    func anchorNodeID(current: String) -> String {
        if !isRunning, isPending(current: current), let shownNodeID { return shownNodeID }
        return finishTarget ?? current
    }

    func display(current: String) -> MapDisplay {
        if let sequenceDisplay { return sequenceDisplay }
        return MapDisplay(index: route.ordinal(of: anchorNodeID(current: current)) ?? 0)
    }

    /// 말풍선 문구. 연출을 기다리는 동안은 붙잡은 문구, 없으면(앱을 새로 열었을 때) 숨긴다.
    func bubbleText(current: String, live: String) -> String? {
        if bubbleHidden { return nil }
        if let frozenLabels { return frozenLabels.bubble }
        if !isRunning, isPending(current: current) { return nil }
        return live
    }

    func buttonTitle(live: String?) -> String? {
        frozenLabels?.buttonTitle ?? live
    }

    // MARK: 세션을 열고 닫을 때

    /// 세션 덮개를 띄우기 전에 지금 문구를 붙잡는다.
    func freeze(_ labels: MapLabels) {
        guard !isRunning else { return }
        frozenLabels = labels
    }

    /// 지도가 화면에 보이게 된 순간 (4.1): 덮개가 다 닫힌 뒤, K·S에서 뒤로 온 뒤, 앱을 연 뒤 첫 배치.
    /// - Parameters:
    ///   - scroll: 칸을 쉼 자리에 두는 스크롤. 애니메이션이 nil이면 바로 옮긴다.
    ///   - announce: VoiceOver 알림을 읽는다.
    func mapBecameVisible(current: String, reduceMotion: Bool, voiceOver: Bool,
                          scroll: @escaping (MapWaypoint, Animation?) -> Void,
                          announce: @escaping () -> Void) {
        guard !isRunning else { return }
        switch transition(to: current) {
        case .none:
            frozenLabels = nil
            remember(current)
        case .jump:
            frozenLabels = nil
            remember(current)
            scroll(.node(current), nil)
        case .hops(let hops):
            guard let from = shownNodeID else { return }
            if voiceOver {
                frozenLabels = nil
                remember(current)
                scroll(.node(current), nil)
                announce()
                return
            }
            run(from: from, to: current, hops: hops, reduceMotion: reduceMotion, scroll: scroll)
        }
    }

    /// 연출을 즉시 끝 상태로 만든다 (4.5). 스크롤 끌기, 칸·건물·꾸미기 입구·시작 버튼 누름, 백그라운드.
    /// - Returns: 연출 중이었는지(시작 버튼의 첫 탭은 연출만 끝낸다).
    @discardableResult
    func skip() -> Bool {
        guard isRunning, let target = finishTarget else { return false }
        task?.cancel()
        task = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { finish(at: target) }
        return true
    }

    /// 앱을 연 뒤나 보여 준 칸이 없을 때 지금 칸으로 맞춘다(연출 없음).
    func remember(_ nodeID: String) {
        shownNodeID = nodeID
        shownStore.shownNodeID = nodeID
    }

    // MARK: 연출

    private func run(from: String, to: String, hops: [MapHop], reduceMotion: Bool,
                     scroll: @escaping (MapWaypoint, Animation?) -> Void) {
        guard let fromIndex = route.ordinal(of: from), let toIndex = route.ordinal(of: to) else { return }
        isRunning = true
        finishTarget = to
        sequenceDisplay = MapDisplay(index: fromIndex)
        giriPath = [.node(from)] + hops.map(\.to)
        giriProgress = 0
        let motion = motion
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            if reduceMotion {
                await self.runReduced(to: to, toIndex: toIndex, hops: hops, scroll: scroll, motion: motion)
            } else {
                await self.runFull(to: to, toIndex: toIndex, hops: hops, scroll: scroll, motion: motion)
            }
        }
    }

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    private func runFull(to: String, toIndex: Int, hops: [MapHop],
                         scroll: (MapWaypoint, Animation?) -> Void, motion: MapMotion) async {
        // 덮개가 내려간 직후 한 프레임을 그린 뒤 시작한다.
        guard await pause(0.05) else { return }
        // 2 칸 완료 표시 + 말풍선 사라짐.
        withAnimation(.easeInOut(duration: motion.markFade)) { sequenceDisplay?.markIndex = toIndex }
        withAnimation(.easeOut(duration: motion.bubbleOut)) { bubbleHidden = true }
        guard await pause(motion.markFade) else { return }

        // 3 깡충. 표정은 처음에 웃음.
        withAnimation(.easeInOut(duration: motion.faceSwap)) { giriPose = .happy }
        var i = 0
        while i < hops.count {
            let hop = hops[i]
            if hop.kind == .scene, case .front = hop.to, i + 1 < hops.count {
                // 장면 완료: 건물 열림과 깡충 ①을 같이, 이어서 깡충 ②. 스크롤은 a 칸까지 한 번 (4.4).
                let landing = hops[i + 1].to
                if case .node(let id) = landing, let open = route.ordinal(of: id) {
                    withAnimation(.easeInOut(duration: motion.buildingOpen)) { sequenceDisplay?.buildingOpenIndex = open }
                }
                scroll(landing, .easeInOut(duration: motion.hopScene * 2))
                let start = Double(i)
                withAnimation(.easeInOut(duration: motion.hopScene)) { giriProgress = start + 1 }
                guard await pause(motion.hopScene) else { return }
                withAnimation(.easeInOut(duration: motion.hopScene)) { giriProgress = start + 2 }
                guard await pause(motion.hopScene) else { return }
                i += 2
            } else {
                scroll(hop.to, .easeInOut(duration: motion.hop))
                let next = Double(i + 1)
                withAnimation(.easeInOut(duration: motion.hop)) { giriProgress = next }
                guard await pause(motion.hop) else { return }
                i += 1
            }
        }

        // 4 착지: 표정 말하기, 새 칸 지금 모양, 시작 버튼 문구, 새 말풍선.
        withAnimation(.easeInOut(duration: motion.faceSwap)) { giriPose = .talk }
        withAnimation(.easeInOut(duration: motion.labelFade)) {
            sequenceDisplay?.currentIndex = toIndex
            sequenceDisplay?.buildingOpenIndex = toIndex
            frozenLabels = nil
        }
        withAnimation(.spring(response: motion.bubbleIn, dampingFraction: 0.85)) { bubbleHidden = false }
        guard await pause(motion.bubbleIn) else { return }
        finish(at: to)
    }

    /// 동작 줄이기: 위치가 움직이는 것을 모두 없앤다. 기리는 불투명도로만 옮긴다(0.15 + 0.15초, 4.5).
    private func runReduced(to: String, toIndex: Int, hops: [MapHop],
                            scroll: (MapWaypoint, Animation?) -> Void, motion: MapMotion) async {
        guard await pause(0.05) else { return }
        sequenceDisplay?.markIndex = toIndex
        withAnimation(.easeOut(duration: motion.reduceMotionFade)) { giriOpacity = 0 }
        guard await pause(motion.reduceMotionFade) else { return }
        sequenceDisplay = MapDisplay(index: toIndex)
        giriProgress = Double(hops.count)
        frozenLabels = nil
        scroll(.node(to), nil)
        withAnimation(.easeIn(duration: motion.reduceMotionFade)) { giriOpacity = 1 }
        guard await pause(motion.reduceMotionFade) else { return }
        finish(at: to)
    }

    private func finish(at nodeID: String) {
        sequenceDisplay = nil
        giriPath = []
        giriProgress = 0
        giriPose = .talk
        giriOpacity = 1
        bubbleHidden = false
        frozenLabels = nil
        isRunning = false
        finishTarget = nil
        remember(nodeID)
    }
}

/// 깡충: 가로는 곧게, 세로는 직선 보간 위에 `lift`만큼 솟는 포물선 (4.3).
/// `progress`가 정수 k에서 k+1로 움직이는 동안 `points[k]` → `points[k+1]`을 뛴다.
struct MapHopEffect: ViewModifier, Animatable {
    var progress: Double
    let points: [CGPoint]
    let lift: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.position(position)
    }

    private var position: CGPoint {
        guard let first = points.first else { return .zero }
        guard points.count > 1 else { return first }
        let clamped = min(max(progress, 0), Double(points.count - 1))
        let k = min(Int(clamped.rounded(.down)), points.count - 2)
        let t = CGFloat(clamped - Double(k))
        let a = points[k], b = points[k + 1]
        let x = a.x + (b.x - a.x) * t
        let y = a.y + (b.y - a.y) * t - lift * 4 * t * (1 - t)
        return CGPoint(x: x, y: y)
    }
}
