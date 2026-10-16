import AppKit

/// `0xAARRGGBB` / `0xRRGGBB` like SketchyBar, or `#RRGGBB` / `#RRGGBBAA` like CSS.
func parseColor(_ s: String) -> NSColor? {
    var hex = s.trimmingCharacters(in: .whitespaces).lowercased()
    let argb = hex.hasPrefix("0x")
    if argb { hex.removeFirst(2) } else if hex.hasPrefix("#") { hex.removeFirst() }
    guard let v = UInt32(hex, radix: 16) else { return nil }

    let a, r, g, b: UInt32
    switch hex.count {
    case 6: (a, r, g, b) = (255, v >> 16 & 255, v >> 8 & 255, v & 255)
    case 8 where argb: (a, r, g, b) = (v >> 24, v >> 16 & 255, v >> 8 & 255, v & 255)
    case 8: (r, g, b, a) = (v >> 24, v >> 16 & 255, v >> 8 & 255, v & 255)
    default: return nil
    }
    return NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
}
