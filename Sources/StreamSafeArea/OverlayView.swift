import AppKit
import AVFoundation

final class OverlayView: NSView {
    private let cameraContainer = NSView()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let noCameraLabel = NSTextField(labelWithString: "摄像头不可用")
    private let frameLayer = CAShapeLayer()
    private let hoverToolbar = NSStackView()
    private let controlsButton = NSButton(title: "控制", target: nil, action: nil)
    private let lockButton = NSButton(title: "锁定", target: nil, action: nil)
    private let ratioButton = NSButton(title: "比例", target: nil, action: nil)
    private var trackingAreaRef: NSTrackingArea?

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
        let area = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        hoverToolbar.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        if !settings.clickThrough { hoverToolbar.isHidden = true }
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

        [controlsButton, lockButton, ratioButton].forEach {
            $0.bezelStyle = .rounded
            $0.setButtonType(.momentaryPushIn)
            $0.font = .systemFont(ofSize: 12, weight: .medium)
        }
        controlsButton.target = self
        controlsButton.action = #selector(openControls)
        lockButton.target = self
        lockButton.action = #selector(toggleLock)
        ratioButton.target = self
        ratioButton.action = #selector(toggleRatioLock)

        hoverToolbar.orientation = .horizontal
        hoverToolbar.spacing = 6
        hoverToolbar.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        hoverToolbar.wantsLayer = true
        hoverToolbar.layer?.cornerRadius = 10
        hoverToolbar.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        hoverToolbar.addArrangedSubview(controlsButton)
        hoverToolbar.addArrangedSubview(lockButton)
        hoverToolbar.addArrangedSubview(ratioButton)
        hoverToolbar.isHidden = true
        addSubview(hoverToolbar)

        applySettings()
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

        lockButton.title = settings.lockFrame ? "已锁定" : "锁定"
        ratioButton.title = settings.lockAspectRatio ? "比例已锁" : "比例"
        updateFramePath()
    }

    private func updateFramePath() {
        frameLayer.frame = bounds
        let inset = settings.lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        frameLayer.path = CGPath(roundedRect: rect, cornerWidth: settings.cornerRadius, cornerHeight: settings.cornerRadius, transform: nil)
    }

    @objc private func openControls() { actionHandler?.showControls() }
    @objc private func toggleLock() { actionHandler?.toggleLockFrame() }
    @objc private func toggleRatioLock() { actionHandler?.toggleAspectRatioLock() }
}
