import AudioToolbox
import CoreAudio
import Foundation

protocol AudioSource: AnyObject {
    func start()
    func stop()
}

/// Everything the Mac plays, through a process tap inside a private aggregate device.
/// Only built while something plays: a running tap keeps the Mac from idle sleeping.
final class AudioTap: AudioSource {
    private let ring: SampleRing
    private let queue = DispatchQueue(label: "sketchyspectrum.audio", qos: .userInteractive)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var outputListener: AudioObjectPropertyListenerBlock?
    private var monitor: PlaybackMonitor?
    private let mono: UnsafeMutablePointer<Float>
    private let scratchCount = 1 << 14

    init(ring: SampleRing) {
        self.ring = ring
        mono = .allocate(capacity: scratchCount)
    }

    deinit {
        stop()
        mono.deallocate()
    }

    func start() {
        let monitor = PlaybackMonitor { [weak self] playing in
            log("audio: \(playing ? "playback started" : "silent, releasing the tap")")
            if playing { self?.rebuild() } else { self?.teardown() }
        }
        monitor.start()
        self.monitor = monitor
        watchDefaultOutput()
    }

    func stop() {
        monitor?.stop()
        monitor = nil
        if let outputListener {
            var addr = propertyAddress(kAudioHardwarePropertyDefaultOutputDevice)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, audioListenerQueue, outputListener)
            self.outputListener = nil
        }
        teardown()
    }

    private func rebuild() {
        teardown()
        do { try build() } catch {
            log("audio: \(error)")
            teardown()
        }
    }

    private func build() throws {
        let desc = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        desc.uuid = UUID()
        desc.name = "SketchySpectrum"
        desc.isPrivate = true
        desc.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(desc, &tapID), "create process tap")

        var format = AudioStreamBasicDescription()
        try getProperty(tapID, kAudioTapPropertyFormat, &format)
        guard format.mFormatFlags & kAudioFormatFlagIsFloat != 0, format.mBitsPerChannel == 32 else {
            throw AudioError(description: "unsupported tap format \(format)")
        }
        ring.sampleRate = format.mSampleRate

        let outputUID = try deviceUID(defaultOutputDevice())
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SketchySpectrum Tap",
            kAudioAggregateDeviceUIDKey: "com.marcfusch.SketchySpectrum.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: desc.uuid.uuidString,
            ]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "create aggregate device")
        setBufferSize(Self.bufferFrames)
        try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue, ioBlock(format)), "create IO proc")
        try check(AudioDeviceStart(aggregateID, procID), "start aggregate device")
        log("audio: tapping system output, \(Int(format.mSampleRate)) Hz, \(format.mChannelsPerFrame) ch, clock \(outputUID)")
    }

    /// Sub devices come first in the aggregate's buffer list, the tap streams last.
    private func ioBlock(_ format: AudioStreamBasicDescription) -> AudioDeviceIOBlock {
        let ring = ring, mono = mono, chunk = scratchCount
        let channels = Int(max(1, format.mChannelsPerFrame))
        let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0

        return { _, input, _, _, _ in
            let abl = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            let left, right: UnsafePointer<Float>
            let stride, frames: Int
            if interleaved {
                guard let b = abl.last, let data = b.mData?.assumingMemoryBound(to: Float.self) else { return }
                stride = Int(max(1, b.mNumberChannels))
                frames = Int(b.mDataByteSize) / (4 * stride)
                (left, right) = (UnsafePointer(data), UnsafePointer(data + (stride > 1 ? 1 : 0)))
            } else {
                guard abl.count >= channels else { return }
                let chans = abl[(abl.count - channels)...].compactMap { $0.mData?.assumingMemoryBound(to: Float.self) }
                guard let l = chans.first, let r = chans.last else { return }
                stride = 1
                frames = Int(abl[abl.count - 1].mDataByteSize) / 4
                (left, right) = (UnsafePointer(l), UnsafePointer(r))
            }
            for start in Swift.stride(from: 0, to: frames, by: chunk) {
                let n = min(chunk, frames - start)
                mixToMono(left: left + start * stride, right: right + start * stride, stride: stride, frames: n, into: mono)
                ring.push(mono, count: n)
            }
        }
    }

    /// Smaller IO buffers hand samples over sooner; the device may round or refuse it.
    private static let bufferFrames: UInt32 = 128

    private func setBufferSize(_ frames: UInt32) {
        var addr = propertyAddress(kAudioDevicePropertyBufferFrameSize)
        var value = frames
        let status = AudioObjectSetPropertyData(aggregateID, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        if status != noErr { log("audio: could not set a \(frames) frame buffer (\(status))") }
    }

    private func teardown() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    private func watchDefaultOutput() {
        guard outputListener == nil else { return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self, self.monitor?.playing == true else { return }
                log("audio: default output changed")
                self.rebuild()
            }
        }
        var addr = propertyAddress(kAudioHardwarePropertyDefaultOutputDevice)
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, audioListenerQueue, block) == noErr {
            outputListener = block
        }
    }
}
