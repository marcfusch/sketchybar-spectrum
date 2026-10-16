import AppKit

/// Level (0...1) to a pixel, from the configured colors spread evenly.
struct Colormap {
    private let lut: [UInt32]

    init(colors: [NSColor], opacity: CGFloat, space: NSColorSpace) {
        let stops = colors.map { $0.usingColorSpace(space) ?? $0 }
        lut = (0..<256).map { i in
            let pos = CGFloat(i) / 255 * CGFloat(max(1, stops.count - 1))
            let k = min(stops.count - 1, Int(pos))
            let a = stops[k], b = stops[min(stops.count - 1, k + 1)]
            let f = pos - CGFloat(k)
            func mix(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * f }
            return pixel(r: mix(a.redComponent, b.redComponent),
                         g: mix(a.greenComponent, b.greenComponent),
                         b: mix(a.blueComponent, b.blueComponent),
                         a: mix(a.alphaComponent, b.alphaComponent) * opacity)
        }
    }

    func callAsFunction(_ level: Float) -> UInt32 {
        lut[Int(min(1, max(0, level)) * 255)]
    }
}

func pixel(_ color: NSColor, space: NSColorSpace) -> UInt32 {
    let c = color.usingColorSpace(space) ?? color
    return pixel(r: c.redComponent, g: c.greenComponent, b: c.blueComponent, a: c.alphaComponent)
}

/// Premultiplied RGBA bytes in memory order, as a little endian word.
func pixel(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> UInt32 {
    func byte(_ v: CGFloat) -> UInt32 { UInt32(min(255, max(0, (v * a * 255).rounded()))) }
    return byte(r) | byte(g) << 8 | byte(b) << 16 | UInt32(min(255, max(0, (a * 255).rounded()))) << 24
}
