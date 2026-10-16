import Foundation

/// MiniMeters style smoothing: each 60 Hz frame keeps `amount` of the previous value.
/// Scaled by the real frame time, so it feels the same at any refresh rate.
struct Smoother {
    private(set) var levels: [Float]

    init(count: Int) {
        levels = [Float](repeating: 0, count: count)
    }

    var isIdle: Bool { !levels.contains { $0 > 0.001 } }

    mutating func step(towards targets: [Float], dt: Float, amount: Double) {
        let keep = amount > 0 ? pow(Float(amount), dt * 60) : 0
        for i in levels.indices {
            levels[i] = targets[i] + (levels[i] - targets[i]) * keep
        }
    }
}
