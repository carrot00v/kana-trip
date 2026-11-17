import SwiftUI

/// 홈의 NavigationStack에 쌓는 화면.
enum HomeRoute: Hashable {
    case scene(String)
    /// K 기리 꾸미기 (docs/design/reward-flow.md 2.2).
    case customize
    /// 앱 정보(크레딧). "더 보기" 메뉴에서 연다.
    case about
    /// 앱 정보 안의 라이선스 전문.
    case license(LicenseText)
}

/// 칸 카드 시트에 띄울 칸.
private struct NodeCardRoute: Identifiable {
    let sessionID: String
    let state: MapNodeState

    var id: String { sessionID }
}

/// H 홈 = 지도 (docs/design/home-map.md). 위: 인라인 바(가운데 진행률, 오른쪽 메뉴). 가운데: 지도.
/// 아래 고정 72pt: [꾸미기 입구][시작 버튼]. 세션을 닫으면 어디서 열었든 지도로 돌아와 연출한다 (3.4, 4번).
struct HomeView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var path: [HomeRoute] = []
    @State private var route: SessionRoute?
    /// 세션 덮개가 떠 있는 동안(닫히는 애니메이션이 끝날 때까지) true.
    @State private var coverActive = false
    @State private var card: NodeCardRoute?
    @State private var pendingChoice: NodeCardSheet.Choice?
    @State private var showsComingSoon = false
    @State private var visibleTick = 0
    @State private var prepareTick = 0
    @State private var model: MapScreenModel? = HomeView.makeModel()
    #if DEBUG
    @State private var showsSpike = false
    #endif

    private let library = ContentLibrary.shared

    private static func makeModel() -> MapScreenModel? {
        guard let definition = MapDefinition.bundled, !definition.regions.isEmpty else { return nil }
        #if DEBUG
        if let shown = MapDebug.shown {
            return MapScreenModel(definition: definition, shownStore: MapShownStore(override: .some(shown)))
        }
        #endif
        return MapScreenModel(definition: definition, shownStore: MapShownStore())
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $path) {
            Group {
                if let model, let current = store.mapCurrentNodeID(route: model.route) {
                    MapView(
                        model: model,
                        currentNodeID: current,
                        liveBubble: giriLine,
                        visibleTick: visibleTick,
                        prepareTick: prepareTick,
                        onTapSession: openCard,
                        onTapScene: openScene,
                        announce: announce
                    )
                    .safeAreaInset(edge: .bottom, spacing: 0) { dock(model: model, current: current) }
                } else {
                    Color.appBackground
                }
            }
            .background(Color.appBackground)
            .navigationTitle(L.mapTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(MapPalette.ground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    let done = library.scenes.count { store.isSceneCompleted($0) }
                    Text(L.regionProgress(script: library.sectionTitle, done: done, total: library.scenes.count))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Color.ink)
                        .accessibilityLabel(L.regionProgressLabel(script: library.sectionTitle, done: done, total: library.scenes.count))
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle(L.soundToggle, isOn: $store.soundOn)
                        Button(L.about, systemImage: "info.circle") { path.append(.about) }
                        #if DEBUG
                        Button(L.devSpike) { showsSpike = true }
                        Button("개발용: 지금 칸 끝내기") { debugCompleteCurrent() }
                        #endif
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.accent)
                    }
                    .accessibilityLabel(L.more)
                }
            }
            .navigationDestination(for: HomeRoute.self) { destination in
                switch destination {
                case .scene(let sceneID):
                    if let scene = library.scene(id: sceneID) {
                        SceneDetailView(
                            scene: scene,
                            onStart: startSession,
                            onBackToList: { path = [] }
                        )
                    }
                case .customize:
                    CustomizeView()
                case .about:
                    AboutView()
                case .license(let license):
                    LicenseTextView(license: license)
                }
            }
            .alert(L.comingSoon, isPresented: $showsComingSoon) {
                Button(L.ok, role: .cancel) {}
            }
            .sheet(item: $card, onDismiss: cardDismissed) { card in
                if let session = library.session(id: card.sessionID) {
                    NodeCardSheet(session: session, state: card.state) { pendingChoice = $0 }
                        .appStyle()
                }
            }
        }
        .fullScreenCover(item: $route, onDismiss: coverDismissed) { route in
            if let session = library.session(id: route.sessionID) {
                SessionView(
                    initialSession: session,
                    onClose: closeToMap,
                    onBackToList: closeToMap,
                    onCustomize: {
                        // 덮개를 닫고 지도 위에 꾸미기를 띄운다. K에서 뒤로 가면 지도가 보이고 그때 연출한다 (3.4).
                        prepareTick += 1
                        self.route = nil
                        path = [.customize]
                    }
                )
                .appStyle()
            }
        }
        .onChange(of: path) { _, newPath in
            // K·S에서 뒤로 와 지도가 보이게 됨. 덮개가 닫히는 중이면 onDismiss가 맡는다.
            if newPath.isEmpty, !coverActive { visibleTick += 1 }
        }
        .onChange(of: scenePhase) { _, phase in
            // 연출 도중 백그라운드로 가면 끝 상태로 저장 (4.5).
            if phase == .background { model?.skip() }
        }
        #if DEBUG
        .onAppear {
            if let id = MapDebug.card, let session = library.session(id: id), let model {
                let current = store.mapCurrentNodeID(route: model.route) ?? ""
                openCard(session, model.route.state(ofSession: id, display: model.display(current: current)))
            }
        }
        .fullScreenCover(isPresented: $showsSpike) {
            VStack(spacing: 0) {
                HStack {
                    Button(L.close) { showsSpike = false }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                WritingSpikeView()
            }
            .background(Color.appBackground)
            .appStyle()
        }
        #endif
    }

    // MARK: 문구

    /// 기리가 권하는 말 (giri-companion.md 3.11의 H).
    private var giriLine: String {
        GiriSpeech.home(store.giriHomeTurn(in: library))
    }

    private var target: (scene: TripScene, session: TripSession)? {
        store.homeTarget(in: library)
    }

    private func longTitle(_ target: (scene: TripScene, session: TripSession)) -> String {
        L.homeStart(scene: target.scene.name, step: L.sessionName(target.session), resume: store.isInProgress(target.session))
    }

    private var liveLabels: MapLabels {
        MapLabels(bubble: giriLine, buttonTitle: target.map(longTitle))
    }

    // MARK: 아래 고정 영역 (5.1)

    private func dock(model: MapScreenModel, current: String) -> some View {
        let live = target
        let long = model.buttonTitle(live: live.map(longTitle))
        let short = live.map { L.stepAction(L.sessionName($0.session), resume: store.isInProgress($0.session)) }
        // 큰 글자 크기: 말풍선을 아래 고정 영역 카드로. 연출을 기다리는 동안은 붙잡은 문구.
        let card = model.bubbleText(current: current, live: giriLine) ?? model.frozenLabels?.bubble ?? giriLine
        return MapDock(
            metrics: model.metrics,
            longTitle: long,
            shortTitle: model.frozenLabels == nil ? short : nil,
            bubbleCard: card,
            coins: store.rewards.coins,
            canBuy: store.canBuyAnyItem,
            onCustomize: {
                model.skip()
                path.append(.customize)
            },
            onStart: {
                // 연출 도중 첫 탭은 연출을 끝 상태로 만들기만 한다 (4.5).
                if model.skip() { return }
                guard let live else { return }
                startSession(live.session)
            }
        )
    }

    // MARK: 세션 열고 닫기 (3.1, 3.4)

    private func startSession(_ session: TripSession) {
        model?.freeze(liveLabels)
        coverActive = true
        route = SessionRoute(sessionID: session.id)
    }

    /// 세션을 닫으면 지도로. 덮개가 내려가기 전에 보여 준 칸을 쉼 자리에 두고 스택을 비운다 (4.2).
    private func closeToMap() {
        prepareTick += 1
        path = []
        route = nil
    }

    private func coverDismissed() {
        coverActive = false
        if path.isEmpty { visibleTick += 1 }
    }

    // MARK: 칸과 건물 (3.3)

    private func openCard(_ session: TripSession, _ state: MapNodeState) {
        guard library.scene(of: session)?.hasContent == true else {
            showsComingSoon = true
            return
        }
        card = NodeCardRoute(sessionID: session.id, state: state)
    }

    private func cardDismissed() {
        guard let choice = pendingChoice else { return }
        pendingChoice = nil
        switch choice {
        case .session(let session): startSession(session)
        case .sceneWords(let sceneID): path.append(.scene(sceneID))
        }
    }

    private func openScene(_ scene: TripScene) {
        guard scene.hasContent else {
            showsComingSoon = true
            return
        }
        path.append(.scene(scene.id))
    }

    // MARK: VoiceOver 알림 (4.5)

    private func announce(_ current: String) {
        let text: String
        if let session = library.session(id: current), let scene = library.scene(of: session) {
            if let step = session.step, step.index == 0, scene.order > 1 {
                text = L.newSceneAnnouncement(scene: scene.name, step: step.name)
            } else {
                text = L.turnAnnouncement(scene: scene.name, session: L.sessionName(session))
            }
        } else {
            text = L.giriAllDone
        }
        AccessibilityNotification.Announcement(text).post()
    }

    #if DEBUG
    /// 개발용: 지금 칸의 세션을 끝낸 것으로 저장하고 돌아온 연출을 본다.
    private func debugCompleteCurrent() {
        guard let target else { return }
        model?.freeze(liveLabels)
        _ = SessionRun(session: target.session, store: store).complete()
        visibleTick += 1
    }
    #endif
}
