import Foundation

struct Arguments {
    var demo = false
    var configPath = Config.defaultPath
    var service: Service.Command?

    static func parse(_ args: [String] = CommandLine.arguments) -> Arguments {
        var a = Arguments()
        var it = args.dropFirst().makeIterator()
        while let arg = it.next() {
            switch arg {
            case "--demo": a.demo = true
            case "--config": if let p = it.next() { a.configPath = (p as NSString).expandingTildeInPath }
            case "-h", "--help":
                let services = Service.Command.allCases.map(\.rawValue).joined(separator: " | ")
                print("usage: sketchyspectrum [--demo] [--config path]\n       sketchyspectrum \(services)")
                exit(0)
            default:
                if let cmd = Service.Command(rawValue: arg) {
                    a.service = cmd
                } else if arg.hasPrefix("--") {
                    log("ignoring unknown argument \(arg)")
                }
            }
        }
        return a
    }
}
