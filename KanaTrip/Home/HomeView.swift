import SwiftUI

/// H 홈(장면 목록).
struct HomeView: View {
    @Environment(ProgressStore.self) private var store
    @State private var path: [String] = []
    @State private var route: SessionRoute?
    @State private var showsComingSoon = false
    #if DEBUG
    @State private var showsSpike = false
    #endif

    private let library = ContentLibrary.shared

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $path) {
            List {
                Section(library.sectionTitle) {
                    ForEach(library.scenes) { scene in
                        row(scene)
                    }
                }
            }
            .listStyle(.insetGrouped)
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
                    }
                    .accessibilityLabel(L.more)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let target = nextTarget {
                    PrimaryButton(
                        title: L.homeStart(
                            scene: target.scene.name,
                            step: target.step.name,
                            resume: store.isInProgress(target.step)
                        )
                    ) {
                        // 세션을 닫으면 장면 진입이 아래에 깔려 있도록 먼저 push한다.
                        path = [target.scene.id]
                        route = SessionRoute(stepID: target.step.id)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .navigationDestination(for: String.self) { sceneID in
                if let scene = library.scene(id: sceneID) {
                    SceneDetailView(
                        scene: scene,
                        onStart: { route = SessionRoute(stepID: $0.id) },
                        onBackToList: { path = [] }
                    )
                }
            }
            .alert(L.comingSoon, isPresented: $showsComingSoon) {
                Button(L.ok, role: .cancel) {}
            }
        }
        .fullScreenCover(item: $route) { route in
            if let step = library.step(id: route.stepID) {
                SessionView(
                    initialStep: step,
                    onClose: { self.route = nil },
                    onBackToList: {
                        path = []
                        self.route = nil
                    }
                )
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
        }
        #endif
    }

    // MARK: - 장면 상태

    /// 장면 1은 처음부터 열려 있고, 그 뒤 장면은 앞 장면의 두 단계를 끝내면 열린다.
    private func status(_ scene: TripScene) -> SceneRowStatus {
        if store.isSceneCompleted(scene) { return .completed }
        return store.isSceneUnlocked(scene) ? .open : .locked
    }

    /// 아래 주 버튼이 시작할 장면과 단계. 열린 장면의 내용이 아직 없으면 버튼을 숨긴다.
    private var nextTarget: (scene: TripScene, step: TripStep)? {
        guard let scene = library.scenes.first(where: { status($0) == .open }),
              scene.hasContent,
              let step = store.nextStep(in: scene)
        else { return nil }
        return (scene, step)
    }

    // MARK: - 장면 행 (scene-flow.md 5번, scene-art/brief.md 2번)

    @ViewBuilder
    private func row(_ scene: TripScene) -> some View {
        let status = status(scene)
        let done = store.completedStepCount(scene)
        Button {
            if scene.hasContent {
                path.append(scene.id)
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
                        .foregroundStyle(status == .locked ? .secondary : .primary)
                        .lineLimit(1)
                    stepKanaLine(scene)
                        .foregroundStyle(status == .locked ? .secondary : .primary)
                }

                Spacer(minLength: 0)

                if status != .locked {
                    Text(status == .completed ? L.done : "\(done)/\(scene.steps.count)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
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
                : L.sceneRowLabel(order: scene.order, name: scene.name, steps: scene.steps.map { ($0.name, $0.kana) }, done: done)
        )
        .accessibilityAddTraits(status == .locked ? [] : .isButton)
    }

    /// 새 글자를 단계별로 나눠 놓는다: "す し · い か た こ". 글자 20pt, 가운뎃점 좌우 8pt.
    private func stepKanaLine(_ scene: TripScene) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(scene.steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    Text("·").font(.system(size: 20)).foregroundStyle(.secondary)
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
    /// 외곽선 색. visual-rules의 `Outline`(라이트 #4A2219, 다크 #8C7366). 이 브랜치에는 색 에셋이 없어 코드에 둔다.
    private static let outline = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x8C / 255, green: 0x73 / 255, blue: 0x66 / 255, alpha: 1)
            : UIColor(red: 0x4A / 255, green: 0x22 / 255, blue: 0x19 / 255, alpha: 1)
    })

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
                        RoundedRectangle(cornerRadius: 12).strokeBorder(Self.outline, lineWidth: 2)
                    }
                if let badge {
                    Image(systemName: badge.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(badge.color)
                        .frame(width: Self.badge, height: Self.badge)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
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
        case .locked: ("lock.fill", .secondary)
        case .completed: ("checkmark.circle.fill", .green)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .locked:
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
        case .open:
            Image(systemName: scene.icon ?? "lock.open.fill").foregroundStyle(Color.accentColor)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }
}
