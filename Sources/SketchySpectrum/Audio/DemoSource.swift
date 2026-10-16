import Foundation

/// Synthetic music-ish signal for `--demo`, so the look can be tuned without the audio permission.
final class DemoSource: AudioSource {
    private let ring: SampleRing
    private let rate = 48000.0
    private let block = 480
    private var timer: DispatchSourceTimer?
    private var t = 0.0
    private var buf: [Float]

    init(ring: SampleRing) {
        self.ring = ring
        buf = [Float](repeating: 0, count: block)
    }

    func start() {
        ring.sampleRate = rate
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "sketchyspectrum.demo", qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: .milliseconds(10))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let dt = 1 / rate
        for i in 0..<block {
            let beat = t.truncatingRemainder(dividingBy: 0.5)
            let kick = exp(-beat * 18) * sin(2 * .pi * (45 + 110 * exp(-beat * 30)) * t)
            let bass = sin(2 * .pi * 55 * t) * 0.25
            let hat = beat > 0.25 && beat < 0.29 ? Double.random(in: -0.12...0.12) : 0
            let chord = [220.0, 277.2, 329.6, 440, 554.4].reduce(0) { $0 + sin(2 * .pi * $1 * t) } * 0.05
            let air = Double.random(in: -0.01...0.01)
            buf[i] = Float(kick * 0.6 + bass + hat + chord * (0.6 + 0.4 * sin(t * 1.3)) + air)
            t += dt
        }
        buf.withUnsafeBufferPointer { ring.push($0.baseAddress!, count: block) }
    }
}
