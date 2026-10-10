import AppKit
import Darwin

if CommandLine.arguments.contains("--self-test") {
    let code = SelfTest.run()
    fflush(stdout)
    exit(code)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
