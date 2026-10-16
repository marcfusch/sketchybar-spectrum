import CoreAudio
import Foundation

/// Tells when another process plays audio, so the tap (which keeps the Mac awake) only runs then.
/// Event driven: CoreAudio notifies process list and "is running" changes; nothing is polled.
final class PlaybackMonitor {
    private let hold: Double
    private let onChange: (Bool) -> Void
    private let system = AudioObjectID(kAudioObjectSystemObject)
    private var watched: Set<AudioObjectID> = []
    private var listListener: AudioObjectPropertyListenerBlock?
    private var runningListener: AudioObjectPropertyListenerBlock?
    private var holdTimer: Timer?
    private(set) var playing = false

    init(hold: Double = 15, onChange: @escaping (Bool) -> Void) {
        self.hold = hold
        self.onChange = onChange
    }

    func start() {
        let list: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.refreshProcesses() }
        }
        let running: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.evaluate() }
        }
        listListener = list
        runningListener = running
        var addr = propertyAddress(kAudioHardwarePropertyProcessObjectList)
        AudioObjectAddPropertyListenerBlock(system, &addr, audioListenerQueue, list)
        refreshProcesses()
    }

    func stop() {
        var addr = propertyAddress(kAudioHardwarePropertyProcessObjectList)
        if let listListener { AudioObjectRemovePropertyListenerBlock(system, &addr, audioListenerQueue, listListener) }
        watched.forEach(unwatch)
        watched = []
        holdTimer?.invalidate()
        listListener = nil
        runningListener = nil
    }

    private func refreshProcesses() {
        let me = getpid()
        let current = Set(getArrayProperty(system, kAudioHardwarePropertyProcessObjectList).filter { process in
            var pid: pid_t = 0
            return (try? getProperty(process, kAudioProcessPropertyPID, &pid)) != nil && pid != me
        })
        watched.subtracting(current).forEach(unwatch)
        current.subtracting(watched).forEach(watch)
        watched = current
        evaluate()
    }

    private func evaluate() {
        let anyPlaying = watched.contains { process in
            var running: UInt32 = 0
            return (try? getProperty(process, kAudioProcessPropertyIsRunningOutput, &running)) != nil && running != 0
        }
        if anyPlaying {
            holdTimer?.invalidate()
            holdTimer = nil
            set(playing: true)
        } else if playing, holdTimer == nil {
            holdTimer = Timer.scheduledTimer(withTimeInterval: hold, repeats: false) { [weak self] _ in
                self?.holdTimer = nil
                self?.set(playing: false)
            }
        }
    }

    private func set(playing: Bool) {
        guard playing != self.playing else { return }
        self.playing = playing
        onChange(playing)
    }

    /// "Is running output" sends no notifications; "is running" does, so that one is watched.
    private func watch(_ process: AudioObjectID) {
        guard let runningListener else { return }
        var addr = propertyAddress(kAudioProcessPropertyIsRunning)
        AudioObjectAddPropertyListenerBlock(process, &addr, audioListenerQueue, runningListener)
    }

    private func unwatch(_ process: AudioObjectID) {
        guard let runningListener else { return }
        var addr = propertyAddress(kAudioProcessPropertyIsRunning)
        AudioObjectRemovePropertyListenerBlock(process, &addr, audioListenerQueue, runningListener)
    }
}
