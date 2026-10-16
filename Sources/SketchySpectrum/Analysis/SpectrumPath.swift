import Foundation

/// One FFT size, resampled to the display columns.
final class SpectrumPath {
    let size: Int
    private let fft: FFT
    private let resampler: Resampler
    private let gain: Float
    private(set) var db: [Float]

    /// `reference` is the FFT size whose noise floor the output matches: a smaller FFT has wider
    /// bins that collect more noise, so it is pulled down by the bin width ratio.
    init(size: Int, reference: Int, columns: Columns, sampleRate: Double, window: WindowFunction) {
        self.size = size
        fft = FFT(size: size, window: window)
        resampler = Resampler(frequencies: columns.frequencies, edges: columns.edges, sampleRate: sampleRate, fftSize: size)
        gain = Float(10 * log10(Double(size) / Double(reference)))
        db = [Float](repeating: -200, count: columns.frequencies.count)
    }

    /// `samples` holds the newest `size` samples, oldest first.
    func run(_ samples: UnsafePointer<Float>) {
        fft.run(samples)
        resampler.apply(fft.powerDb, into: &db)
        if gain != 0 { for i in db.indices { db[i] += gain } }
    }
}
