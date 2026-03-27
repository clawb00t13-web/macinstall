import SwiftUI

@main
struct MacInstallApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        MenuBarExtra("MacInstall", systemImage: "square.and.arrow.down") {
            MenuBarView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Window("MacInstall", id: "main") {
            ContentView()
                .environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
    }
}
