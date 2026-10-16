import AppKit

/// Shows the painter's bitmap, filling the whole window.
final class SpectrumView: NSView {
    private let canvas = CALayer()
    private var painter: SpectrumPainter?
    private var config: Config

    var columns: Int { painter?.columns ?? 0 }

    init(config: Config) {
        self.config = config
        super.init(frame: .zero)
        wantsLayer = true
        canvas.contentsGravity = .resize
        canvas.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(canvas)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func apply(_ config: Config) {
        self.config = config
        rebuild()
    }

    func render(levels: [Float]) {
        canvas.contents = painter?.paint(levels: levels)
    }

    override func layout() {
        super.layout()
        rebuild()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rebuild()
    }

    private func rebuild() {
        let scale = window?.backingScaleFactor ?? 2
        canvas.frame = bounds
        canvas.contentsScale = scale
        let space = window?.colorSpace ?? NSScreen.main?.colorSpace ?? .sRGB
        painter = SpectrumPainter(size: bounds.size, scale: scale, config: config, space: space)
    }
}
