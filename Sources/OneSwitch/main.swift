import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menü çubuğu aracı (LSUIElement gibi: Dock'ta görünmez, sadece menü çubuğunda yer alır)
app.setActivationPolicy(.accessory)
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
