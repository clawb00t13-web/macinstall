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
    @Published var customPacks: [StarterPack] = []
    @Published var appliedPackId: String? = nil
    var authService: AuthService? = nil

    private var syncTask: Task<Void, Never>?

    init() {
        let defaultPath = (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
            .appendingPathComponent(".macinstall/profile.yaml")
        profilePath = defaultPath
        loadCatalog()
        loadProfile()
        Task { await detectInstalled() }
        startSyncPolling()
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
        profile = parseYAML(content)
    }

    func saveProfile() {
        let yaml = buildYAML()
        let url = URL(fileURLWithPath: profilePath)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? yaml.write(to: url, atomically: true, encoding: .utf8)

        // Always sync to cloud when signed in — not just when cloudSyncEnabled
        if let session = authService?.session {
            Task { try? await SupabaseService().upsertProfile(
                accessToken: session.accessToken, userId: session.userId, yaml: yaml
            )}
        }
    }

    func loadFromCloud(accessToken: String, userId: String) async {
        let yaml = (try? await SupabaseService().fetchProfile(accessToken: accessToken)) ?? ""
        if !yaml.isEmpty {
            profile = parseYAML(yaml)
        }
        customPacks = (try? await SupabaseService().fetchCustomPacks(accessToken: accessToken)) ?? []
        appliedPackId = try? await SupabaseService().fetchAppliedPackId(accessToken: accessToken)
    }

    private func buildYAML() -> String {
        var lines = ["version: 1", "apps:"]
        for app in apps where profile[app.id] == true {
            lines.append("  - id: \(app.id)")
            lines.append("    enabled: true")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func parseYAML(_ content: String) -> [String: Bool] {
        var result: [String: Bool] = [:]
        var currentId: String? = nil
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- id:") {
                currentId = trimmed.replacingOccurrences(of: "- id:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("enabled:"), let id = currentId {
                let val = trimmed.replacingOccurrences(of: "enabled:", with: "").trimmingCharacters(in: .whitespaces)
                result[id] = (val == "true")
                currentId = nil
            }
        }
        return result
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

        for app in apps {
            installStatus[app.id] = checkAppInstalled(app)
        }

        await syncInstalledToCloud()
        await checkAndProcessUninstallQueue()
    }

    private func checkAppInstalled(_ app: CatalogApp) -> InstallStatus {
        let appName = app.name
        let appPath = "/Applications/\(appName).app"
        let homeApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/\(appName).app").path

        if FileManager.default.fileExists(atPath: appPath) ||
           FileManager.default.fileExists(atPath: homeApps) {
            return .installed
        }
        return .notInstalled
    }

    private func syncInstalledToCloud() async {
        guard let session = authService?.session else { return }
        let installedIds = installStatus.compactMap { id, status in status == .installed ? id : nil }
        try? await SupabaseService().upsertInstalledApps(
            accessToken: session.accessToken,
            userId: session.userId,
            appIds: installedIds
        )
    }

    // MARK: - Cloud Sync Polling

    func startSyncPolling() {
        syncTask?.cancel()
        syncTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                guard !Task.isCancelled else { break }
                await pollCloudSync()
            }
        }
    }

    func stopSyncPolling() {
        syncTask?.cancel()
        syncTask = nil
    }

    private func pollCloudSync() async {
        guard let session = authService?.session else { return }

        // Pull latest profile from cloud
        if let cloudYaml = try? await SupabaseService().fetchProfile(accessToken: session.accessToken),
           !cloudYaml.isEmpty {
            let cloudProfile = parseYAML(cloudYaml)
            if cloudProfile != profile {
                print("[Sync] profile changed — updating local (\(cloudProfile.count) apps)")
                let oldProfile = profile
                profile = cloudProfile
                // Persist locally so it survives restarts
                let url = URL(fileURLWithPath: profilePath)
                try? cloudYaml.write(to: url, atomically: true, encoding: .utf8)
                // Auto-install apps newly enabled from the web
                let toInstall = apps.filter {
                    cloudProfile[$0.id] == true &&
                    oldProfile[$0.id] != true &&
                    installStatus[$0.id] == .notInstalled
                }
                if !toInstall.isEmpty {
                    await installApps(toInstall)
                }
            }
        }

        await checkAndProcessUninstallQueue()

        // Sync custom packs
        if let fetched = try? await SupabaseService().fetchCustomPacks(accessToken: session.accessToken) {
            if fetched.map(\.id) != customPacks.map(\.id) {
                customPacks = fetched
            }
        }

        // Sync applied pack ID
        if let cloudPackId = try? await SupabaseService().fetchAppliedPackId(accessToken: session.accessToken) {
            if cloudPackId != appliedPackId {
                appliedPackId = cloudPackId
            }
        }

    }

    // MARK: - Uninstall

    func uninstallApp(_ app: CatalogApp) async {
        if let cask = app.brewCask {
            _ = await runCommand(brewPath, args: ["uninstall", "--cask", cask])
        } else if let masId = app.masId {
            _ = await runCommand(masPath, args: ["uninstall", "\(masId)"])
        } else {
            let fm = FileManager.default
            let appPath = URL(fileURLWithPath: "/Applications/\(app.name).app")
            let homeAppPath = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/\(app.name).app")
            if fm.fileExists(atPath: appPath.path) {
                try? fm.trashItem(at: appPath, resultingItemURL: nil)
            } else if fm.fileExists(atPath: homeAppPath.path) {
                try? fm.trashItem(at: homeAppPath, resultingItemURL: nil)
            }
        }
        await detectInstalled()
    }

    func checkAndProcessUninstallQueue() async {
        guard let session = authService?.session else { return }
        let queue = (try? await SupabaseService().fetchUninstallQueue(accessToken: session.accessToken)) ?? []
        guard !queue.isEmpty else { return }
        // Clear first — prevents re-entry if detectInstalled() triggers this again mid-uninstall
        try? await SupabaseService().clearUninstallQueue(
            accessToken: session.accessToken,
            userId: session.userId
        )
        print("[Sync] uninstall queue: \(queue.joined(separator: ", "))")
        for id in queue {
            if let app = apps.first(where: { $0.id == id }) {
                await uninstallApp(app)
            }
        }
    }

    // MARK: - Install

    func installMissing() {
        isInstalling = true
        Task {
            defer { isInstalling = false }
            let toInstall = apps.filter { profile[$0.id] == true && installStatus[$0.id] == .notInstalled }
            await installApps(toInstall)
        }
    }

    private func installApps(_ appsToInstall: [CatalogApp]) async {
        for app in appsToInstall {
            installStatus[app.id] = .installing
            if let cask = app.brewCask {
                _ = await runCommand(brewPath, args: ["install", "--cask", cask])
                if checkAppInstalled(app) == .notInstalled {
                    _ = await runCommand(brewPath, args: ["reinstall", "--cask", cask])
                }
            } else if let masId = app.masId {
                _ = await runCommand(masPath, args: ["install", "\(masId)"])
            }
            installStatus[app.id] = checkAppInstalled(app)
        }
        await syncInstalledToCloud()
    }

    // MARK: - Starter Packs

    func createCustomPack(name: String, icon: String, description: String, appIds: [String]) {
        var pack = StarterPack(id: UUID().uuidString, name: name, description: description, icon: icon, appIds: appIds)
        pack.isCustom = true
        customPacks.insert(pack, at: 0)
        saveCustomPacksToCloud()
    }

    func deleteCustomPack(id: String) {
        customPacks.removeAll { $0.id == id }
        saveCustomPacksToCloud()
    }

    private func saveCustomPacksToCloud() {
        guard let session = authService?.session else { return }
        let packs = customPacks
        Task {
            try? await SupabaseService().upsertCustomPacks(
                accessToken: session.accessToken,
                userId: session.userId,
                packs: packs
            )
        }
    }

    func applyStarterPack(appIds: [String], packId: String) {
        appliedPackId = packId
        profile = [:]
        for id in appIds {
            profile[id] = true
        }
        saveProfile()
        if let session = authService?.session {
            Task { try? await SupabaseService().upsertAppliedPackId(
                accessToken: session.accessToken, userId: session.userId, packId: packId
            )}
        }
    }

    // MARK: - Helpers

    private var brewPath: String {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/brew"
    }

    private var masPath: String {
        ["/opt/homebrew/bin/mas", "/usr/local/bin/mas"]
            .first { FileManager.default.fileExists(atPath: $0) } ?? "/usr/local/bin/mas"
    }

    @discardableResult
    private func runCommand(_ path: String, args: [String]) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = args
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
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
