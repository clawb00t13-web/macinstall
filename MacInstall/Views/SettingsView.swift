import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mackup: MackupService
    @State private var showProfilePathEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 16)

                profileSection
                cloudSyncSection
                mackupSection
                aboutSection

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Profile", systemImage: "person.crop.circle")
                    .font(.headline)

                LabeledContent {
                    HStack(spacing: 8) {
                        TextField("Path to profile.yaml", text: $store.profilePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                        Button("Reset") {
                            let defaultPath = (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
                                .appendingPathComponent(".macinstall/profile.yaml")
                            store.profilePath = defaultPath
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } label: {
                    Text("Profile Path")
                        .font(.callout)
                }

                HStack(spacing: 8) {
                    Button {
                        store.ensureProfileFileExists()
                        CLIRunner.openInEditor(store.profilePath)
                    } label: {
                        Label("Open Profile in Editor", systemImage: "square.and.pencil")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        store.saveProfile()
                    } label: {
                        Label("Save Profile", systemImage: "square.and.arrow.down")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(8)
        }
    }

    // MARK: - Cloud Sync

    private var cloudSyncSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Sync", systemImage: "icloud")
                    .font(.headline)

                Toggle(isOn: $store.cloudSyncEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cloud Sync")
                            .font(.callout)
                        Text("Sync your profile across machines via iCloud Drive.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.cloudSyncEnabled {
                    warningBanner(
                        icon: "info.circle",
                        text: "Cloud sync is not yet functional. This is a placeholder feature."
                    )
                }
            }
            .padding(8)
        }
    }

    // MARK: - Mackup Config Sync

    private var mackupSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("App Config Sync", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)

                Text("Sync app configs (Rectangle, iTerm2, VS Code, etc.) between Macs via Mackup + Supabase.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !mackup.isInstalled {
                    warningBanner(
                        icon: "exclamationmark.triangle",
                        text: "Mackup not installed. Run: brew install mackup"
                    )
                } else if authService.session == nil {
                    warningBanner(
                        icon: "person.crop.circle.badge.exclamationmark",
                        text: "Sign in to sync configs between Macs."
                    )
                } else {
                    mackupActions
                }
            }
            .padding(8)
        }
    }

    private var mackupActions: some View {
        let installedIds = store.installStatus
            .filter { $0.value == .installed }
            .map(\.key)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    Task {
                        guard let s = await authService.validSession() else { return }
                        await mackup.backupToSupabase(accessToken: s.accessToken, userId: s.userId, installedApps: installedIds)
                    }
                } label: {
                    Label("Backup Configs", systemImage: "arrow.up.circle")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(mackup.isRunning)

                Button {
                    Task {
                        guard let s = await authService.validSession() else { return }
                        await mackup.restoreFromSupabase(accessToken: s.accessToken, userId: s.userId, installedApps: installedIds)
                    }
                } label: {
                    Label("Restore Configs", systemImage: "arrow.down.circle")
                        .font(.callout)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(mackup.isRunning)

                if mackup.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let error = mackup.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let msg = mackup.statusMessage, mackup.errorMessage == nil {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("About", systemImage: "info.circle")
                    .font(.headline)

                LabeledContent("MacInstall", value: "macOS App Manager")
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Apps in catalog", value: "\(allApps.count)")
                LabeledContent("Installed apps", value: "\(store.installedCount)")
            }
            .font(.callout)
            .padding(8)
        }
    }

    // MARK: - Shared Components

    private func warningBanner(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
