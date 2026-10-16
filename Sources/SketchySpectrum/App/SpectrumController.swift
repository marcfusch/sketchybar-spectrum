import AppKit

/// Drives the frame loop and decides when the overlay is placed, shown, hidden or paused.
final class SpectrumController {
    private let ring: SampleRing
    private var config: Config
    private var analyzer: Analyzer
    private let view: SpectrumView
    private let window: OverlayWindow
    private var link: CADisplayLink?
    private var housekeeping: Timer?
    private var ticks = 0
    private var lastFrame: CFTimeInterval = 0
    private var itemFrame: CGRect?
    private var lastResize = -Double.infinity
    private var placementInFlight = false
    private var lastSnapshot: BarWindows.Snapshot?
    private var running = false
    private var visible = false

    init(ring: SampleRing, config: Config) {
        self.ring = ring
        self.config = config
        analyzer = Analyzer(ring: ring, config: config)
        view = SpectrumView(config: config)
        window = OverlayWindow(content: view)
    }

    func start() {
        let link = view.displayLink(target: self, selector: #selector(frame(_:)))
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        self.link = link
        applyFrameRate()

        housekeeping = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.housekeep() }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.refreshPlacement(force: true) }
        window.pin()
        refreshPlacement(force: true)
    }

    func apply(_ config: Config) {
        self.config = config
        lastResize = -.infinity
        analyzer = Analyzer(ring: ring, config: config)
        view.apply(config)
        applyFrameRate()
        refreshPlacement(force: true)
    }

    /// Asks SketchyBar for the item only when its windows changed (or when forced): a query spawns a process.
    func refreshPlacement(force: Bool = false) {
        guard !placementInFlight else { return }
        placementInFlight = true
        let item = config.item, exe = config.sketchybar
        let known = force || itemFrame == nil ? nil : lastSnapshot
        DispatchQueue.global(qos: .utility).async {
            let snapshot = BarWindows.snapshot()
            let frame = snapshot != nil && snapshot == known ? nil : ItemFrame.of(item, sketchybar: exe)
            DispatchQueue.main.async {
                self.placementInFlight = false
                if snapshot != nil && snapshot == known { return }
                self.lastSnapshot = snapshot
                self.place(frame, level: snapshot?.level)
            }
        }
    }

    // MARK: Loop

    @objc private func frame(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = lastFrame == 0 ? 1.0 / 60 : now - lastFrame
        lastFrame = now
        analyzer.resize(columns: view.columns)
        analyzer.update(dt: dt)
        view.render(levels: analyzer.levels)
        if !hasSound && analyzer.isIdle { updateState() }
    }

    private func housekeep() {
        ticks += 1
        if !running { updateState() }
        let every = itemFrame == nil ? 8 : (running ? 4 : 0)
        if every > 0 && ticks % every == 0 { refreshPlacement() }
    }

    // MARK: State

    private var hasSound: Bool {
        monotonicSeconds() - ring.lastSound < config.silenceTimeout
    }

    private func place(_ item: CGRect?, level: NSWindow.Level?) {
        if let item, config.width > 0, abs(item.width - config.width) > 0.5 { resizeItem() }
        itemFrame = level == nil ? nil : item
        if let level, window.level != level { window.level = level }
        if let item {
            let frame = windowFrame(in: item)
            if window.frame != frame { window.setFrame(frame, display: true) }
        }
        updateState()
    }

    private func windowFrame(in item: CGRect) -> CGRect {
        let h = config.height > 0 ? config.height : item.height
        return CGRect(x: item.minX + config.padding, y: item.midY - h / 2 + config.yOffset,
                      width: max(1, item.width - 2 * config.padding), height: h)
    }

    /// The item's width follows the config, so `width` is all there is to edit.
    private func resizeItem() {
        let now = monotonicSeconds()
        guard now - lastResize > 5 else { return }
        lastResize = now
        let item = config.item, exe = config.sketchybar, width = Int(config.width)
        DispatchQueue.global(qos: .utility).async {
            SketchyBar.set(item, ["width=\(width)"], sketchybar: exe)
            DispatchQueue.main.async { self.refreshPlacement(force: true) }
        }
    }

    private func updateState() {
        let placed = itemFrame != nil
        let run = placed && (hasSound || !analyzer.isIdle)
        let show = placed && (run || !config.hideWhenSilent)

        if run != running {
            running = run
            lastFrame = 0
            link?.isPaused = !run
            if run { refreshPlacement() }
        }
        if show != visible {
            visible = show
            if show { view.render(levels: analyzer.levels) }
            window.fade(in: show)
        }
    }

    private func applyFrameRate() {
        guard let link else { return }
        if config.fps > 0 {
            let fps = Float(config.fps)
            link.preferredFrameRateRange = CAFrameRateRange(minimum: fps / 2, maximum: fps, preferred: fps)
        } else {
            link.preferredFrameRateRange = .default
        }
    }
}
