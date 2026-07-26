import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, OverlayVisibilityHandling {
    private var window: OverlayWindow!
    private var restoreWindow: RestoreOverlayWindow!
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

        window = OverlayWindow(settings: settings, cameraController: cameraController)
        restoreWindow = RestoreOverlayWindow(actionHandler: self)
        window.orderFrontRegardless()
        panelController.bind(window: window, settings: settings, actionHandler: self)
        panelController.setResolutionOptions(cameraController.availableResolutions)
        buildMenu()
        buildStatusItem()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncWindowState),
            name: .overlayDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncCameraState),
            name: .cameraAvailabilityDidChange,
            object: cameraController
        )

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func syncWindowState() {
        settings = window.settings
        panelController.push(settings: settings)
        scheduleAutosave()
        if restoreWindow.isVisible {
            restoreWindow.syncVisiblePosition(near: window.frame, on: currentScreen())
        }
    }

    @objc private func syncCameraState() {
        cameraController.refreshAvailableResolutions()
        panelController.setResolutionOptions(cameraController.availableResolutions)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard window != nil else { return }
        cameraController.refreshAvailableResolutions()
        panelController.setResolutionOptions(cameraController.availableResolutions)
    }

    private func persistCurrentWindowState() {
        autosaveTask?.cancel()
        settings = window.settings
        if let screenNumber = window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            settings.targetScreenID = String(screenNumber.intValue)
        }
        settings.lastSavedAt = Date().timeIntervalSince1970
        SettingsStore.shared.save(settings)
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.persistCurrentWindowState()
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
        appMenu.addItem(withTitle: "切换锁定视频比例", action: #selector(toggleAspectRatioLock), keyEquivalent: "r")
        appMenu.addItem(withTitle: "吸附到右下角", action: #selector(snapToBottomRight), keyEquivalent: "b")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 SameShot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = mainMenu
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = nil
        item.isVisible = true
        item.button?.toolTip = "SameShot"
        item.button?.setAccessibilityLabel("SameShot")
        item.button?.image = Self.statusBarImage()
        item.button?.imagePosition = .imageOnly
        item.button?.title = ""
        let menu = NSMenu()
        menu.addItem(withTitle: "显示控制面板", action: #selector(showControls), keyEquivalent: "")
        menu.addItem(withTitle: "切换锁定视频比例", action: #selector(toggleAspectRatioLock), keyEquivalent: "")
        menu.addItem(withTitle: "吸附到右下角", action: #selector(snapToBottomRight), keyEquivalent: "")
        menu.addItem(withTitle: "移动到鼠标所在屏幕", action: #selector(moveOverlayToMouseScreen), keyEquivalent: "")
        menu.addItem(withTitle: "隐藏悬浮窗", action: #selector(hideOverlay), keyEquivalent: "")
        menu.addItem(withTitle: "显示悬浮窗", action: #selector(showOverlay), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出 SameShot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        item.menu = menu
        statusItem = item
    }

    private static func statusBarImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSGraphicsContext.current?.shouldAntialias = true
            NSColor.black.setStroke()

            let screen = NSBezierPath(
                roundedRect: NSRect(x: 1.5, y: 2.75, width: 15, height: 12.5),
                xRadius: 2.7,
                yRadius: 2.7
            )
            screen.lineWidth = 1.8
            screen.stroke()

            let pictureInPicture = NSBezierPath(
                roundedRect: NSRect(x: 9.25, y: 4.5, width: 5.5, height: 4.5),
                xRadius: 1.1,
                yRadius: 1.1
            )
            pictureInPicture.lineWidth = 1.6
            pictureInPicture.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc func showControls() {
        panelController.showWindow(nil)
        panelController.window?.orderFrontRegardless()
        panelController.scrollToTop()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showOverlay() {
        restoreWindow.orderOut(nil)
        window.orderFrontRegardless()
    }

    @objc func hideOverlay() {
        restoreWindow.show(near: window.frame, on: currentScreen())
        window.orderOut(nil)
    }

    @objc func toggleAspectRatioLock() {
        var next = window.settings
        next.lockAspectRatio.toggle()
        apply(next)
    }

    @objc private func snapToBottomRight() {
        guard let screen = currentScreen() else { return }
        let visible = screen.visibleFrame
        let width = CGFloat(window.settings.width)
        let height = CGFloat(window.settings.height)
        let rect = NSRect(x: visible.maxX - width - 40, y: visible.minY + 40, width: width, height: height)
        window.move(to: rect)
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        persistCurrentWindowState()
    }

    static func screenID(for screen: NSScreen) -> String? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { String($0.intValue) }
    }
}
