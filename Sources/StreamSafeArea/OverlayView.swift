import AppKit
import AVFoundation

final class OverlayView: NSView {
    private let cameraContainer = NSView()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let noCameraLabel = NSTextField(labelWithString: "摄像头不可用")
    private let frameLayer = CAShapeLayer()

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
        updateFramePath()
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
        updateFramePath()
    }

    private func updateFramePath() {
        frameLayer.frame = bounds
        let inset = settings.lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        frameLayer.path = CGPath(roundedRect: rect, cornerWidth: settings.cornerRadius, cornerHeight: settings.cornerRadius, transform: nil)
    }
}
