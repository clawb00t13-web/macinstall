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
            .onChange(of: authService.session == nil) { isSignedOut in
                if isSignedOut {
                    store.stopSyncPolling()
                } else {
                    // Immediately pull cloud state on sign-in instead of waiting 30s
                    store.startSyncPolling()
                    Task {
                        await store.loadFromCloud(
                            accessToken: authService.session!.accessToken,
                            userId: authService.session!.userId
                        )
                        await store.detectInstalled()
                    }
                }
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
