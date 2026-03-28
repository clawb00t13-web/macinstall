import Foundation

/// Watches a set of file paths for write/rename/delete events.
/// Calls `onChange(appId, key)` after a 2-second debounce.
@MainActor
class ConfigWatcher {
    private var sources: [String: DispatchSourceFileSystemObject] = [:]  // "appId:key" -> source
    private var debounceTimers: [String: Task<Void, Never>] = [:]
    var onChange: ((String, String) -> Void)?  // (appId, key)

    func watch(appId: String, paths: [ConfigPath]) {
        for cp in paths {
            let token = "\(appId):\(cp.key)"
            guard sources[token] == nil else { continue }
            let fd = open(cp.resolvedPath, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                Task { @MainActor in
                    self?.scheduleCapture(appId: appId, key: cp.key, token: token)
                }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            sources[token] = source
        }
    }

    func stopWatching(appId: String) {
        let prefix = "\(appId):"
        let keys = sources.keys.filter { $0.hasPrefix(prefix) }
        for k in keys {
            sources[k]?.cancel()
            sources.removeValue(forKey: k)
        }
    }

    func stopAll() {
        sources.values.forEach { $0.cancel() }
        sources.removeAll()
    }

    private func scheduleCapture(appId: String, key: String, token: String) {
        debounceTimers[token]?.cancel()
        debounceTimers[token] = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s debounce
            guard !Task.isCancelled else { return }
            onChange?(appId, key)
        }
    }
}
