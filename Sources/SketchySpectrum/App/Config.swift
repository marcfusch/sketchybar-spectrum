import AppKit

enum ColorMode: String { case level, frequency }

struct Config {
    // Placement
    var item = "spectrum"
    var sketchybar = ""
    var width: CGFloat = 300
    var height: CGFloat = 26
    var padding: CGFloat = 2
    var yOffset: CGFloat = 0

    // Look
    var colors = ["0xff1a0526", "0xff5c1170", "0xffa3157f", "0xffe0306a", "0xffff4a1c"].compactMap(parseColor)
    var colorMode = ColorMode.level
    var fillOpacity: CGFloat = 0.9
    var lineColor = parseColor("0xffa9b4d4")!
    var lineWidth: CGFloat = 1
    var grid = true
    var gridColor = parseColor("0x18ffffff")!

    // Analysis
    var fftSize = 4096
    var fastFftSize = 1024
    var crossover = 1000.0
    var window = WindowFunction.hann
    var scale = FrequencyScale.log
    var minFreq = 20.0
    var maxFreq = 20000.0
    var minDb = -70.0
    var maxDb = -10.0
    var tilt = 4.5
    var smoothing = 0.6

    // Behaviour
    var fps = 0
    var hideWhenSilent = true
    var silenceTimeout = 3.0

    static var defaultPath: String {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] ?? (NSHomeDirectory() + "/.config")
        return base + "/sketchybar-spectrum/config.json"
    }
}
