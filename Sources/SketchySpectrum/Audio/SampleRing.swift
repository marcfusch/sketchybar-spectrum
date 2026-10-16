import Accelerate
import Foundation
import os

/// Mono samples from the audio thread to the render thread. The lock only covers a memcpy.
final class SampleRing: @unchecked Sendable {
    private let capacity: Int
    private let buf: UnsafeMutablePointer<Float>
    private let lock: UnsafeMutablePointer<os_unfair_lock>
    private var write = 0
    private var _sampleRate = 48000.0
    private var _lastSound = 0.0

    static let silenceThreshold: Float = 1e-4

    init(capacity: Int = 1 << 15) {
        self.capacity = capacity
        buf = .allocate(capacity: capacity)
        buf.initialize(repeating: 0, count: capacity)
        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        buf.deallocate()
        lock.deallocate()
    }

    var sampleRate: Double {
        get { os_unfair_lock_lock(lock); defer { os_unfair_lock_unlock(lock) }; return _sampleRate }
        set { os_unfair_lock_lock(lock); _sampleRate = newValue; os_unfair_lock_unlock(lock) }
    }

    /// `monotonicSeconds()` of the last block that was not silent.
    var lastSound: Double {
        os_unfair_lock_lock(lock); defer { os_unfair_lock_unlock(lock) }
        return _lastSound
    }

    func push(_ src: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }
        var peak: Float = 0
        vDSP_maxmgv(src, 1, &peak, vDSP_Length(count))
        let now = peak > Self.silenceThreshold ? monotonicSeconds() : 0

        os_unfair_lock_lock(lock)
        var src = src, left = count
        if left > capacity { src += left - capacity; left = capacity }
        while left > 0 {
            let n = min(left, capacity - write)
            (buf + write).update(from: src, count: n)
            write = (write + n) % capacity
            src += n
            left -= n
        }
        if now > 0 { _lastSound = now }
        os_unfair_lock_unlock(lock)
    }

    /// Newest `count` samples, oldest first.
    func latest(into dst: UnsafeMutablePointer<Float>, count: Int) {
        let count = min(count, capacity)
        os_unfair_lock_lock(lock)
        let start = (write - count + capacity) % capacity
        let first = min(count, capacity - start)
        dst.update(from: buf + start, count: first)
        if first < count { (dst + first).update(from: buf, count: count - first) }
        os_unfair_lock_unlock(lock)
    }
}
