import Foundation
import SwiftUI

enum InstallStatus {
    case installed
    case notInstalled
    case installing
    case unknown
}

@MainActor
class AppStore: ObservableObject {
    @Published var apps: [CatalogApp] = []
    @Published var profile: [String: Bool] = [:]
    @Published var installStatus: [String: InstallStatus] = [:]
    @Published var searchQuery = ""
    @Published var selectedCategory = "all"
    @Published var profilePath: String = ""
    @Published var cloudSyncEnabled: Bool = false
    @Published var isDetecting: Bool = false
    @Published var isInstalling: Bool = false

    var authService: AuthService? = nil

    private var brewInstalledCasks: Set<String> = []

    init() {
        let defaultPath = (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
            .appendingPathComponent(".macinstall/profile.yaml")
        profilePath = defaultPath
        loadCatalog()
        loadProfile()
        Task {
            await detectInstalled()
        }
    }

    func loadCatalog() {
        apps = allApps
        for app in apps where installStatus[app.id] == nil {
            installStatus[app.id] = .unknown
        }
    }

    var filteredApps: [CatalogApp] {
        apps.filter { app in
            let matchesCategory = selectedCategory == "all" || app.categories.contains(selectedCategory)
            let matchesSearch = searchQuery.isEmpty ||
                app.name.localizedCaseInsensitiveContains(searchQuery) ||
                app.id.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesSearch
        }
    }

    // MARK: - Profile

    func loadProfile() {
        let url = URL(fileURLWithPath: profilePath)
        guard let content = try? String(contentsOf: url) else { return }
        parseYAML(content)
    }

    func saveProfile() {
        let url = URL(fileURLWithPath: profilePath)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var lines = ["version: 1", "apps:"]
        for app in apps where profile[app.id] == true {
            lines.append("  - id: \(app.id)")
            lines.append("    enabled: true")
        }
        let yaml = lines.joined(separator: "\n") + "\n"
        try? yaml.write(to: url, atomically: true, encoding: .utf8)

        if cloudSyncEnabled, let session = authService?.session {
            Task { try? await SupabaseService().upsertProfile(accessToken: session.accessToken, userId: session.userId, yaml: yaml) }
        }
    }

    func loadFromCloud(accessToken: String, userId: String) async {
        let yaml = (try? await SupabaseService().fetchProfile(accessToken: accessToken)) ?? ""
        guard !yaml.isEmpty else { return }
        parseYAML(yaml)
    }

    private func parseYAML(_ content: String) {
        var result: [String: Bool] = [:]
        let lines = content.components(separatedBy: "\n")
        var currentId: String? = nil
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- id:") {
                currentId = trimmed.replacingOccurrences(of: "- id:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("enabled:"), let id = currentId {
                let val = trimmed.replacingOccurrences(of: "enabled:", with: "").trimmingCharacters(in: .whitespaces)
                result[id] = (val == "true")
                currentId = nil
            }
        }
        profile = result
    }

    func toggleApp(_ id: String) {
        let currentDefault = installStatus[id] == .installed
        profile[id] = !(profile[id] ?? currentDefault)
        saveProfile()
    }

    // MARK: - Detection

    func detectInstalled() async {
        isDetecting = true
        defer { isDetecting = false }

        // Get brew list once
        let brewOutput = await runCommand("/opt/homebrew/bin/brew", args: ["list", "--cask"])
        let brewInstalled = Set(brewOutput.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })

        for app in apps {
            let status = await checkAppInstalled(app, brewInstalled: brewInstalled)
            installStatus[app.id] = status
        }

        // Sync installed app IDs to cloud so the website can reflect them
        if let session = authService?.session {
            let installedIds = installStatus.compactMap { id, status in
                status == .installed ? id : nil
            }
            Task { try? await SupabaseService().upsertInstalledApps(
                accessToken: session.accessToken,
                userId: session.userId,
                appIds: installedIds
            )}
        }
    }

    private func checkAppInstalled(_ app: CatalogApp, brewInstalled: Set<String>) async -> InstallStatus {
        let appName = app.name
        let appPath = "/Applications/\(appName).app"
        let homeApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/\(appName).app").path

        // Check /Applications and ~/Applications
        if FileManager.default.fileExists(atPath: appPath) ||
           FileManager.default.fileExists(atPath: homeApps) {
            return .installed
        }

        // Brew lists it — but .app is missing from disk.
        // Double-check with brew info --cask --json to see if it's truly installed
        // (could be in a non-standard location) or was manually deleted.
        if let cask = app.brewCask, brewInstalled.contains(cask) {
            let json = await runCommand("/opt/homebrew/bin/brew", args: ["info", "--cask", cask, "--json"])
            // An installed cask has a non-empty "installed" array; uninstalled shows "installed":[]
            let isReallyInstalled = json.contains("\"installed\":[{") || json.contains("\"installed\": [{")
            return isReallyInstalled ? .installed : .notInstalled
        }

        return .notInstalled
    }

    // MARK: - Install

    func installMissing() {
        isInstalling = true
        Task {
            defer { isInstalling = false }
            let enabledApps = apps.filter { profile[$0.id] == true && installStatus[$0.id] == .notInstalled }

            for app in enabledApps {
                installStatus[app.id] = .installing
                if let cask = app.brewCask {
                    _ = await runCommand("/opt/homebrew/bin/brew", args: ["install", "--cask", cask])
                    let brewOutput = await runCommand("/opt/homebrew/bin/brew", args: ["list", "--cask"])
                    let brewInstalled = Set(brewOutput.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
                    installStatus[app.id] = brewInstalled.contains(cask) ? .installed : .notInstalled
                } else if let masId = app.masId {
                    _ = await runCommand("/usr/local/bin/mas", args: ["install", "\(masId)"])
                    installStatus[app.id] = .installed
                } else {
                    installStatus[app.id] = .notInstalled
                }
            }
        }
    }

    // MARK: - Starter Packs

    func applyStarterPack(_ pack: StarterPack) {
        profile = [:]
        for id in pack.appIds {
            profile[id] = true
        }
        saveProfile()
    }

    // MARK: - Helpers

    private func runCommand(_ path: String, args: [String]) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = args
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    // MARK: - Computed helpers

    var missingEnabledApps: [CatalogApp] {
        apps.filter { profile[$0.id] == true && installStatus[$0.id] == .notInstalled }
    }

    var installedCount: Int {
        installStatus.values.filter { $0 == .installed }.count
    }
}
