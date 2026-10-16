import AppKit

/// What the window server knows about SketchyBar's windows, cheaper to read than asking SketchyBar.
enum BarWindows {
    struct Snapshot: Equatable {
        /// One above the bar window (SketchyBar's widest): over the bar, under app windows.
        let level: NSWindow.Level
        /// Every SketchyBar window; any item moving or resizing changes this.
        let frames: [CGRect]
    }

    /// Nil when the bar is not on screen, e.g. hidden in a fullscreen space.
    static func snapshot() -> Snapshot? {
        let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let windows = all.filter { ($0[kCGWindowOwnerName as String] as? String)?.lowercased() == "sketchybar" }
        let frames = windows.map(frame)
        guard let bar = zip(windows, frames).max(by: { $0.1.width < $1.1.width }),
              let layer = bar.0[kCGWindowLayer as String] as? Int else { return nil }
        return Snapshot(level: NSWindow.Level(rawValue: layer + 1), frames: frames)
    }

    private static func frame(_ window: [String: Any]) -> CGRect {
        guard let bounds = window[kCGWindowBounds as String] as? NSDictionary else { return .zero }
        return CGRect(dictionaryRepresentation: bounds) ?? .zero
    }
}
