import AppKit
import AVFoundation

final class OverlayView: NSView {
    private let cameraContainer = NSView()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let noCameraLabel = NSTextField(labelWithString: "摄像头不可用")
    private let frameLayer = CAShapeLayer()
    private let hoverToolbarContainer = NSView()
    private let hoverToolbar = NSStackView()
    private let lockButton = NSButton(title: "锁定位置", target: nil, action: nil)
    private let ratioButton = NSButton(title: "锁定比例", target: nil, action: nil)
    private let controlsButton = NSButton(title: "打开设置", target: nil, action: nil)
    private let hideButton = NSButton(title: "隐藏窗口", target: nil, action: nil)
    private var trackingAreaRef: NSTrackingArea?
    private var currentResizeCursor: NSCursor?

    weak var actionHandler: OverlayActionHandling?

    var cameraController: CameraSessionController? {
        didSet { reconnectCameraIfNeeded() }
    }

    var settings: OverlaySettings = .defaults {
        didSet { applySettings() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupViews()
    }

    override func layout() {
        super.layout()
        cameraContainer.frame = bounds
        previewLayer.frame = cameraContainer.bounds
        noCameraLabel.frame = bounds.insetBy(dx: 16, dy: 16)
        let toolbarSize = hoverToolbar.fittingSize
        hoverToolbarContainer.frame = NSRect(x: 10, y: bounds.height - toolbarSize.height - 14, width: toolbarSize.width + 8, height: toolbarSize.height + 8)
        hoverToolbar.frame = NSRect(x: 4, y: 4, width: toolbarSize.width, height: toolbarSize.height)
        updateFramePath()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds, options: [.activeAlways, .activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        if !settings.clickThrough { setToolbarVisible(true) }
    }

    override func mouseExited(with event: NSEvent) {
        setToolbarVisible(false)
        currentResizeCursor?.pop()
        currentResizeCursor = nil
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        let inside = bounds.contains(point)
        setToolbarVisible(inside && !settings.clickThrough)
        updateResizeCursor(for: point)
    }

    private func setupViews() {
        layer?.backgroundColor = NSColor.clear.cgColor

        cameraContainer.wantsLayer = true
        cameraContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        cameraContainer.layer?.masksToBounds = true
        addSubview(cameraContainer)
        cameraContainer.layer?.addSublayer(previewLayer)

        noCameraLabel.alignment = .center
        noCameraLabel.textColor = .white.withAlphaComponent(0.9)
        noCameraLabel.font = .systemFont(ofSize: 18, weight: .medium)
        noCameraLabel.isHidden = true
        addSubview(noCameraLabel)

        frameLayer.fillColor = NSColor.clear.cgColor
        layer?.addSublayer(frameLayer)

        [lockButton, ratioButton, controlsButton, hideButton].forEach {
            $0.bezelStyle = .rounded
            $0.setButtonType(.momentaryPushIn)
            $0.font = .systemFont(ofSize: 11, weight: .semibold)
            $0.contentTintColor = .white
        }

        lockButton.target = self
        lockButton.action = #selector(toggleLock)
        ratioButton.target = self
        ratioButton.action = #selector(toggleRatioLock)
        controlsButton.target = self
        controlsButton.action = #selector(openControls)
        hideButton.target = self
        hideButton.action = #selector(hideOverlay)

        hoverToolbar.orientation = .horizontal
        hoverToolbar.spacing = 6
        hoverToolbar.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        hoverToolbar.addArrangedSubview(lockButton)
        hoverToolbar.addArrangedSubview(ratioButton)
        hoverToolbar.addArrangedSubview(controlsButton)
        hoverToolbar.addArrangedSubview(hideButton)

        hoverToolbarContainer.wantsLayer = true
        hoverToolbarContainer.layer?.cornerRadius = 10
        hoverToolbarContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.42).cgColor
        hoverToolbarContainer.layer?.borderWidth = 1
        hoverToolbarContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        hoverToolbarContainer.addSubview(hoverToolbar)
        hoverToolbarContainer.isHidden = true
        hoverToolbarContainer.alphaValue = 0.0
        addSubview(hoverToolbarContainer)

        applySettings()
    }

    private func setToolbarVisible(_ visible: Bool) {
        hoverToolbarContainer.isHidden = !visible
        hoverToolbarContainer.alphaValue = visible ? 1.0 : 0.0
        if visible {
            bringSubviewToFront(hoverToolbarContainer)
        }
    }

    private func reconnectCameraIfNeeded() {
        if settings.displayMode == .camera {
            cameraController?.attach(to: previewLayer, resolutionID: settings.cameraResolutionID)
            noCameraLabel.isHidden = cameraController?.isAvailable ?? false
        } else {
            noCameraLabel.isHidden = true
        }
    }

    private func applySettings() {
        layer?.cornerRadius = settings.cornerRadius
        layer?.masksToBounds = false

        cameraContainer.layer?.cornerRadius = settings.cornerRadius
        cameraContainer.alphaValue = CGFloat(settings.cameraAlpha)
        cameraContainer.isHidden = settings.displayMode != .camera
        cameraContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(max(0.05, 1 - settings.cameraAlpha)).cgColor

        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = settings.mirrorCamera
        }

        reconnectCameraIfNeeded()
        noCameraLabel.isHidden = !(settings.displayMode == .camera && !(cameraController?.isAvailable ?? false))

        frameLayer.lineWidth = settings.lineWidth
        frameLayer.strokeColor = NSColor.systemOrange.withAlphaComponent(settings.borderAlpha).cgColor
        frameLayer.fillColor = settings.displayMode == .frame
            ? NSColor.systemOrange.withAlphaComponent(settings.fillAlpha).cgColor
            : NSColor.clear.cgColor
        frameLayer.isHidden = settings.displayMode == .camera && !settings.showBorderInCameraMode

        style(button: lockButton, active: settings.lockFrame)
        style(button: ratioButton, active: settings.lockAspectRatio)
        style(button: controlsButton, active: false)
        style(button: hideButton, active: false)
        lockButton.title = settings.lockFrame ? "已锁定位置" : "锁定位置"
        ratioButton.title = settings.lockAspectRatio ? "已锁定比例" : "锁定比例"
        controlsButton.title = "打开设置"
        hideButton.title = "隐藏窗口"
        let mousePoint = convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
        setToolbarVisible(bounds.contains(mousePoint) && !settings.clickThrough)
        updateResizeCursor(for: mousePoint)
        updateFramePath()
    }

