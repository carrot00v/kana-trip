import SwiftUI

@main
struct KanaTripApp: App {
    @State private var store = ProgressStore()

    init() {
        AppStyle.configureNavigationBar()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .appStyle()
        }
    }
}
