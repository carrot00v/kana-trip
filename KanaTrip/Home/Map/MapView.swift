import SwiftUI

/// 홈 지도: 세로로 스크롤되는 여행 길 (docs/design/home-map.md 1~4번, "2026-11-21 재구성안" 안 A).
/// 구간을 위에서 아래로(데이터의 역순) 쌓고, 그 위에 기리 덮개 층을 얹는다. 아래 고정 영역은 바깥(HomeView)에 있다.
struct MapView: View {
    let model: MapScreenModel
    /// 지금 칸의 id (진도에서 계산).
    let currentNodeID: String
    /// 지금 칸의 기리 대사.
    let liveBubble: String
    /// 지도가 화면에 보이게 될 때마다 1씩 오른다(연출 비교, 4.1).
    let visibleTick: Int
    /// 세션 덮개가 닫히기 전에 1씩 오른다: 보여 준 칸을 쉼 자리에 미리 맞춘다(4.2).
    let prepareTick: Int
    let onTapSession: (TripSession, MapNodeState) -> Void
    let onTapScene: (TripScene) -> Void
    let announce: (String) -> Void

    @Environment(ProgressStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var position = ScrollPosition(idType: String.self)
    @State private var visibleTop: CGFloat = 0
    @State private var didInitialScroll = false

    private var library: ContentLibrary { .shared }
    private var metrics: MapMetrics { model.metrics }
    private var region: MapRegion { model.route.region }

    var body: some View {
        GeometryReader { geo in
            let layout = MapLayout(region: region, metrics: metrics, width: geo.size.width, viewportHeight: geo.size.height)
            let display = model.display(current: currentNodeID)
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    // 구간은 10개뿐이고 높이가 고정이라 VStack으로 쌓는다. 기리 덮개 층과 겹친 ZStack 안의
                    // LazyVStack은 시뮬레이터에서 구간을 그리지 않았다(구현 값, home-map.md 8.1).
                    VStack(spacing: 0) {
                        Color.clear.frame(height: layout.topMargin)
                        ForEach(region.sections.reversed()) { section in
                            sectionView(section, width: geo.size.width, display: display)
                        }
                        Color.clear.frame(height: layout.bottomMargin)
                    }
                    giriLayer(layout: layout, size: CGSize(width: geo.size.width, height: layout.contentHeight))
                }
                .frame(width: geo.size.width, height: layout.contentHeight, alignment: .topLeading)
            }
            .scrollPosition($position)
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, top in
                visibleTop = top
            }
            .onScrollPhaseChange { _, phase in
                // 연출 도중 끌면 즉시 끝 상태로 (4.5).
                if phase == .interacting { model.skip() }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L.mapLabel)
            .overlay(alignment: .bottom) {
                bottomOverlay(layout: layout, viewport: geo.size.height)
            }
            .onAppear {
                guard geo.size.height > 0 else { return }
                initialScroll(layout: layout, viewport: geo.size.height)
            }
            .onChange(of: geo.size) { _, size in
                guard size.height > 0 else { return }
                initialScroll(layout: layout, viewport: size.height)
            }
            .onChange(of: visibleTick) { _, _ in
                mapBecameVisible(layout: layout, viewport: geo.size.height)
            }
            .onChange(of: prepareTick) { _, _ in
                // 덮개에 가려 있을 때 보여 준 칸을 쉼 자리에 둔다.
                scroll(to: .node(model.anchorNodeID(current: currentNodeID)), layout: layout, viewport: geo.size.height, animation: nil)
            }
        }
        // 바탕색 + 홈 바탕 풍경(고정 띠) + 위 씻김 (home-backdrop.md 2.1). 풍경이 있을 때만 지도 요소에 바탕색 테 (2.4).
        .background(MapBackdropLayer(backdrop: MapPalette.backdrop))
        .environment(\.mapHalo, MapPalette.backdrop != nil && contrast != .increased)
    }

    // MARK: 스크롤

    private func point(_ waypoint: MapWaypoint, layout: MapLayout) -> CGPoint? {
        switch waypoint {
        case .node(let id): layout.center(of: id)
        case .front(let id): layout.front(of: id)
        }
    }

    private func scroll(to waypoint: MapWaypoint, layout: MapLayout, viewport: CGFloat, animation: Animation?) {
        guard let p = point(waypoint, layout: layout) else { return }
        let y = layout.restOffset(forContentY: p.y, viewportHeight: viewport, restAnchor: metrics.restAnchor)
        if let animation {
            withAnimation(animation) { position.scrollTo(y: y) }
        } else {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { position.scrollTo(y: y) }
        }
    }

    /// 앱을 연 뒤 첫 배치: 기리가 선 칸을 움직임 없이 쉼 자리에 두고, 한 박자 뒤 연출 비교 (3.1).
    private func initialScroll(layout: MapLayout, viewport: CGFloat) {
        guard !didInitialScroll else { return }
        didInitialScroll = true
        #if DEBUG
        if let target = MapDebug.scrollTo {
            scroll(to: .node(target), layout: layout, viewport: viewport, animation: nil)
            return
        }
        #endif
        scroll(to: .node(model.anchorNodeID(current: currentNodeID)), layout: layout, viewport: viewport, animation: nil)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            mapBecameVisible(layout: layout, viewport: viewport)
        }
    }

    private func mapBecameVisible(layout: MapLayout, viewport: CGFloat) {
        model.mapBecameVisible(
            current: currentNodeID,
            reduceMotion: reduceMotion,
            voiceOver: voiceOver,
            scroll: { waypoint, animation in
                scroll(to: waypoint, layout: layout, viewport: viewport, animation: animation)
            },
            announce: { announce(currentNodeID) }
        )
    }

    // MARK: 구간

    private func sectionView(_ section: MapSection, width: CGFloat, display: MapDisplay) -> some View {
        let completed = store.state.completedSessionIDs
        let route = model.route
        let bandState = section.nodes.first { $0.kind == .band }
            .map { route.state(ofBand: $0.id, display: display, completed: completed) }
        return MapSectionView(
            section: section,
            width: width,
            metrics: metrics,
            node: { nodeInfo($0, display: display) },
            band: { bandInfo($0, state: route.state(ofBand: $0.id, display: display, completed: completed)) },
            showsStickers: bandState == .completed,
            onTapNode: { node in
                model.skip()
                guard let session = library.session(id: node.session ?? node.id) else { return }
                onTapSession(session, route.state(ofSession: node.id, display: model.display(current: currentNodeID)))
            },
            onTapBand: { node in
                model.skip()
                guard let scene = library.scene(id: node.scene ?? node.id) else { return }
                onTapScene(scene)
            }
        )
        .frame(height: section.height)
    }

    private func nodeInfo(_ node: MapNode, display: MapDisplay) -> MapNodeInfo {
        guard let session = library.session(id: node.session ?? node.id), let scene = library.scene(of: session) else {
            return MapNodeInfo()
        }
        let state = model.route.state(ofSession: node.id, display: display)
        var info = MapNodeInfo(state: state, kana: session.step?.kana ?? [])
        if session.isQuiz, state != .completed, store.nextSession(in: scene)?.id == session.id {
            // 복습 글자 수는 지금 차례인 종합 퀴즈 칸의 VoiceOver 레이블에만 붙인다. 지도에는 적지 않는다(1.2).
            let saved = store.progress(for: session.id).quiz?.review
            info.review = saved?.count ?? store.reviewKana(for: scene).count
        }
        let status: String
        switch state {
        case .locked: status = L.nodeStatusLocked(previous: MapCopy.previousSessionName(of: session))
        case .current: status = store.isInProgress(session) ? L.nodeStatusResume : L.nodeStatusMyTurn
        case .completed: status = L.doneRedoLabel
        }
        if let step = session.step {
            info.accessibilityLabel = L.stepNodeLabel(order: scene.order, scene: scene.name, step: step.name, kana: step.kana, status: status)
        } else {
            info.accessibilityLabel = AttributedString(L.quizNodeLabel(order: scene.order, scene: scene.name, review: info.review, status: status))
        }
        return info
    }

    private func bandInfo(_ node: MapNode, state: MapBandState) -> MapBandInfo {
        guard let scene = library.scene(id: node.scene ?? node.id) else { return MapBandInfo() }
        let label: String
        switch state {
        case .locked: label = L.buildingLabel(order: scene.order, name: scene.name, status: L.locked)
        case .open: label = L.buildingLabel(order: scene.order, name: scene.name, status: "\(L.buildingInProgress), \(L.buildingSeeWords)")
        case .completed: label = L.buildingLabel(order: scene.order, name: scene.name, status: "\(L.done), \(L.buildingSeeWords)")
        }
        return MapBandInfo(state: state, order: scene.order, name: scene.name, kana: scene.kana, icon: scene.icon,
                           accessibilityLabel: label)
    }

    // MARK: 기리

    /// 기리 가운데: 칸이면 칸 오른쪽 옆, 장면 띠면 띠 가운데 (R2.3, R2.4).
    private func giriCenter(_ waypoint: MapWaypoint, layout: MapLayout) -> CGPoint? {
        switch waypoint {
        case .node(let id): layout.giriCenter(atNode: id)
        case .front(let id): layout.front(of: id)
        }
    }

    @ViewBuilder
    private func giriLayer(layout: MapLayout, size: CGSize) -> some View {
        let anchor = model.anchorNodeID(current: currentNodeID)
        let path = model.giriPath.isEmpty ? [MapWaypoint.node(anchor)] : model.giriPath
        let centers = path.compactMap { giriCenter($0, layout: layout) }
        // 말풍선은 서 있는 칸에: 연출 중이면 지금까지 온 자리, 아니면 기준 칸.
        let standing: String? = {
            guard model.isRunning else { return anchor }
            let i = min(max(Int(model.giriProgress.rounded()), 0), path.count - 1)
            if case .node(let id) = path[i] { return id }
            return nil
        }()
        let bubbleText = typeSize.isAccessibilitySize ? nil : model.bubbleText(current: currentNodeID, live: liveBubble)
        let bubble: MapGiriLayer.Bubble? = {
            guard let bubbleText, let standing, let center = layout.giriCenter(atNode: standing) else { return nil }
            return MapGiriLayer.Bubble(text: bubbleText, giriCenter: center)
        }()
        if !centers.isEmpty {
            MapGiriLayer(
                metrics: metrics,
                width: size.width,
                height: size.height,
                giriCenters: centers,
                progress: model.giriProgress,
                pose: model.giriPose,
                motion: model.giriMotion,
                opacity: model.giriOpacity,
                isHopping: model.isRunning,
                bubble: bubble
            )
        }
    }

    // MARK: 아래 겹침: 그라데이션과 "지금 칸으로" (3.2, 5.1)

    @ViewBuilder
    private func bottomOverlay(layout: MapLayout, viewport: CGFloat) -> some View {
        let anchor = model.anchorNodeID(current: currentNodeID)
        let y = layout.center(of: anchor)?.y ?? 0
        let margin = metrics.edgeMargin
        let above = y < visibleTop + margin
        let below = y > visibleTop + viewport - margin
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [MapPalette.ground.opacity(0), MapPalette.ground], startPoint: .top, endPoint: .bottom)
                .frame(height: MapShape.bottomFade)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            if (above || below) && !model.isRunning {
                // 44pt 원 버튼, 아이콘만, 테 없는 옅은 강조색 바탕. 오른쪽 여백 16, 아래 고정 영역 위 12 (R2.3).
                Button {
                    scroll(to: .node(anchor), layout: layout, viewport: viewport,
                           animation: reduceMotion ? nil : .easeInOut(duration: model.motion.jumpScroll))
                } label: {
                    Image(systemName: above ? "arrow.up" : "arrow.down")
                        .font(.system(size: MapShape.jumpIcon, weight: .bold))
                        .foregroundStyle(MapPalette.softAccent)
                        .frame(width: metrics.jumpButton, height: metrics.jumpButton)
                        .background(MapPalette.softAccent.opacity(MapPalette.softAccentOpacity), in: Circle())
                        .background(MapPalette.ground, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(MapPressStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, MapShape.screenMargin)
                .padding(.bottom, MapShape.jumpBottom)
                .transition(.opacity)
                .accessibilityLabel(L.toCurrentNodeLabel)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: above || below)
    }
}

