import AppKit

@MainActor
final class OverlayWindow: NSPanel {
    var settings = OverlaySettings.defaults {
        didSet {
            persistFrame()
            updateBehaviors()
        }
    }

    private let overlayView: OverlayView
    private var suppressFrameSync = false

    init(settings: OverlaySettings, cameraController: CameraSessionController) {
        let rect = NSRect(x: settings.x, y: settings.y, width: settings.width, height: settings.height)
        overlayView = OverlayView(frame: rect)
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        self.settings = settings
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        contentView = overlayView
        overlayView.cameraController = cameraController
        overlayView.settings = settings
        updateBehaviors()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        if settings.lockFrame { return }
        super.mouseDown(with: event)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        syncFromFrame()
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: flag, animate: animateFlag)
        syncFromFrame()
    }

    override func setContentSize(_ size: NSSize) {
        if settings.lockFrame { return }
        super.setContentSize(size)
    }

    func apply(_ settings: OverlaySettings, preservePosition: Bool = true) {
        var next = settings
        if preservePosition {
            next.x = self.settings.x
            next.y = self.settings.y
            next.width = self.settings.width
            next.height = self.settings.height
        }
        self.settings = next
        suppressFrameSync = true
        let frame = NSRect(x: next.x, y: next.y, width: next.width, height: next.height)
        super.setFrame(frame, display: true)
        suppressFrameSync = false
        overlayView.settings = next
        orderFrontRegardless()
    }

    func move(to rect: NSRect) {
        var next = settings
        next.x = rect.origin.x
        next.y = rect.origin.y
        next.width = rect.width
        next.height = rect.height
        apply(next, preservePosition: false)
    }

    private func syncFromFrame() {
        guard !suppressFrameSync else { return }
        if settings.lockFrame {
            suppressFrameSync = true
            let locked = NSRect(x: settings.x, y: settings.y, width: settings.width, height: settings.height)
            super.setFrame(locked, display: true)
            suppressFrameSync = false
            return
        }
        settings.x = frame.origin.x
        settings.y = frame.origin.y
        settings.width = frame.size.width
        settings.height = frame.size.height
        overlayView.settings = settings
        NotificationCenter.default.post(name: .overlayDidChange, object: nil)
    }

    private func persistFrame() {
        SettingsStore.shared.save(settings)
    }

    private func updateBehaviors() {
        ignoresMouseEvents = settings.clickThrough
        isMovableByWindowBackground = !settings.lockFrame && !settings.clickThrough
        overlayView.settings = settings
    }
}
