import AppKit

if let command = Arguments.parse().service {
    exit(Service.run(command))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
