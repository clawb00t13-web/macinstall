import Foundation

struct AppDetector {
    static func detectInstalled(app: CatalogApp, brewCasks: Set<String>) -> InstallStatus {
        // Check /Applications/AppName.app
        let appPath = "/Applications/\(app.name).app"
        if FileManager.default.fileExists(atPath: appPath) {
            return .installed
        }

        // Check common alternate paths
        let homeApps = (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
            .appendingPathComponent("Applications/\(app.name).app")
        if FileManager.default.fileExists(atPath: homeApps) {
            return .installed
        }

        // Check brew cask list
        if let cask = app.brewCask, brewCasks.contains(cask) {
            return .installed
        }

        return .notInstalled
    }

    static func fetchBrewCasks() async -> Set<String> {
        let output = await runCommand("/opt/homebrew/bin/brew", args: ["list", "--cask"])
        let items = output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Set(items)
    }

    static func fetchMasInstalled() async -> Set<Int> {
        let output = await runCommand("/usr/local/bin/mas", args: ["list"])
        var ids: Set<Int> = []
        for line in output.components(separatedBy: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
            if let first = parts.first, let id = Int(first) {
                ids.insert(id)
            }
        }
        return ids
    }

    private static func runCommand(_ path: String, args: [String]) async -> String {
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
}
