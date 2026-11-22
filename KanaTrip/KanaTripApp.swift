import SwiftUI

@main
struct KanaTripApp: App {
    @State private var store = KanaTripApp.makeStore()

    init() {
        AppStyle.configureNavigationBar()
    }

    private static func makeStore() -> ProgressStore {
        let store = makeProgressStore()
        // 스킨은 저장된 착용 상태에서 나온다 (app-skin.md 8.2).
        SkinStore.shared.progress = store
        return store
    }

    private static func makeProgressStore() -> ProgressStore {
        #if DEBUG
        if let n = MapDebug.completedCount {
            let store = MapDebugProgress.store(completed: n)
            // 메모리 진도에서는 스킨 아이템을 가진 채 입힌다. 꾸미기 화면에서 다른 칸을 눌러 볼 수 있다.
            if let id = SkinDebug.skinID, let itemID = SkinCatalog.shared.skin(idOrItemID: id)?.itemID {
                store.debugOwnAndEquip(itemID)
            }
            return store
        }
        if let id = SkinDebug.skinID { SkinStore.shared.debugSkinID = id }
        #endif
        return ProgressStore()
    }

    var body: some Scene {
        WindowGroup {
            ScreenClassReader {
                #if DEBUG
                if let index = DebugLaunch.wordIndex {
                    DebugWordPreview(index: index).appStyle()
                } else if DebugGiri.enabled {
                    DebugGiriPreview().appStyle()
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
