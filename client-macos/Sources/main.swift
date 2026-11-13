import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
if CommandLine.arguments.contains("--ops") {
    DispatchQueue.main.async { delegate.openOpsWindow() }
}
app.run()
