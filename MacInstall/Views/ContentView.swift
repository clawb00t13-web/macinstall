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
    @EnvironmentObject var authService: AuthService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // User identity bar
            if let session = authService.session {
                HStack(spacing: 8) {
                    UserAvatarView(url: session.avatarURL)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.fullName ?? "Signed in")
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Text("Synced to cloud")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        authService.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Sign out")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
            }

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

// MARK: - User Avatar

private struct UserAvatarView: View {
    let url: String?

    var body: some View {
        Group {
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private var placeholderIcon: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .foregroundStyle(.secondary)
    }
}
