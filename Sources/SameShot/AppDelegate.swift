import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, OverlayVisibilityHandling {
    private var window: OverlayWindow!
    private var restoreWindow: RestoreOverlayWindow!
    private var settings = SettingsStore.shared.load()
    private let panelController = ControlPanelController()
    private let cameraController = CameraSessionController()
    private var statusItem: NSStatusItem?
    private var overlayVisibilityMenuItems: [NSMenuItem] = []
    private var autosaveTask: DispatchWorkItem?
    private let autosaveDelay: TimeInterval = 0.45

    func applicationDidFinishLaunching(_ notification: Notification) {
        let resolved = resolveInitialSettings(settings)
        cameraController.refreshAvailableResolutions()
        settings = sanitizedCameraSettings(resolved)

        window = OverlayWindow(settings: settings, cameraController: cameraController)
        restoreWindow = RestoreOverlayWindow(actionHandler: self)
        window.orderFrontRegardless()
        panelController.bind(
            window: window,
            settings: settings,
            cameraController: cameraController
        )
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
        let currentSettings = window.settings
        let sanitizedSettings = sanitizedCameraSettings(currentSettings)
        if sanitizedSettings.cameraResolutionID != currentSettings.cameraResolutionID ||
            sanitizedSettings.cameraFrameRate != currentSettings.cameraFrameRate {
            window.apply(sanitizedSettings)
        }
        panelController.setResolutionOptions(cameraController.availableResolutions)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard window != nil else { return }
        cameraController.refreshAvailableResolutions()
        let currentSettings = window.settings
        let sanitizedSettings = sanitizedCameraSettings(currentSettings)
        if sanitizedSettings.cameraResolutionID != currentSettings.cameraResolutionID ||
            sanitizedSettings.cameraFrameRate != currentSettings.cameraFrameRate {
            window.apply(sanitizedSettings)
        }
        panelController.setResolutionOptions(cameraController.availableResolutions)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControls()
        return false
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
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            updated.targetScreenID = Self.screenID(for: screen)
            updated.x = visible.maxX - updated.width - 40
            updated.y = visible.minY + 40
        }
        return updated
    }

    private func sanitizedCameraSettings(_ current: OverlaySettings) -> OverlaySettings {
        var updated = current
        guard current.cameraResolutionID != CameraResolutionOption.auto.id else {
            updated.cameraFrameRate = nil
            return updated
        }
        guard let option = cameraController.availableResolutions.first(where: { $0.id == current.cameraResolutionID }) else {
            updated.cameraResolutionID = CameraResolutionOption.auto.id
            updated.cameraFrameRate = nil
            return updated
        }
        if let frameRate = current.cameraFrameRate,
           let matchingFrameRate = option.matchingFrameRate(for: frameRate) {
            updated.cameraFrameRate = matchingFrameRate
        } else {
            updated.cameraFrameRate = option.preferredFrameRate
        }
        return updated
    }

    private func buildMenu() {
        overlayVisibilityMenuItems.removeAll()
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(menuItem("控制面板", action: #selector(showControls), keyEquivalent: ","))
        let visibilityItem = menuItem("隐藏画中画", action: #selector(toggleOverlayVisibility))
        appMenu.addItem(visibilityItem)
        overlayVisibilityMenuItems.append(visibilityItem)
        appMenu.addItem(menuItem("重置画中画位置", action: #selector(resetOverlayPosition)))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(menuItem("退出 SameShot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q", target: NSApp))
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
        menu.addItem(menuItem("显示控制面板", action: #selector(showControls)))
        let visibilityItem = menuItem("隐藏画中画", action: #selector(toggleOverlayVisibility))
        menu.addItem(visibilityItem)
        overlayVisibilityMenuItems.append(visibilityItem)
        menu.addItem(menuItem("重置画中画位置", action: #selector(resetOverlayPosition)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem("退出 SameShot", action: #selector(NSApplication.terminate(_:)), target: NSApp))
        item.menu = menu
        statusItem = item
        updateOverlayVisibilityMenuTitles()
    }

    private func menuItem(
        _ title: String,
        action: Selector,
        keyEquivalent: String = "",
        target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target ?? self
        return item
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
        updateOverlayVisibilityMenuTitles()
    }

    @objc func hideOverlay() {
        restoreWindow.show(near: window.frame, on: currentScreen())
        window.orderOut(nil)
        updateOverlayVisibilityMenuTitles()
    }

    @objc private func toggleOverlayVisibility() {
        window.isVisible ? hideOverlay() : showOverlay()
    }

    @objc private func resetOverlayPosition() {
        let mouse = NSEvent.mouseLocation
        guard let screen =
            NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ??
            NSScreen.main else {
            return
        }
        let visible = screen.visibleFrame
        let width = CGFloat(window.settings.width)
        let height = CGFloat(window.settings.height)
        let rect = NSRect(x: visible.maxX - width - 40, y: visible.minY + 40, width: width, height: height)
        window.move(to: rect)
        var next = window.settings
        next.targetScreenID = Self.screenID(for: screen)
        apply(next)
        showOverlay()
    }

    private func updateOverlayVisibilityMenuTitles() {
        let title = window?.isVisible == true ? "隐藏画中画" : "显示画中画"
        overlayVisibilityMenuItems.forEach { $0.title = title }
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