#if DEBUG
/// 화면 확인용 실행 인자 (DEBUG 빌드 전용). 진도 저장을 건드리지 않는다.
///   -mapDebugCompleted N   앞에서부터 N개 세션을 끝낸 진도(메모리에만)
///   -mapDebugShown ID      보여 준 칸(연출 비교 시작점). "none"이면 없음
///   -mapDebugScrollTo ID   처음 스크롤할 칸(연출 없이)
///   -mapDebugCard ID       처음에 칸 카드를 띄울 칸
///   -mapDebugCanvas WxH    앱 전체를 W×H pt 틀 안에 그린다(작은 화면 확인)
enum MapDebug {
    private static func value(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let at = args.firstIndex(of: name), at + 1 < args.count else { return nil }
        return args[at + 1]
    }

    static var completedCount: Int? { value("-mapDebugCompleted").flatMap(Int.init) }
    static var shown: String?? {
        guard let v = value("-mapDebugShown") else { return nil }
        return .some(v == "none" ? nil : v)
    }
    static var scrollTo: String? { value("-mapDebugScrollTo") }
    static var card: String? { value("-mapDebugCard") }
    static var canvas: CGSize? {
        guard let v = value("-mapDebugCanvas") else { return nil }
        let parts = v.split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }
}
#endif
