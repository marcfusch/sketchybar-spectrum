import AppKit

extension Config {
    /// Missing or invalid keys keep their default value.
    static func load(path: String) -> Config {
        var c = Config()
        guard let data = FileManager.default.contents(atPath: path) else { return c }
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.json5Allowed]),
              let d = obj as? [String: Any] else {
            log("config: \(path) is not a valid JSON object, using defaults")
            return c
        }
        var known = Set<String>()
        func value(_ k: String) -> Any? { known.insert(k); return d[k] }
        func num(_ k: String) -> Double? { (value(k) as? NSNumber)?.doubleValue }
        func str(_ k: String) -> String? { value(k) as? String }
        func bool(_ k: String) -> Bool? { value(k) as? Bool }
        func color(_ k: String) -> NSColor? { str(k).flatMap(parseColor) }

        if let v = str("item") { c.item = v }
        if let v = str("sketchybar") { c.sketchybar = v }
        if let v = num("width") { c.width = max(0, v) }
        if let v = num("height") { c.height = max(0, v) }
        if let v = num("padding") { c.padding = max(0, v) }
        if let v = num("y_offset") { c.yOffset = v }

        if let v = value("colors") as? [String], case let parsed = v.compactMap(parseColor), !parsed.isEmpty { c.colors = parsed }
        if let v = str("color_mode"), let m = ColorMode(rawValue: v) { c.colorMode = m }
        if let v = num("fill_opacity") { c.fillOpacity = min(1, max(0, v)) }
        if let v = color("line_color") { c.lineColor = v }
        if let v = num("line_width") { c.lineWidth = max(0, v) }
        if let v = bool("grid") { c.grid = v }
        if let v = color("grid_color") { c.gridColor = v }

        if let v = num("fft_size") { c.fftSize = powerOfTwo(v) }
        if let v = num("fast_fft_size") { c.fastFftSize = v <= 0 ? 0 : powerOfTwo(v) }
        if let v = num("crossover") { c.crossover = max(50, v) }
        if let v = str("scale"), let s = FrequencyScale(rawValue: v) { c.scale = s }
        if let v = str("window"), let w = WindowFunction(rawValue: v) { c.window = w }
        if let v = num("min_freq") { c.minFreq = max(10, v) }
        if let v = num("max_freq") { c.maxFreq = min(22000, max(c.minFreq * 2, v)) }
        if let v = num("min_db") { c.minDb = v }
        if let v = num("max_db") { c.maxDb = max(c.minDb + 1, v) }
        if let v = num("tilt") { c.tilt = v }
        if let v = num("smoothing") { c.smoothing = min(0.99, max(0, v > 1 ? v / 100 : v)) }

        if let v = num("fps") { c.fps = max(0, Int(v)) }
        if let v = bool("hide_when_silent") { c.hideWhenSilent = v }
        if let v = num("silence_timeout") { c.silenceTimeout = max(0.1, v) }

        for k in Set(d.keys).subtracting(known).sorted() { log("config: unknown key '\(k)', ignored") }
        return c
    }

    private static func powerOfTwo(_ v: Double) -> Int {
        Int(pow(2, log2(max(256, min(16384, v))).rounded()))
    }
}
