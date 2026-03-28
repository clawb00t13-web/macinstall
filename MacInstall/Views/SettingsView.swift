import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var authService: AuthService
    @StateObject private var mackup = MackupService()
    @State private var showProfilePathEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)

                // Profile section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Profile", systemImage: "person.crop.circle")
                            .font(.headline)
                            .padding(.bottom, 4)

                        HStack(spacing: 8) {
                            Text("Profile Path")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
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

                        HStack(spacing: 8) {
                            Spacer().frame(width: 108)
                            Button {
                                let url = URL(fileURLWithPath: store.profilePath)
                                let dir = url.deletingLastPathComponent()
                                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                                if !FileManager.default.fileExists(atPath: store.profilePath) {
                                    try? "version: 1\napps: []\n".write(toFile: store.profilePath, atomically: true, encoding: .utf8)
                                }
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
                    .padding(4)
                }

                // Cloud Sync section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Sync", systemImage: "icloud")
                            .font(.headline)
                            .padding(.bottom, 4)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cloud Sync")
                                    .font(.callout)
                                Text("Sync your profile across machines via iCloud Drive.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $store.cloudSyncEnabled)
                                .labelsHidden()
                        }

                        if store.cloudSyncEnabled {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.orange)
                                Text("Cloud sync is not yet functional. This is a placeholder feature.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(4)
                }

                // Mackup Config Sync section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("App Config Sync", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline)
                            .padding(.bottom, 4)

                        Text("Sync app configs (Rectangle, iTerm2, VS Code, etc.) between Macs via Mackup + Supabase.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !mackup.isInstalled {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                Text("Mackup not installed. Run: brew install mackup")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else if authService.session == nil {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle.badge.exclamationmark")
                                    .foregroundStyle(.orange)
                                Text("Sign in to sync configs between Macs.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            let installedIds = store.installStatus
                                .filter { $0.value == .installed }
                                .map(\.key)

                            HStack(spacing: 12) {
                                Button {
                                    guard let s = authService.session else { return }
                                    Task { await mackup.backupToSupabase(accessToken: s.accessToken, userId: s.userId, installedAppIds: installedIds) }
                                } label: {
                                    Label("Backup Configs", systemImage: "arrow.up.circle")
                                        .font(.callout)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(mackup.isRunning)

                                Button {
                                    guard let s = authService.session else { return }
                                    Task { await mackup.restoreFromSupabase(accessToken: s.accessToken, userId: s.userId, installedAppIds: installedIds) }
                                } label: {
                                    Label("Restore Configs", systemImage: "arrow.down.circle")
                                        .font(.callout)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(mackup.isRunning)

                                if mackup.isRunning {
                                    ProgressView()
                                        .scaleEffect(0.7)
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
                    .padding(4)
                }

                // App Info section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About", systemImage: "info.circle")
                            .font(.headline)
                            .padding(.bottom, 4)

                        HStack {
                            Text("MacInstall")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
                            Text("macOS App Manager")
                                .font(.callout)
                        }

                        HStack {
                            Text("Version")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
                            Text("1.0.0")
                                .font(.callout)
                        }

                        HStack {
                            Text("Apps in catalog")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
                            Text("\(allApps.count)")
                                .font(.callout)
                        }

                        HStack {
                            Text("Installed apps")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
                            Text("\(store.installedCount)")
                                .font(.callout)
                        }
                    }
                    .padding(4)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
