import Foundation

/// Polls the config file's modification date once a second; editors replace files, so no vnode watch.
final class ConfigWatcher {
    private let path: String
    private let onChange: (Config) -> Void
    private var stamp: Date?
    private var timer: Timer?

    init(path: String, onChange: @escaping (Config) -> Void) {
        self.path = path
        self.onChange = onChange
        stamp = modified()
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
    }

    func reload() {
        stamp = modified()
        onChange(Config.load(path: path))
        log("config: reloaded \(path)")
    }

    private func poll() {
        if modified() != stamp { reload() }
    }

    private func modified() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }
}
