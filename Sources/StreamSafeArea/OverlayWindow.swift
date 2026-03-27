import AppKit

@MainActor
final class OverlayWindow: NSPanel {
    var settings = OverlaySettings.defaults {
        didSet {
            updateBehaviors()
        }
    }

    private let overlayView: OverlayView
    private var suppressFrameSync = false
    private var observersInstalled = false

    init(settings: OverlaySettings, cameraController: CameraSessionController, actionHandler: OverlayActionHandling?) {
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
        acceptsMouseMovedEvents = true
        contentView = overlayView
        overlayView.actionHandler = actionHandler
        overlayView.cameraController = cameraController
        overlayView.settings = settings
        installWindowObserversIfNeeded()
        updateBehaviors()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        if settings.lockFrame { return }
        super.mouseDown(with: event)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        let adjusted = adjustedFrameRect(frameRect)
        super.setFrame(adjusted, display: flag)
        syncFromFrame()
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        let adjusted = adjustedFrameRect(frameRect)
        super.setFrame(adjusted, display: flag, animate: animateFlag)
        syncFromFrame()
    }

    override func setContentSize(_ size: NSSize) {
        if settings.lockFrame { return }
        super.setContentSize(size)
    }

    func apply(_ settings: OverlaySettings, preservePosition: Bool = true) {
        var next = settings
        if preservePosition {
            next.x = frame.origin.x
            next.y = frame.origin.y
            next.width = frame.size.width
            next.height = frame.size.height
        }
        self.settings = next
        suppressFrameSync = true
        let nextFrame = NSRect(x: next.x, y: next.y, width: next.width, height: next.height)
        super.setFrame(nextFrame, display: true)
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

    private func installWindowObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveOrResize(_:)),
            name: NSWindow.didMoveNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveOrResize(_:)),
            name: NSWindow.didResizeNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMoveOrResize(_:)),
            name: NSWindow.didChangeScreenNotification,
            object: self
        )
    }

    @objc private func windowDidMoveOrResize(_ notification: Notification) {
        syncFromFrame()
    }

    private func adjustedFrameRect(_ frameRect: NSRect) -> NSRect {
        guard settings.lockAspectRatio, settings.height > 0 else { return frameRect }
        let ratio = settings.width / settings.height
        let widthDelta = abs(frameRect.width - frame.width)
        let heightDelta = abs(frameRect.height - frame.height)
        if widthDelta >= heightDelta {
            let newHeight = frameRect.width / ratio
            return NSRect(x: frameRect.origin.x, y: frameRect.origin.y, width: frameRect.width, height: newHeight)
        } else {
            let newWidth = frameRect.height * ratio
            return NSRect(x: frameRect.origin.x, y: frameRect.origin.y, width: newWidth, height: frameRect.height)
        }
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
        if let screenNumber = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            settings.targetScreenID = String(screenNumber.intValue)
        }
        overlayView.settings = settings
        NotificationCenter.default.post(name: .overlayDidChange, object: nil)
    }

    private func updateBehaviors() {
        ignoresMouseEvents = settings.clickThrough
        isMovableByWindowBackground = !settings.lockFrame && !settings.clickThrough
        overlayView.settings = settings
    }
}
