import Foundation

/// Unix signals delivered on the main queue.
final class Signals {
    private var sources: [DispatchSourceSignal] = []

    func on(_ signals: Int32..., handler: @escaping () -> Void) {
        for sig in signals {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler(handler: handler)
            src.resume()
            sources.append(src)
        }
    }
}
