import AppKit
import AVFoundation

final class OverlayView: NSView {
    private let cameraContainer = NSView()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let noCameraLabel = NSTextField(labelWithString: "摄像头不可用")
    private let frameLayer = CAShapeLayer()
    private let hoverToolbar = NSStackView()
    private let passthroughButton = NSButton(title: "穿透", target: nil, action: nil)
    private let lockButton = NSButton(title: "锁定", target: nil, action: nil)
    private let ratioButton = NSButton(title: "比例", target: nil, action: nil)
    private let modeButton = NSButton(title: "视频", target: nil, action: nil)
    private let controlsButton = NSButton(title: "设置", target: nil, action: nil)
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
        hoverToolbar.setFrameOrigin(NSPoint(x: 12, y: bounds.height - hoverToolbar.fittingSize.height - 12))
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
        setToolbarVisible(true)
    }

    override func mouseExited(with event: NSEvent) {
        if !settings.clickThrough { setToolbarVisible(false) }
        currentResizeCursor?.pop()
        currentResizeCursor = nil
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        setToolbarVisible(bounds.contains(point) && !settings.clickThrough)
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

        [passthroughButton, lockButton, ratioButton, modeButton, controlsButton].forEach {
            $0.bezelStyle = .rounded
            $0.setButtonType(.momentaryPushIn)
            $0.font = .systemFont(ofSize: 11, weight: .semibold)
            $0.contentTintColor = .white
        }

        passthroughButton.target = self
        passthroughButton.action = #selector(togglePassthrough)
        lockButton.target = self
        lockButton.action = #selector(toggleLock)
        ratioButton.target = self
        ratioButton.action = #selector(toggleRatioLock)
        modeButton.target = self
        modeButton.action = #selector(toggleMode)
        controlsButton.target = self
        controlsButton.action = #selector(openControls)

        hoverToolbar.orientation = .horizontal
        hoverToolbar.spacing = 5
        hoverToolbar.edgeInsets = NSEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)
        hoverToolbar.wantsLayer = true
        hoverToolbar.layer?.cornerRadius = 9
        hoverToolbar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.42).cgColor
        hoverToolbar.addArrangedSubview(passthroughButton)
        hoverToolbar.addArrangedSubview(lockButton)
        hoverToolbar.addArrangedSubview(ratioButton)
        hoverToolbar.addArrangedSubview(modeButton)
        hoverToolbar.addArrangedSubview(controlsButton)
        hoverToolbar.isHidden = true
        addSubview(hoverToolbar)

        applySettings()
    }

    private func setToolbarVisible(_ visible: Bool) {
        hoverToolbar.isHidden = !visible
        if visible {
            bringSubviewToFront(hoverToolbar)
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

        style(button: passthroughButton, active: settings.clickThrough)
        style(button: lockButton, active: settings.lockFrame)
        style(button: ratioButton, active: settings.lockAspectRatio)
        style(button: modeButton, active: settings.displayMode == .camera)
        style(button: controlsButton, active: false)
        modeButton.title = settings.displayMode == .camera ? "线框" : "视频"
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
        if nearLeft || nearRight {
            nextCursor = .resizeLeftRight
        } else if nearTop || nearBottom {
            nextCursor = .resizeUpDown
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
        addSubview(view)
    }

    private func updateFramePath() {
        frameLayer.frame = bounds
        let inset = settings.lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        frameLayer.path = CGPath(roundedRect: rect, cornerWidth: settings.cornerRadius, cornerHeight: settings.cornerRadius, transform: nil)
    }

    @objc private func openControls() { actionHandler?.showControls() }
    @objc private func togglePassthrough() { actionHandler?.toggleClickThrough() }
    @objc private func toggleLock() { actionHandler?.toggleLockFrame() }
    @objc private func toggleRatioLock() { actionHandler?.toggleAspectRatioLock() }
    @objc private func toggleMode() { actionHandler?.toggleDisplayMode() }
}
