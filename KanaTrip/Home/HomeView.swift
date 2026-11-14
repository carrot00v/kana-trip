import SwiftUI

/// 홈의 NavigationStack에 쌓는 화면.
enum HomeRoute: Hashable {
    case scene(String)
    /// K 기리 꾸미기 (docs/design/reward-flow.md 2.2).
    case customize
}

/// H 홈(장면 목록).
struct HomeView: View {
    @Environment(ProgressStore.self) private var store
    @State private var path: [HomeRoute] = []
    @State private var route: SessionRoute?
    @State private var showsComingSoon = false
    @Environment(\.dynamicTypeSize) private var typeSize
    #if DEBUG
    @State private var showsSpike = false
    #endif

    private let library = ContentLibrary.shared

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $path) {
            List {
                Section {
                    giriRow
                        .listRowBackground(Color.cardBackground)
                }
                Section {
                    ForEach(library.scenes) { scene in
                        row(scene)
                            .listRowBackground(Color.cardBackground)
                    }
                } header: {
                    Text(library.sectionTitle)
                        .foregroundStyle(Color.inkSecondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.appTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle(L.soundToggle, isOn: $store.soundOn)
                        #if DEBUG
                        Button(L.devSpike) { showsSpike = true }
                        #endif
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.accent)
                    }
                    .accessibilityLabel(L.more)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let target = nextTarget {
                    PrimaryButton(
                        title: L.homeStart(
                            scene: target.scene.name,
                            step: L.sessionName(target.session),
                            resume: store.isInProgress(target.session)
                        )
                    ) {
                        // 세션을 닫으면 장면 진입이 아래에 깔려 있도록 먼저 push한다.
                        path = [.scene(target.scene.id)]
                        route = SessionRoute(sessionID: target.session.id)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .navigationDestination(for: HomeRoute.self) { destination in
                switch destination {
                case .scene(let sceneID):
                    if let scene = library.scene(id: sceneID) {
                        SceneDetailView(
                            scene: scene,
                            onStart: { route = SessionRoute(sessionID: $0.id) },
                            onBackToList: { path = [] }
                        )
                    }
                case .customize:
                    CustomizeView()
                }
            }
            .alert(L.comingSoon, isPresented: $showsComingSoon) {
                Button(L.ok, role: .cancel) {}
            }
        }
        .fullScreenCover(item: $route) { route in
            if let session = library.session(id: route.sessionID) {
                SessionView(
                    initialSession: session,
                    onClose: { self.route = nil },
                    onBackToList: {
                        path = []
                        self.route = nil
                    },
                    onCustomize: {
                        // 덮개를 닫고 장면 진입은 쌓지 않은 채 홈 위에 꾸미기를 띄운다.
                        self.route = nil
                        path = [.customize]
                    }
                )
                .appStyle()
            }
        }
        #if DEBUG
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

    // MARK: - 기리 행

    /// 목록 맨 위의 기리 행 (reward-flow.md 4번). 행 전체가 누르는 영역이고 기리 그림은 장식이다.
    /// 접근성 글자 크기에서는 기리를 숨긴다 (visual-rules.md 8.1).
    private var giriRow: some View {
        let canBuy = store.canBuyAnyItem
        return Button {
            path.append(.customize)
        } label: {
            HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    GiriView(face: .normal, outfit: store.rewards.equipped, side: 64)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.customize)
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    Text(L.coinsBalance(store.rewards.coins))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.inkSecondary)
                    if canBuy {
                        HStack(spacing: 4) {
                            Image(systemName: "yensign.circle.fill")
                                .foregroundStyle(Color.highlightStrong)
                            Text(L.canBuyItem)
                                .foregroundStyle(Color.ink)
                        }
                        .font(.footnote)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 80)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.customizeRowLabel(balance: store.rewards.coins, canBuy: canBuy))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - 장면 상태

    /// 장면 1은 처음부터 열려 있고, 그 뒤 장면은 앞 장면의 두 단계를 끝내면 열린다.
    private func status(_ scene: TripScene) -> SceneRowStatus {
        if store.isSceneCompleted(scene) { return .completed }
        return store.isSceneUnlocked(scene) ? .open : .locked
    }

    /// 아래 주 버튼이 시작할 장면과 세션. 열린 장면의 내용이 아직 없으면 버튼을 숨긴다.
    private var nextTarget: (scene: TripScene, session: TripSession)? {
        guard let scene = library.scenes.first(where: { status($0) == .open }),
              scene.hasContent,
              let session = store.nextSession(in: scene)
        else { return nil }
        return (scene, session)
    }

    // MARK: - 장면 행 (scene-flow.md 5번, scene-art/brief.md 2번)

    @ViewBuilder
    private func row(_ scene: TripScene) -> some View {
        let status = status(scene)
        let done = store.completedSessionCount(scene)
        let total = library.sessions(in: scene).count
        Button {
            if scene.hasContent {
                path.append(.scene(scene.id))
            } else {
                showsComingSoon = true
            }
        } label: {
            HStack(spacing: 12) {
                SceneThumbnail(scene: scene, status: status)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(scene.order)  \(scene.name)")
                        .font(.headline)
                        .foregroundStyle(status == .locked ? Color.inkSecondary : Color.ink)
                        .lineLimit(1)
                    stepKanaLine(scene)
                        .foregroundStyle(status == .locked ? Color.inkSecondary : Color.ink)
                }
                // 글자 줄이 오른쪽 "0/3 ›"보다 먼저 자리를 차지한다 (scene-flow.md 5번 폭 확인).
                .layoutPriority(1)

                Spacer(minLength: 0)

                if status != .locked {
                    Text(status == .completed ? L.done : "\(done)/\(total)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Color.inkSecondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 52)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 잠긴 행은 반응하지 않는다. `.disabled`는 행 전체를 흐리게 하므로 쓰지 않는다(그림의 불투명도는 낮추지 않는다, brief.md 2.2).
        .allowsHitTesting(status != .locked)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            status == .locked
                ? L.sceneRowLocked(order: scene.order, name: scene.name)
                : L.sceneRowLabel(order: scene.order, name: scene.name, steps: scene.steps.map { ($0.name, $0.kana) }, done: done, total: total)
        )
        .accessibilityAddTraits(status == .locked ? [] : .isButton)
    }

    /// 새 글자를 단계별로 나눠 놓는다: "す し · い か た こ". 글자 20pt, 가운뎃점 좌우 8pt.
    private func stepKanaLine(_ scene: TripScene) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(scene.steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    Text("·").font(.system(size: 20)).foregroundStyle(Color.inkSecondary)
                }
                KanaText(text: step.kana.joined(separator: " "), size: 20)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

enum SceneRowStatus {
    case locked, open, completed
}

/// 홈 장면 행의 장면 그림 52×52pt와 상태 배지 (scene-art/brief.md 2번).
/// 에셋이 없으면 대체 그림, 그것도 없으면 SF Symbol 상태 아이콘을 그린다. 큰 글자 크기에서는 그림을 숨긴다.
struct SceneThumbnail: View {
    let scene: TripScene
    let status: SceneRowStatus

    @Environment(\.dynamicTypeSize) private var typeSize

    static let side: CGFloat = 52
    static let badge: CGFloat = 22

    private var image: UIImage? {
        UIImage(named: scene.thumbnailName) ?? UIImage(named: TripScene.placeholderThumbnailName)
    }

    var body: some View {
        if !typeSize.isAccessibilitySize, let image {
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Self.side, height: Self.side)
                    .saturation(status == .locked ? 0 : 1)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12).strokeBorder(Color.outline, lineWidth: AppStyle.outlineWidth)
                    }
                if let badge {
                    Image(systemName: badge.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(badge.color)
                        .frame(width: Self.badge, height: Self.badge)
                        .background(Color.cardBackground, in: Circle())
                        // 원의 중심을 그림 오른쪽 아래 꼭짓점에서 왼쪽과 위로 7pt에 둔다.
                        .offset(x: Self.side - 7 - Self.badge / 2, y: Self.side - 7 - Self.badge / 2)
                }
            }
            .frame(width: Self.side, height: Self.side, alignment: .topLeading)
        } else {
            statusIcon
                .font(.title2)
                .frame(width: 28)
        }
    }

    private var badge: (symbol: String, color: Color)? {
        switch status {
        case .open: nil
        case .locked: ("lock.fill", .inkSecondary)
        case .completed: ("checkmark.circle.fill", .correct)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .locked:
            Image(systemName: "lock.fill").foregroundStyle(Color.inkSecondary)
        case .open:
            Image(systemName: scene.icon ?? "lock.open.fill").foregroundStyle(Color.accent)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.correct)
        }
    }
}
