import SwiftUI

/// H 홈(장면 목록).
struct HomeView: View {
    @Environment(ProgressStore.self) private var store
    @State private var path: [String] = []
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
                    ForEach(library.scenes) { scene in
                        row(scene)
                            .listRowBackground(Color.cardBackground)
                    }
                } header: {
                    sectionHeader
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
                            session: target.kind,
                            resume: store.isInProgress(target.kind, sceneID: target.scene.id)
                        )
                    ) {
                        // 세션을 닫으면 장면 진입이 아래에 깔려 있도록 먼저 push한다.
                        path = [target.scene.id]
                        route = SessionRoute(sceneID: target.scene.id, kind: target.kind)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .navigationDestination(for: String.self) { sceneID in
                if let scene = library.scene(id: sceneID) {
                    SceneDetailView(
                        scene: scene,
                        onStart: { route = SessionRoute(sceneID: scene.id, kind: $0) },
                        onBackToList: { path = [] }
                    )
                }
            }
            .alert(L.comingSoon, isPresented: $showsComingSoon) {
                Button(L.ok, role: .cancel) {}
            }
        }
        .fullScreenCover(item: $route) { route in
            if let scene = library.scene(id: route.sceneID) {
                SessionView(
                    scene: scene,
                    initialKind: route.kind,
                    onClose: { self.route = nil },
                    onBackToList: {
                        path = []
                        self.route = nil
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

    // MARK: - 섹션 머리글

    /// "히라가나" 머리글과 기본 표정 캐릭터(64pt). 둘의 아래 끝을 맞춘다.
    /// 접근성 글자 크기에서는 캐릭터를 숨기고 기본 높이로 둔다 (visual-rules.md 7.2, 8.1).
    private var sectionHeader: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(library.sectionTitle)
                .foregroundStyle(Color.inkSecondary)
            Spacer(minLength: 0)
            if !typeSize.isAccessibilitySize {
                Image("OnigiriDefault")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                    .padding(.vertical, 4)
            }
        }
        .textCase(nil)
    }

    // MARK: - 장면 상태

    private enum SceneStatus {
        case locked, open, completed
    }

    /// 장면 1은 처음부터 열려 있고, 그 뒤 장면은 앞 장면을 끝내면 열린다.
    private func status(_ scene: TripScene) -> SceneStatus {
        if store.isSceneCompleted(sceneID: scene.id) { return .completed }
        guard let previous = library.scene(before: scene) else { return .open }
        return store.isSceneCompleted(sceneID: previous.id) ? .open : .locked
    }

    /// 아래 주 버튼이 시작할 장면과 세션. 열린 장면의 내용이 아직 없으면 버튼을 숨긴다.
    private var nextTarget: (scene: TripScene, kind: SessionKind)? {
        guard let scene = library.scenes.first(where: { status($0) == .open }),
              scene.hasContent,
              let kind = store.nextSession(sceneID: scene.id)
        else { return nil }
        return (scene, kind)
    }

    // MARK: - 장면 행

    @ViewBuilder
    private func row(_ scene: TripScene) -> some View {
        let status = status(scene)
        Button {
            if scene.hasContent {
                path.append(scene.id)
            } else {
                showsComingSoon = true
            }
        } label: {
            HStack(spacing: 12) {
                statusIcon(scene, status: status)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(scene.order)  \(scene.name)")
                        .font(.headline)
                        .foregroundStyle(status == .locked ? Color.inkSecondary : Color.ink)
                    Text(KanaText.japanese(scene.kana.joined(separator: " ")))
                        .font(.title3)
                        .foregroundStyle(status == .locked ? Color.inkSecondary : Color.ink)
                        .environment(\.locale, Locale(identifier: "ja"))
                }

                Spacer()

                if status != .locked {
                    Text(status == .completed ? L.done : "\(store.completedCount(sceneID: scene.id))/\(SessionKind.allCases.count)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Color.inkSecondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(status == .locked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            status == .locked
                ? L.sceneRowLocked(order: scene.order, name: scene.name)
                : L.sceneRowLabel(order: scene.order, name: scene.name, kana: scene.kana, done: store.completedCount(sceneID: scene.id))
        )
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func statusIcon(_ scene: TripScene, status: SceneStatus) -> some View {
        switch status {
        case .locked:
            Image(systemName: "lock.fill").foregroundStyle(Color.inkSecondary)
        case .open:
            // 장면 아이콘이 아직 정해지지 않은 장면은 열린 자물쇠로 대신한다.
            Image(systemName: scene.icon ?? "lock.open.fill").foregroundStyle(Color.accent)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.correct)
        }
    }
}
