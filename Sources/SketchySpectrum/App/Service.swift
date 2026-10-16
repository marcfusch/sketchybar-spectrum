import Foundation

/// yabai / skhd style LaunchAgent: `--install-service`, `--start-service`, ...
enum Service {
    enum Command: String, CaseIterable {
        case install = "--install-service"
        case uninstall = "--uninstall-service"
        case start = "--start-service"
        case stop = "--stop-service"
        case restart = "--restart-service"
    }

    static let label = "com.marcfusch.SketchySpectrum"
    private static var plistPath: String { NSHomeDirectory() + "/Library/LaunchAgents/\(label).plist" }
    private static var domain: String { "gui/\(getuid())" }
    private static var target: String { "\(domain)/\(label)" }
    static var logPath: String { "/tmp/sketchyspectrum_\(NSUserName()).err.log" }

    static func run(_ command: Command) -> Int32 {
        switch command {
        case .install: return install()
        case .uninstall:
            _ = stop()
            if (try? FileManager.default.removeItem(atPath: plistPath)) != nil { print("removed \(plistPath)") }
            return 0
        case .start: return start()
        case .stop: return stop()
        case .restart: return isLoaded ? launchctl("kickstart", "-k", target) : start()
        }
    }

    private static func install() -> Int32 {
        guard let exe = Bundle.main.executableURL?.resolvingSymlinksInPath().path else {
            print("cannot resolve the executable path")
            return 1
        }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exe],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false, "Crashed": true],
            "StandardOutPath": "/tmp/sketchyspectrum_\(NSUserName()).out.log",
            "StandardErrorPath": logPath,
            "ProcessType": "Interactive",
        ]
        do {
            try FileManager.default.createDirectory(atPath: (plistPath as NSString).deletingLastPathComponent,
                                                    withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: plistPath))
        } catch {
            print("could not write \(plistPath): \(error)")
            return 1
        }
        print("installed \(plistPath)")
        return 0
    }

    private static func start() -> Int32 {
        if !FileManager.default.fileExists(atPath: plistPath), install() != 0 { return 1 }
        return isLoaded ? launchctl("kickstart", target) : launchctl("bootstrap", domain, plistPath)
    }

    private static func stop() -> Int32 {
        isLoaded ? launchctl("bootout", target) : 0
    }

    private static var isLoaded: Bool {
        launchctl("print", target, quiet: true) == 0
    }

    @discardableResult
    private static func launchctl(_ args: String..., quiet: Bool = false) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        if quiet {
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
        }
        do { try p.run() } catch { return 1 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}
