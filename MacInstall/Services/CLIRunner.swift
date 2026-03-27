import Foundation

struct CLIRunner {
    static func runInstall(profilePath: String, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Try macinstall CLI first
            let macinstallPaths = [
                "/usr/local/bin/macinstall",
                "/opt/homebrew/bin/macinstall",
                (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
                    .appendingPathComponent(".local/bin/macinstall")
            ]

            for path in macinstallPaths {
                if FileManager.default.fileExists(atPath: path) {
                    let (success, output) = runProcess(path, args: ["install", "--profile", profilePath])
                    DispatchQueue.main.async { completion(success, output) }
                    return
                }
            }

            // Fallback: read profile and brew install each
            DispatchQueue.main.async {
                completion(false, "macinstall CLI not found. Install it with: npm install -g macinstall")
            }
        }
    }

    static func installCask(_ cask: String, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let brewPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
                ? "/opt/homebrew/bin/brew"
                : "/usr/local/bin/brew"
            let (success, output) = runProcess(brewPath, args: ["install", "--cask", cask])
            DispatchQueue.main.async { completion(success, output) }
        }
    }

    static func openInEditor(_ path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-t", path]
        try? process.run()
    }

    @discardableResult
    private static func runProcess(_ path: String, args: [String]) -> (Bool, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return (process.terminationStatus == 0, out + err)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
