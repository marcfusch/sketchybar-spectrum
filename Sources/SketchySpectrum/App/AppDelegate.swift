import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let args = Arguments.parse()
    private let ring = SampleRing()
    private let signals = Signals()
    private var source: AudioSource?
    private var controller: SpectrumController?
    private var watcher: ConfigWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let other = otherInstance() {
            log("already running as pid \(other.processIdentifier), exiting")
            exit(0)
        }
        let controller = SpectrumController(ring: ring, config: Config.load(path: args.configPath))
        let watcher = ConfigWatcher(path: args.configPath) { controller.apply($0) }
        let source: AudioSource = args.demo ? DemoSource(ring: ring) : AudioTap(ring: ring)

        signals.on(SIGHUP) { watcher.reload() }
        signals.on(SIGUSR1) { controller.refreshPlacement(force: true) }
        signals.on(SIGINT, SIGTERM) { NSApp.terminate(nil) }

        source.start()
        controller.start()
        watcher.start()
        (self.source, self.controller, self.watcher) = (source, controller, watcher)
    }

    func applicationWillTerminate(_ notification: Notification) {
        source?.stop()
    }

    private func otherInstance() -> NSRunningApplication? {
        guard let id = Bundle.main.bundleIdentifier else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).first { $0 != .current }
    }
}
