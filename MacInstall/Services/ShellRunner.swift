import Foundation

/// Protocol for running shell commands. Abstracted for testability.
protocol ShellRunning: Sendable {
    func run(_ executablePath: String, arguments: [String], standardInput: String?) async -> (output: String, success: Bool)
}

extension ShellRunning {
    func run(_ executablePath: String, arguments: [String]) async -> (output: String, success: Bool) {
        await run(executablePath, arguments: arguments, standardInput: nil)
    }
}

/// Default implementation that spawns a real `Process`.
struct ShellRunner: ShellRunning {
    @discardableResult
    func run(_ executablePath: String, arguments: [String], standardInput: String? = nil) async -> (output: String, success: Bool) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                if let standardInput {
                    let stdinPipe = Pipe()
                    stdinPipe.fileHandleForWriting.write(standardInput.data(using: .utf8)!)
                    stdinPipe.fileHandleForWriting.closeFile()
                    process.standardInput = stdinPipe
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: (output, process.terminationStatus == 0))
                } catch {
                    continuation.resume(returning: ("", false))
                }
            }
        }
    }
}
