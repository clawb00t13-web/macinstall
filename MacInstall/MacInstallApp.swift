import SwiftUI

@main
struct MacInstallApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var authService = AuthService()

    var body: some Scene {
        MenuBarExtra("MacInstall", systemImage: "square.and.arrow.down") {
            Group {
                if authService.session == nil {
                    AuthView()
                        .environmentObject(authService)
                } else {
                    MenuBarView()
                        .environmentObject(store)
                        .environmentObject(authService)
                }
            }
            .task {
                authService.restoreSession()
                store.authService = authService
            }
        }
        .menuBarExtraStyle(.window)

        Window("MacInstall", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(authService)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
    }
}
