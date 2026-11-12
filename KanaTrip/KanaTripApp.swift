import SwiftUI

@main
struct KanaTripApp: App {
    @State private var store = ProgressStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
        }
    }
}
