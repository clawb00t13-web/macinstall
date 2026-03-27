import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            AppListView()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2")
                }
                .tag(0)

            StarterPacksView()
                .tabItem {
                    Label("Starter Packs", systemImage: "wand.and.stars")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .frame(minWidth: 800, minHeight: 520)
    }
}

struct MenuBarView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("MacInstall")
                            .font(.headline)
                        Text("\(store.installedCount) apps installed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Divider()

            if !store.missingEnabledApps.isEmpty {
                Button {
                    store.installMissing()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                            .foregroundStyle(.orange)
                        Text("Install \(store.missingEnabledApps.count) missing apps")
                            .font(.callout)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Divider()
            }

            Button {
                Task { await store.detectInstalled() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Detect Installed Apps")
                        .font(.callout)
                    Spacer()
                    if store.isDetecting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .disabled(store.isDetecting)

            Divider()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit MacInstall")
                        .font(.callout)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 280)
    }
}
