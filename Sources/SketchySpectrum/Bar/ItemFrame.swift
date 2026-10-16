import AppKit

enum ItemFrame {
    /// Frame of the item in Cocoa screen coordinates, nil when it is missing or hidden.
    /// SketchyBar reports global coordinates with a top left origin.
    static func of(_ item: String, sketchybar: String) -> CGRect? {
        guard let info = SketchyBar.query(item, sketchybar: sketchybar) else { return nil }
        if let geometry = info["geometry"] as? [String: Any], geometry["drawing"] as? String == "off" { return nil }
        guard let rects = info["bounding_rects"] as? [String: Any],
              let key = rects.keys.sorted().first,
              let rect = rects[key] as? [String: Any],
              let origin = rect["origin"] as? [Double], origin.count == 2,
              let size = rect["size"] as? [Double], size.count == 2,
              size[0] > 0, size[1] > 0 else { return nil }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: origin[0], y: primaryHeight - origin[1] - size[1], width: size[0], height: size[1])
    }
}
