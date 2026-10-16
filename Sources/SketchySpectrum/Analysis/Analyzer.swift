import Foundation

/// Owns the channel and rebuilds it when the number of display columns changes.
final class Analyzer {
    private let ring: SampleRing
    private let config: Config
    private var channel: Channel?

    private(set) var columns = 0
    var levels: [Float] { channel?.levels ?? [] }
    var isIdle: Bool { channel?.isIdle ?? true }

    init(ring: SampleRing, config: Config) {
        self.ring = ring
        self.config = config
    }

    func resize(columns: Int) {
        guard columns != self.columns, columns > 1 else { return }
        self.columns = columns
        channel = Channel(ring: ring, config: config, columns: columns)
    }

    func update(dt: Double) {
        channel?.update(dt: Float(min(dt, 0.1)))
    }
}
