import AppKit
import ServiceManagement

// `just uninstall` runs this before deleting the app: only the app itself can drop its login item.
if CommandLine.arguments.contains("--unregister-login") {
    do { try SMAppService.mainApp.unregister() } catch { FileHandle.standardError.write(Data("\(error)\n".utf8)) }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
