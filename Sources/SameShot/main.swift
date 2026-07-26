import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)

if Bundle.main.bundleURL.pathExtension.lowercased() != "app" {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "请运行 SameShot App"
    alert.informativeText = """
    当前启动的是 Swift Package 可执行程序，不具备完整的 App 身份和摄像头权限配置。

    请停止运行，打开 SameShot.xcodeproj，并在 Xcode 顶部选择“SameShot App”Scheme 后重新运行。
    """
    alert.addButton(withTitle: "知道了")
    app.activate(ignoringOtherApps: true)
    alert.runModal()
} else {
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
