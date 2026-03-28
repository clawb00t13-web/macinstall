import Foundation

/// Mackup + Supabase config sync.
///
/// Flow:
/// 1. Configures Mackup with `file_system` engine → `~/.macinstall/mackup-staging/`
///    and `[applications_to_sync]` filtered to only installed catalog apps.
/// 2. `mackup backup` copies only those configs into staging dir
/// 3. tar.gz → base64 → Supabase TEXT column
/// 4. On restore: download → untar → `mackup restore`
@MainActor
class MackupService: ObservableObject {
    @Published var isRunning = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let stagingDir: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent(".macinstall/mackup-staging")
    }()

    private let archivePath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent(".macinstall/mackup-backup.tar.gz")
    }()

    private let mackupCfgPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent(".mackup.cfg")
    }()

    private var mackupPath: String? {
        ["/opt/homebrew/bin/mackup", "/usr/local/bin/mackup"]
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    var isInstalled: Bool { mackupPath != nil }

    /// Maps MacInstall catalog app IDs → Mackup app names.
    /// Only apps that Mackup knows about are listed here.
    private static let catalogToMackup: [String: String] = [
        "visual-studio-code": "vscode",
        "cursor":             "cursor",
        "iterm2":             "iterm2",
        "warp":               "warp",
        "git":                "git",
        "rectangle":          "rectangle",
        "sublime":            "sublime-text",
        "bettertouchtool":    "bettertouchtool",
        "spotify":            "spotify",
        "vlc":                "vlc",
        "zoom":               "zoom",
        "docker":             "docker",
        "brave":              "brave",
        "telegram":           "telegram_macos",
        "whatsapp":           "whatsapp",
    ]

    /// Plist files in staging dir that need `defaults import` instead of symlinks.
    /// Maps relative path inside staging → defaults domain.
    private static let plistDomains: [String: String] = [
        "Mackup/Library/Preferences/com.knollsoft.Rectangle.plist": "com.knollsoft.Rectangle",
        "Mackup/Library/Preferences/com.googlecode.iterm2.plist":   "com.googlecode.iterm2",
    ]

    // MARK: - Public API

    /// Backup configs for installed catalog apps → tar.gz → Supabase.
    /// `installedAppIds` should be the IDs of apps with `.installed` status.
    func backupToSupabase(accessToken: String, userId: String, installedAppIds: [String]) async {
        isRunning = true
        errorMessage = nil

        let mackupApps = installedAppIds.compactMap { Self.catalogToMackup[$0] }
        if mackupApps.isEmpty {
            statusMessage = "No installed apps have Mackup support"
            isRunning = false
            return
        }

        statusMessage = "Configuring Mackup for \(mackupApps.count) apps..."
        cleanStagingDir()
        writeMackupConfig(apps: mackupApps)

        statusMessage = "Running mackup backup..."
        guard await runMackup(args: ["backup", "--force"]) else {
            isRunning = false
            return
        }

        statusMessage = "Compressing..."
        guard await compressStagingDir() else {
            errorMessage = "Failed to compress configs"
            isRunning = false
            return
        }

        guard let archiveData = try? Data(contentsOf: URL(fileURLWithPath: archivePath)) else {
            errorMessage = "Failed to read archive"
            isRunning = false
            return
        }

        let sizeMB = String(format: "%.1f", Double(archiveData.count) / 1_000_000)
        statusMessage = "Uploading \(sizeMB) MB (\(mackupApps.count) apps)..."

        do {
            try await SupabaseService().upsertMackupBackup(
                accessToken: accessToken, userId: userId,
                archive: archiveData.base64EncodedString()
            )
            let appNames = mackupApps.joined(separator: ", ")
            statusMessage = "Backed up: \(appNames)"
            print("[Mackup] Uploaded \(mackupApps.count) apps (\(sizeMB) MB) to Supabase: \(appNames)")
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
        isRunning = false
    }

    /// Restore configs from Supabase → untar → mackup restore.
    func restoreFromSupabase(accessToken: String, userId: String, installedAppIds: [String]) async {
        isRunning = true
        errorMessage = nil
        statusMessage = "Downloading from Supabase..."

        let mackupApps = installedAppIds.compactMap { Self.catalogToMackup[$0] }
        writeMackupConfig(apps: mackupApps)

        do {
            let b64 = try await SupabaseService().fetchMackupBackup(accessToken: accessToken)
            if b64.isEmpty {
                errorMessage = "No backup found in Supabase"
                isRunning = false
                return
            }

            guard let archiveData = Data(base64Encoded: b64) else {
                errorMessage = "Corrupt backup data"
                isRunning = false
                return
            }

            let sizeMB = String(format: "%.1f", Double(archiveData.count) / 1_000_000)
            statusMessage = "Extracting \(sizeMB) MB..."

            try archiveData.write(to: URL(fileURLWithPath: archivePath), options: .atomic)
            guard await extractToStagingDir() else {
                errorMessage = "Failed to extract archive"
                isRunning = false
                return
            }

            statusMessage = "Running mackup restore..."
            guard await runMackup(args: ["restore", "--force"]) else {
                isRunning = false
                return
            }

            // Mackup symlinks don't work for cfprefsd-managed plists (Rectangle, etc.)
            // Directly import plists from the staging dir as a fallback.
            statusMessage = "Applying preference plists..."
            await applyPreferencePlists()

            statusMessage = "Configs restored from Supabase"
            print("[Mackup] Restored configs from Supabase (\(sizeMB) MB)")
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
        }
        isRunning = false
    }

    // MARK: - Mackup Config

    private func writeMackupConfig(apps: [String]) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: stagingDir, withIntermediateDirectories: true)

        var cfg = """
        [storage]
        engine = file_system
        path = \(stagingDir)

        [applications_to_sync]

        """
        for app in apps {
            cfg += "\(app)\n"
        }

        try? cfg.write(toFile: mackupCfgPath, atomically: true, encoding: .utf8)
        print("[Mackup] Config: \(apps.count) apps → \(apps.joined(separator: ", "))")
    }

    /// For cfprefsd-managed plists, `defaults import` writes directly into the preference
    /// daemon's cache, bypassing the symlink problem. Then kill cfprefsd to force a re-read.
    private func applyPreferencePlists() async {
        var applied = 0
        for (relativePath, domain) in Self.plistDomains {
            let fullPath = (stagingDir as NSString).appendingPathComponent(relativePath)
            guard FileManager.default.fileExists(atPath: fullPath) else { continue }

            // Kill the app first so it doesn't overwrite our import
            let appName = domain.components(separatedBy: ".").last ?? ""
            _ = await shell("/usr/bin/killall", args: [appName])

            // defaults import writes the plist into cfprefsd directly
            let ok = await shell("/usr/bin/defaults", args: ["import", domain, fullPath])
            if ok {
                applied += 1
                print("[Mackup] defaults import \(domain) ← \(relativePath)")
            } else {
                print("[Mackup] defaults import FAILED for \(domain)")
            }
        }

        if applied > 0 {
            // Restart cfprefsd so all apps pick up the new prefs
            _ = await shell("/usr/bin/killall", args: ["cfprefsd"])
            print("[Mackup] Killed cfprefsd — \(applied) plists imported")
        }
    }

    // MARK: - Staging Dir

    /// Wipe the staging dir so stale files from previous backups don't bloat the archive.
    private func cleanStagingDir() {
        let fm = FileManager.default
        try? fm.removeItem(atPath: stagingDir)
        try? fm.createDirectory(atPath: stagingDir, withIntermediateDirectories: true)
    }

    // MARK: - Tar/Gzip

    private func compressStagingDir() async -> Bool {
        await shell("/usr/bin/tar", args: ["-czf", archivePath, "-C", stagingDir, "."])
    }

    private func extractToStagingDir() async -> Bool {
        let fm = FileManager.default
        try? fm.removeItem(atPath: stagingDir)
        try? fm.createDirectory(atPath: stagingDir, withIntermediateDirectories: true)
        return await shell("/usr/bin/tar", args: ["-xzf", archivePath, "-C", stagingDir])
    }

    // MARK: - Shell

    private func shell(_ path: String, args: [String]) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = args
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    @discardableResult
    private func runMackup(args: [String]) async -> Bool {
        guard let path = mackupPath else {
            errorMessage = "Mackup not found — run: brew install mackup"
            return false
        }

        let success: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = args
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                let stdinPipe = Pipe()
                stdinPipe.fileHandleForWriting.write("yes\n".data(using: .utf8)!)
                stdinPipe.fileHandleForWriting.closeFile()
                process.standardInput = stdinPipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }

        if !success {
            errorMessage = "mackup \(args.joined(separator: " ")) failed"
        }
        return success
    }
}
