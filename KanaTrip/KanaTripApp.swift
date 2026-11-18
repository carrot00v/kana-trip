import SwiftUI

@main
struct KanaTripApp: App {
    @State private var store = KanaTripApp.makeStore()

    init() {
        AppStyle.configureNavigationBar()
    }

    private static func makeStore() -> ProgressStore {
        #if DEBUG
        if let n = MapDebug.completedCount { return MapDebugProgress.store(completed: n) }
        #endif
        return ProgressStore()
    }

    var body: some Scene {
        WindowGroup {
            ScreenClassReader {
                #if DEBUG
                if let index = DebugLaunch.wordIndex {
                    DebugWordPreview(index: index).appStyle()
                } else if let canvas = MapDebug.canvas {
                    // 작은 화면 확인: 상태 바 20pt를 흉내 낸 띠 아래에 W×H 틀로 그린다.
                    VStack(spacing: 0) {
                        Color.black.frame(height: 20)
                        HomeView()
                            .environment(store)
                            .appStyle()
                            .environment(\.isSmallScreen, canvas.height < ScreenClassReader<EmptyView>.smallScreenHeight)
                    }
                    .frame(width: canvas.width, height: canvas.height)
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.4))
                } else {
                    HomeView()
                        .environment(store)
                        .appStyle()
                }
                #else
                HomeView()
                    .environment(store)
                    .appStyle()
                #endif
            }
        }
    }
}

#if DEBUG
/// `-mapDebugCompleted N`: 앞에서부터 N개 세션을 끝낸 진도를 메모리에만 만든다(저장 파일을 건드리지 않음).
enum MapDebugProgress {
    private final class MemoryStorage: ProgressStorage {
        private var state: ProgressState?
        func load() -> ProgressState? { state }
        func save(_ state: ProgressState) { self.state = state }
    }

    static func store(completed n: Int) -> ProgressStore {
        let store = ProgressStore(storage: MemoryStorage())
        for session in ContentLibrary.shared.sessions.prefix(max(0, n)) {
            _ = SessionRun(session: session, store: store).complete()
        }
        return store
    }
}
#endif
