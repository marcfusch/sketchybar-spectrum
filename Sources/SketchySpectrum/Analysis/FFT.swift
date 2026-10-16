import Accelerate

/// Windowed real FFT. `powerDb[k]` is bin k in dBFS: a full scale sine reads 0 dB whatever the window.
final class FFT {
    let size: Int
    var bins: Int { size / 2 }
    let powerDb: UnsafeMutablePointer<Float>

    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private let window: UnsafeMutablePointer<Float>
    private let frame: UnsafeMutablePointer<Float>
    private let real: UnsafeMutablePointer<Float>
    private let imag: UnsafeMutablePointer<Float>
    private var ref: Float

    init(size: Int, window function: WindowFunction) {
        self.size = size
        log2n = vDSP_Length(log2(Double(size)))
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        window = .allocate(capacity: size)
        frame = .allocate(capacity: size)
        real = .allocate(capacity: size / 2)
        imag = .allocate(capacity: size / 2)
        powerDb = .allocate(capacity: size / 2)
        function.fill(window, count: size)
        var sum: Float = 0
        vDSP_sve(window, 1, &sum, vDSP_Length(size))
        ref = sum * sum
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
        [window, frame, real, imag, powerDb].forEach { $0.deallocate() }
    }

    func run(_ samples: UnsafePointer<Float>) {
        let half = vDSP_Length(bins)
        vDSP_vmul(samples, 1, window, 1, frame, 1, vDSP_Length(size))

        var split = DSPSplitComplex(realp: real, imagp: imag)
        frame.withMemoryRebound(to: DSPComplex.self, capacity: bins) {
            vDSP_ctoz($0, 2, &split, 1, half)
        }
        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
        imag[0] = 0 // zrip packs Nyquist there

        vDSP_zvmags(&split, 1, powerDb, 1, half)
        var floor: Float = 1e-12
        vDSP_vsadd(powerDb, 1, &floor, powerDb, 1, half)
        vDSP_vdbcon(powerDb, 1, &ref, powerDb, 1, half, 0)
    }
}
