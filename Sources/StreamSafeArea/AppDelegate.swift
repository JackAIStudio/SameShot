import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, OverlayActionHandling {
    private var lastPersistedSettings = OverlaySettings.defaults
    private var window: OverlayWindow!
    private var settings = SettingsStore.shared.load()
    private let panelController = ControlPanelController()
    private let cameraController = CameraSessionController()
    private var statusItem: NSStatusItem?
    private var autosaveTask: DispatchWorkItem?
    private let autosaveDelay: TimeInterval = 0.45

    func applicationDidFinishLaunching(_ notification: Notification) {
        let resolved = resolveInitialSettings(settings)
        settings = resolved
        cameraController.refreshAvailableResolutions()
        if !cameraController.availableResolutions.contains(where: { $0.id == settings.cameraResolutionID }) {
            settings.cameraResolutionID = CameraResolutionOption.auto.id
        }

        lastPersistedSettings = settings
        window = OverlayWindow(settings: settings, cameraController: cameraController, actionHandler: self)
        window.orderFrontRegardless()
        panelController.bind(window: window, settings: settings)
        panelController.setResolutionOptions(cameraController.availableResolutions)
        panelController.updateDebug(current: settings, saved: lastPersistedSettings)
        buildMenu()
        buildStatusItem()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncWindowState),
            name: .overlayDidChange,
            object: nil
        )

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func syncWindowState() {
        settings = window.settings
        panelController.push(settings: settings)
        scheduleAutosave()
        panelController.updateDebug(current: settings, saved: lastPersistedSettings)
    }

    func rememberCurrentWindowState() {
        autosaveTask?.cancel()
        settings = window.settings
        if let screenNumber = window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            settings.targetScreenID = String(screenNumber.intValue)
        }
        settings.lastSavedAt = Date().timeIntervalSince1970
        lastPersistedSettings = settings
        SettingsStore.shared.save(settings)
        panelController.updateDebug(current: settings, saved: settings)
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.rememberCurrentWindowState()
        }
        autosaveTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autosaveDelay, execute: work)
    }

    private func resolveInitialSettings(_ current: OverlaySettings) -> OverlaySettings {
        var updated = current
        if let targetID = current.targetScreenID,
           let screen = NSScreen.screens.first(where: { Self.screenID(for: $0) == targetID }) {
            let visible = screen.visibleFrame
            if !visible.contains(NSPoint(x: current.x, y: current.y)) {
                updated.x = visible.maxX - current.width - 40
                updated.y = visible.minY + 40
            }
            return updated
        }
        if let screen = NSScreen.screens.last {
            let visible = screen.visibleFrame
            updated.targetScreenID = Self.screenID(for: screen)
            updated.width = max(updated.width, 700)
            updated.height = max(updated.height, 420)
            updated.x = visible.minX + 80
            updated.y = visible.maxY - updated.height - 120
        }
        return updated
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "控制面板", action: #selector(showControls), keyEquivalent: ",")
        appMenu.addItem(withTitle: "切换点击穿透", action: #selector(toggleClickThrough), keyEquivalent: "t")
        appMenu.addItem(withTitle: "切换锁定位置与尺寸", action: #selector(toggleLockFrame), keyEquivalent: "l")
        appMenu.addItem(withTitle: "切换锁定视频比例", action: #selector(toggleAspectRatioLock), keyEquivalent: "r")
        appMenu.addItem(withTitle: "吸附到右下角", action: #selector(snapToBottomRight), keyEquivalent: "b")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 StreamSafeArea", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = mainMenu
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "SSA"
        item.button?.toolTip = "StreamSafeArea"
        let menu = NSMenu()
        menu.addItem(withTitle: "显示控制面板", action: #selector(showControls), keyEquivalent: "")
        menu.addItem(withTitle: "切到线框模式", action: #selector(switchToFrameMode), keyEquivalent: "")
        menu.addItem(withTitle: "切到视频模式", action: #selector(switchToCameraMode), keyEquivalent: "")
        menu.addItem(withTitle: "切换点击穿透", action: #selector(toggleClickThrough), keyEquivalent: "")
        menu.addItem(withTitle: "切换锁定位置与尺寸", action: #selector(toggleLockFrame), keyEquivalent: "")
        menu.addItem(withTitle: "切换锁定视频比例", action: #selector(toggleAspectRatioLock), keyEquivalent: "")
        menu.addItem(withTitle: "吸附到右下角", action: #selector(snapToBottomRight), keyEquivalent: "")
        menu.addItem(withTitle: "移动到鼠标所在屏幕", action: #selector(moveOverlayToMouseScreen), keyEquivalent: "")
        menu.addItem(withTitle: "隐藏悬浮窗", action: #selector(hideOverlay), keyEquivalent: "")
        menu.addItem(withTitle: "显示悬浮窗", action: #selector(showOverlay), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出 StreamSafeArea", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        item.menu = menu
        statusItem = item
    }

    @objc func showControls() {
        panelController.showWindow(nil)
        panelController.window?.orderFrontRegardless()
        panelController.scrollToTop()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showOverlay() { window.orderFrontRegardless() }
    @objc private func hideOverlay() { window.orderOut(nil) }

    @objc private func switchToFrameMode() {
        var next = window.settings
        next.displayMode = .frame
        apply(next)
    }

    @objc private func switchToCameraMode() {
        var next = window.settings
        next.displayMode = .camera
        apply(next)
    }

    @objc func toggleClickThrough() {
        var next = window.settings
        next.clickThrough.toggle()
        apply(next)
    }

    @objc func toggleDisplayMode() {
        var next = window.settings
        next.displayMode = next.displayMode == .frame ? .camera : .frame
        apply(next)
    }

    @objc func toggleLockFrame() {
        var next = window.settings
        next.lockFrame.toggle()
        apply(next)
    }

    @objc func toggleAspectRatioLock() {
        var next = window.settings
        next.lockAspectRatio.toggle()
        apply(next)
    }

    func currentSettings() -> OverlaySettings {
        window.settings
    }

    @objc private func snapToBottomRight() {
        guard let screen = currentScreen() else { return }
        let visible = screen.visibleFrame
        let width = CGFloat(window.settings.width)
        let height = CGFloat(window.settings.height)
        let rect = NSRect(x: visible.maxX - width - 40, y: visible.minY + 40, width: width, height: height)
        window.move(to: rect)
        syncWindowState()
    }

    @objc private func moveOverlayToMouseScreen() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        var next = window.settings
        next.targetScreenID = Self.screenID(for: screen)
        apply(next)
        let visible = screen.visibleFrame
        let width = CGFloat(window.settings.width)
        let height = CGFloat(window.settings.height)
        let x = min(max(mouse.x - width / 2, visible.minX + 20), visible.maxX - width - 20)
        let y = min(max(mouse.y - height / 2, visible.minY + 20), visible.maxY - height - 20)
        let rect = NSRect(x: x, y: y, width: width, height: height)
        window.move(to: rect)
        syncWindowState()
        showOverlay()
    }

    private func currentScreen() -> NSScreen? {
        if let id = window.settings.targetScreenID {
            return NSScreen.screens.first(where: { Self.screenID(for: $0) == id })
        }
        return window.screen ?? NSScreen.main
    }

    private func apply(_ newSettings: OverlaySettings) {
        window.apply(newSettings)
        syncWindowState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        rememberCurrentWindowState()
    }

    static func screenID(for screen: NSScreen) -> String? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { String($0.intValue) }
    }
}
