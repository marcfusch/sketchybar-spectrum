import CoreAudio
import Foundation

struct AudioError: Error, CustomStringConvertible {
    let description: String
}

func check(_ status: OSStatus, _ what: String) throws {
    guard status == noErr else {
        throw AudioError(description: "\(what) failed (\(status) '\(fourCC(UInt32(bitPattern: status)))')")
    }
}

func fourCC(_ v: UInt32) -> String {
    let bytes = [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: v >> $0) }
    let printable = bytes.allSatisfy { $0 >= 32 && $0 < 127 }
    return printable ? String(decoding: bytes, as: UTF8.self) : String(v)
}

/// CoreAudio waits for listener blocks to run on their queue, so a listener on a queue that is itself
/// inside a CoreAudio call deadlocks. Listeners run here and only hop to the main queue asynchronously.
let audioListenerQueue = DispatchQueue(label: "sketchyspectrum.listeners")

func propertyAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector,
                               mScope: kAudioObjectPropertyScopeGlobal,
                               mElement: kAudioObjectPropertyElementMain)
}

func getProperty<T>(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: inout T) throws {
    var addr = propertyAddress(selector)
    var size = UInt32(MemoryLayout<T>.size)
    let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, $0) }
    try check(status, "read property '\(fourCC(selector))'")
}

func defaultOutputDevice() throws -> AudioObjectID {
    var device = AudioObjectID(kAudioObjectUnknown)
    try getProperty(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, &device)
    return device
}

func deviceUID(_ device: AudioObjectID) throws -> String {
    var uid: Unmanaged<CFString>?
    try getProperty(device, kAudioDevicePropertyDeviceUID, &uid)
    guard let uid else { throw AudioError(description: "device \(device) has no UID") }
    return uid.takeRetainedValue() as String
}

func getArrayProperty(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
    var addr = propertyAddress(selector)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(obj, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids
}
