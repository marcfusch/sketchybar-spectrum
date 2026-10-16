import CoreGraphics

/// Premultiplied RGBA pixels, row 0 at the bottom, drawn by hand and handed to Core Animation as a CGImage.
final class Bitmap {
    let width: Int
    let height: Int
    private let stride: Int
    private let ctx: CGContext
    private let pixels: UnsafeMutablePointer<UInt32>

    init?(width: Int, height: Int, space: CGColorSpace) {
        guard width > 1, height > 1,
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return nil }
        self.width = width
        self.height = height
        self.ctx = ctx
        stride = ctx.bytesPerRow / 4
        pixels = data.assumingMemoryBound(to: UInt32.self)
    }

    func clear() {
        pixels.update(repeating: 0, count: stride * height)
    }

    func image() -> CGImage? { ctx.makeImage() }

    @inline(__always) func set(_ x: Int, _ y: Int, _ p: UInt32) {
        pixels[(height - 1 - y) * stride + x] = p
    }

    /// Source over, `p` scaled by `coverage` first.
    @inline(__always) func blend(_ x: Int, _ y: Int, _ p: UInt32, coverage: Float = 1) {
        let src = coverage >= 1 ? p : scaled(p, coverage)
        let i = (height - 1 - y) * stride + x
        pixels[i] = src &+ scaled(pixels[i], 1 - Float(src >> 24) / 255)
    }

    /// Fills `[lo, hi)` (fractional rows) of column `x`, with antialiased ends.
    func span(_ x: Int, from lo: Float, to hi: Float, _ p: UInt32) {
        let first = max(0, Int(lo.rounded(.down))), last = min(height - 1, Int(hi.rounded(.up)) - 1)
        guard first <= last else { return }
        for y in first...last {
            let cover = min(Float(y + 1), hi) - max(Float(y), lo)
            if cover > 0 { blend(x, y, p, coverage: cover) }
        }
    }
}

/// Multiplies every channel of a premultiplied pixel by `k` (0...1).
@inline(__always) func scaled(_ p: UInt32, _ k: Float) -> UInt32 {
    let k = UInt32(min(1, max(0, k)) * 256)
    let rb = ((p & 0x00ff_00ff) &* k >> 8) & 0x00ff_00ff
    let ga = (((p >> 8) & 0x00ff_00ff) &* k >> 8) & 0x00ff_00ff
    return rb | ga << 8
}
