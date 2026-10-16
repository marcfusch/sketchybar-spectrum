import Foundation

/// x positions (0...1) of the 1, 2 ... 9 × 10ⁿ Hz lines; `major` for the powers of ten.
enum FrequencyGrid {
    struct Line {
        let x: Double
        let major: Bool
    }

    static func lines(minFreq: Double, maxFreq: Double, scale: FrequencyScale) -> [Line] {
        var out: [Line] = []
        var decade = pow(10, floor(log10(minFreq)))
        while decade <= maxFreq {
            for m in 1...9 {
                let f = decade * Double(m)
                if f > minFreq && f < maxFreq { out.append(Line(x: scale.position(of: f, lo: minFreq, hi: maxFreq), major: m == 1)) }
            }
            decade *= 10
        }
        return out
    }
}
