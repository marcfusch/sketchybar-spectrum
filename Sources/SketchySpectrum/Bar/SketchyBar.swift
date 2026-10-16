import Foundation

/// Runs the `sketchybar` CLI. Apps started with `open` get a bare PATH, hence the lookup.
enum SketchyBar {
    static func query(_ name: String, sketchybar: String) -> [String: Any]? {
        guard let data = run(["--query", name], sketchybar: sketchybar) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func set(_ item: String, _ properties: [String], sketchybar: String) {
        _ = run(["--set", item] + properties, sketchybar: sketchybar)
    }

    private static func executable(_ configured: String) -> String? {
        let candidates = [configured, "/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar"]
        return candidates.first { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func run(_ args: [String], sketchybar: String) -> Data? {
        guard let exe = executable(sketchybar) else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return p.terminationStatus == 0 ? data : nil
    }
}