    private func style(button: NSButton, active: Bool) {
        button.layer?.cornerRadius = 7
        button.wantsLayer = true
        button.layer?.borderWidth = 1
        button.layer?.borderColor = (active ? NSColor.systemOrange : NSColor.white.withAlphaComponent(0.18)).cgColor
        button.layer?.backgroundColor = (active ? NSColor.systemOrange.withAlphaComponent(0.28) : NSColor.white.withAlphaComponent(0.06)).cgColor
    }

    private func updateResizeCursor(for point: NSPoint) {
        guard !settings.clickThrough, !settings.lockFrame, bounds.contains(point) else {
            currentResizeCursor?.pop()
            currentResizeCursor = nil
            return
        }

        let edge: CGFloat = 12
        let nearLeft = point.x <= edge
        let nearRight = point.x >= bounds.width - edge
        let nearBottom = point.y <= edge
        let nearTop = point.y >= bounds.height - edge

        let nextCursor: NSCursor?
        if nearLeft || nearRight || nearTop || nearBottom {
            nextCursor = .openHand
        } else {
            nextCursor = nil
        }

        if let currentResizeCursor, currentResizeCursor !== nextCursor {
            currentResizeCursor.pop()
            self.currentResizeCursor = nil
        }
        if let nextCursor, currentResizeCursor == nil {
            nextCursor.push()
            currentResizeCursor = nextCursor
        }
    }

    private func bringSubviewToFront(_ view: NSView) {
        view.removeFromSuperview()
        addSubview(view, positioned: .above, relativeTo: noCameraLabel)
    }

    private func updateFramePath() {
        frameLayer.frame = bounds
        let inset = settings.lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        frameLayer.path = CGPath(roundedRect: rect, cornerWidth: settings.cornerRadius, cornerHeight: settings.cornerRadius, transform: nil)
    }

    @objc private func openControls() { actionHandler?.showControls() }
    @objc private func hideOverlay() { actionHandler?.hideOverlay() }
    @objc private func toggleLock() { actionHandler?.toggleLockFrame() }
    @objc private func toggleRatioLock() { actionHandler?.toggleAspectRatioLock() }
}
