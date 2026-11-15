import SwiftUI

@main
struct KanaTripApp: App {
    @State private var store = ProgressStore()

    init() {
        AppStyle.configureNavigationBar()
    }

    var body: some Scene {
        WindowGroup {
            ScreenClassReader {
                #if DEBUG
                if let index = DebugLaunch.wordIndex {
                    DebugWordPreview(index: index).appStyle()
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
