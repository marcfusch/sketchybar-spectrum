import Foundation

/// FFT windows as cosine sums: w(n) = a0 − a1·cos(2πn/N) + a2·cos(4πn/N) − ...
enum WindowFunction: String {
    case hann, hamming, blackman, rectangular
    case blackmanHarris = "blackman_harris"
    case flatTop = "flat_top"

    private var coefficients: [Double] {
        switch self {
        case .hann: [0.5, 0.5]
        case .hamming: [0.54, 0.46]
        case .blackman: [0.42, 0.5, 0.08]
        case .blackmanHarris: [0.35875, 0.48829, 0.14128, 0.01168]
        case .flatTop: [0.21557895, 0.41663158, 0.277263158, 0.083578947, 0.006947368]
        case .rectangular: [1]
        }
    }

    func fill(_ w: UnsafeMutablePointer<Float>, count: Int) {
        let a = coefficients
        for n in 0..<count {
            let phase = 2 * Double.pi * Double(n) / Double(count)
            var v = 0.0
            for (k, ak) in a.enumerated() { v += (k % 2 == 0 ? ak : -ak) * cos(Double(k) * phase) }
            w[n] = Float(v)
        }
    }
}
