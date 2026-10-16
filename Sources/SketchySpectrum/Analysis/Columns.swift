import Foundation

/// Center and edge frequencies of each display column, plus what depends only on them.
struct Columns {
    let frequencies: [Double]
    let edges: [Double]
    let tilt: [Float]
    /// 0 = big FFT only, 1 = fast FFT only, cross faded over the octave below `crossover`.
    let fastWeight: [Float]

    init(count: Int, config: Config, sampleRate: Double) {
        let lo = config.minFreq, hi = min(config.maxFreq, sampleRate / 2)
        let at = { (i: Double) in config.scale.frequency(at: i / Double(count), lo: lo, hi: hi) }
        frequencies = (0..<count).map { at(Double($0) + 0.5) }
        edges = (0...count).map { at(Double($0)) }
        tilt = frequencies.map { Float(config.tilt * log2($0 / 1000)) }
        fastWeight = frequencies.map { f in
            let t = Float(min(1, max(0, log2(f / (config.crossover / 2)))))
            return t * t * (3 - 2 * t)
        }
    }
}
