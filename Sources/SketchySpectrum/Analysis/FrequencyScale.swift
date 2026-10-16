import Foundation

/// How frequencies spread along the x axis.
enum FrequencyScale: String {
    case log, mel, linear

    private func warp(_ f: Double) -> Double {
        switch self {
        case .log: Foundation.log(f)
        case .mel: 2595 * log10(1 + f / 700)
        case .linear: f
        }
    }

    private func unwarp(_ v: Double) -> Double {
        switch self {
        case .log: exp(v)
        case .mel: 700 * (pow(10, v / 2595) - 1)
        case .linear: v
        }
    }

    /// 0...1 position of `f` between `lo` and `hi`.
    func position(of f: Double, lo: Double, hi: Double) -> Double {
        (warp(f) - warp(lo)) / (warp(hi) - warp(lo))
    }

    func frequency(at u: Double, lo: Double, hi: Double) -> Double {
        unwarp(warp(lo) + u * (warp(hi) - warp(lo)))
    }
}
