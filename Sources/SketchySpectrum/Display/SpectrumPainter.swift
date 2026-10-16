import AppKit

/// One frame: colored fill per column, frequency grid, then the trace on top.
final class SpectrumPainter {
    private let bitmap: Bitmap
    private let config: Config
    private let colormap: Colormap
    private let columnColors: [UInt32]?
    private let lineHalfWidth: Float
    private let line: UInt32
    private let grid: [(x: Int, color: UInt32)]
    private var heights: [Float]

    var columns: Int { bitmap.width }

    init?(size: CGSize, scale: CGFloat, config: Config, space: NSColorSpace) {
        guard let cg = space.cgColorSpace,
              let bitmap = Bitmap(width: Int((size.width * scale).rounded()), height: Int((size.height * scale).rounded()), space: cg)
        else { return nil }
        self.bitmap = bitmap
        self.config = config
        let colormap = Colormap(colors: config.colors, opacity: config.fillOpacity, space: space)
        self.colormap = colormap
        columnColors = config.colorMode == .frequency
            ? (0..<bitmap.width).map { colormap(Float($0) / Float(bitmap.width - 1)) }
            : nil
        lineHalfWidth = Float(config.lineWidth * scale) / 2
        line = pixel(config.lineColor, space: space)
        heights = [Float](repeating: 0, count: bitmap.width)

        let minor = pixel(config.gridColor, space: space)
        let major = pixel(config.gridColor.withAlphaComponent(min(1, config.gridColor.alphaComponent * 2.5)), space: space)
        grid = config.grid ? FrequencyGrid.lines(minFreq: config.minFreq, maxFreq: config.maxFreq, scale: config.scale).map {
            (min(bitmap.width - 1, Int($0.x * Double(bitmap.width))), $0.major ? major : minor)
        } : []
    }

    func paint(levels: [Float]) -> CGImage? {
        guard levels.count == bitmap.width else { return nil }
        bitmap.clear()
        fill(levels)
        for g in grid { bitmap.span(g.x, from: 0, to: Float(bitmap.height), g.color) }
        trace(levels)
        return bitmap.image()
    }

    private func fill(_ levels: [Float]) {
        let rows = Float(bitmap.height)
        for (x, level) in levels.enumerated() where level > 0 {
            let h = level * rows
            let color = columnColors?[x] ?? colormap(level)
            for y in 0..<min(bitmap.height, Int(h)) { bitmap.set(x, y, color) }
            bitmap.span(x, from: h.rounded(.down), to: h, color)
        }
    }

    /// Each column covers the curve from halfway to its left neighbor to halfway to its right one.
    private func trace(_ levels: [Float]) {
        guard lineHalfWidth > 0 else { return }
        let rows = Float(bitmap.height)
        for i in levels.indices { heights[i] = levels[i] * rows }
        let last = heights.count - 1
        for x in 0...last {
            let y = heights[x]
            let a = (heights[max(0, x - 1)] + y) / 2
            let b = (heights[min(last, x + 1)] + y) / 2
            bitmap.span(x, from: min(a, b, y) - lineHalfWidth, to: max(a, b, y) + lineHalfWidth, line)
        }
    }
}
