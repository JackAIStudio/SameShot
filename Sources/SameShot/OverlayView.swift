import AppKit
import AVFoundation

final class OverlayView: NSView {
    private let cameraContainer = NSView()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let cameraStatusContainer = NSStackView()
    private let noCameraLabel = NSTextField(wrappingLabelWithString: "")
    private let cameraSettingsButton = NSButton(title: "打开摄像头权限设置", target: nil, action: nil)
    private var trackingAreaRef: NSTrackingArea?
    private var currentResizeCursor: NSCursor?

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
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds, options: [.activeAlways, .activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseExited(with event: NSEvent) {
        currentResizeCursor?.pop()
        currentResizeCursor = nil
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
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
        noCameraLabel.maximumNumberOfLines = 0

        cameraSettingsButton.bezelStyle = .rounded
        cameraSettingsButton.controlSize = .large
        cameraSettingsButton.target = self
        cameraSettingsButton.action = #selector(openCameraPrivacySettings)

        cameraStatusContainer.orientation = .vertical
        cameraStatusContainer.alignment = .centerX
        cameraStatusContainer.spacing = 12
        cameraStatusContainer.translatesAutoresizingMaskIntoConstraints = false
        cameraStatusContainer.addArrangedSubview(noCameraLabel)
        cameraStatusContainer.addArrangedSubview(cameraSettingsButton)
        addSubview(cameraStatusContainer)
        NSLayoutConstraint.activate([
            cameraStatusContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            cameraStatusContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            cameraStatusContainer.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            cameraStatusContainer.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cameraAvailabilityDidChange),
            name: .cameraAvailabilityDidChange,
            object: nil
        )

        applySettings()
    }

    private func reconnectCameraIfNeeded() {
        cameraController?.attach(to: previewLayer, resolutionID: settings.cameraResolutionID)
        updateCameraStatus()
    }

    private func updateCameraStatus() {
        switch cameraController?.availability ?? .unavailable {
        case .available:
            cameraStatusContainer.isHidden = true
        case .requestingPermission:
            cameraStatusContainer.isHidden = false
            noCameraLabel.stringValue = "正在请求摄像头权限…"
            cameraSettingsButton.isHidden = true
        case .permissionDenied:
            cameraStatusContainer.isHidden = false
            noCameraLabel.stringValue = "需要摄像头权限才能显示实时预览"
            cameraSettingsButton.isHidden = false
        case .unavailable:
            cameraStatusContainer.isHidden = false
            noCameraLabel.stringValue = "未检测到可用摄像头"
            cameraSettingsButton.isHidden = true
        }
    }

    private func applySettings() {
        layer?.cornerRadius = settings.cornerRadius
        layer?.masksToBounds = false

        cameraContainer.layer?.cornerRadius = settings.cornerRadius

        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = settings.mirrorCamera
        }

        reconnectCameraIfNeeded()
    }

    @objc private func cameraAvailabilityDidChange() {
        reconnectCameraIfNeeded()
    }

    @objc private func openCameraPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    private func updateResizeCursor(for point: NSPoint) {
        guard bounds.contains(point) else {
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
}
