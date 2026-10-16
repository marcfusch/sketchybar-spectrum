import Foundation

/// FFT bins (dB) to `count` columns spread along the frequency scale.
/// Where a column is narrower than a bin it interpolates (Catmull Rom), otherwise it keeps the loudest bin.
struct Resampler {
    private struct Column {
        let lo: Int
        let hi: Int
        let pos: Float
    }

    private let columns: [Column]
    private let bins: Int

    init(frequencies: [Double], edges: [Double], sampleRate: Double, fftSize: Int) {
        let bins = fftSize / 2
        let binHz = sampleRate / Double(fftSize)
        self.bins = bins
        columns = frequencies.indices.map { i in
            Column(lo: max(1, Int((edges[i] / binHz).rounded(.up))),
                   hi: min(bins - 1, Int((edges[i + 1] / binHz).rounded(.down))),
                   pos: Float(frequencies[i] / binHz))
        }
    }

    func apply(_ db: UnsafePointer<Float>, into out: inout [Float]) {
        for (i, c) in columns.enumerated() {
            if c.hi > c.lo {
                var v = db[c.lo]
                for k in c.lo...c.hi where db[k] > v { v = db[k] }
                out[i] = v
            } else {
                out[i] = interpolate(db, at: c.pos)
            }
        }
    }

    private func interpolate(_ db: UnsafePointer<Float>, at pos: Float) -> Float {
        let k = min(bins - 3, max(1, Int(pos)))
        let t = min(1, max(0, pos - Float(k)))
        let p0 = db[k - 1], p1 = db[k], p2 = db[k + 1], p3 = db[k + 2]
        let a = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3
        let b = p0 - 2.5 * p1 + 2 * p2 - 0.5 * p3
        let c = -0.5 * p0 + 0.5 * p2
        return ((a * t + b) * t + c) * t + p1
    }
}
