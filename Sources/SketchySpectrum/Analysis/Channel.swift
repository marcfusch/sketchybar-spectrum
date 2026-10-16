import Foundation

/// One ring to smoothed 0...1 levels per column: a big FFT for the lows,
/// cross faded into a fast one for the highs so transients show up with less delay.
final class Channel {
    private let ring: SampleRing
    private let config: Config
    private let count: Int
    private let samples: UnsafeMutablePointer<Float>
    private var sampleRate = 0.0
    private var columns: Columns!
    private var big: SpectrumPath!
    private var fast: SpectrumPath?
    private var targets: [Float]
    private var smoother: Smoother

    var levels: [Float] { smoother.levels }
    var isIdle: Bool { smoother.isIdle }

    init(ring: SampleRing, config: Config, columns: Int) {
        self.ring = ring
        self.config = config
        count = columns
        samples = .allocate(capacity: config.fftSize)
        targets = [Float](repeating: 0, count: columns)
        smoother = Smoother(count: columns)
    }

    deinit { samples.deallocate() }

    func update(dt: Float) {
        if ring.sampleRate != sampleRate { build(sampleRate: ring.sampleRate) }

        ring.latest(into: samples, count: big.size)
        big.run(samples)
        fast?.run(samples + (big.size - fast!.size))

        let lo = Float(config.minDb), span = Float(config.maxDb - config.minDb)
        for i in 0..<count {
            var db = big.db[i]
            if let fast, columns.fastWeight[i] > 0 { db += (fast.db[i] - db) * columns.fastWeight[i] }
            targets[i] = min(1, max(0, (db + columns.tilt[i] - lo) / span))
        }
        smoother.step(towards: targets, dt: dt, amount: config.smoothing)
    }

    private func build(sampleRate: Double) {
        self.sampleRate = sampleRate
        columns = Columns(count: count, config: config, sampleRate: sampleRate)
        big = SpectrumPath(size: config.fftSize, reference: config.fftSize, columns: columns,
                           sampleRate: sampleRate, window: config.window)
        let fastSize = config.fastFftSize
        fast = fastSize > 0 && fastSize < config.fftSize
            ? SpectrumPath(size: fastSize, reference: config.fftSize, columns: columns, sampleRate: sampleRate, window: config.window)
            : nil
    }
}
