import AppKit
import AVFoundation

private final class OverlayToolbarButton: NSButton {
    var preferredHeight: CGFloat = 40 {
        didSet { invalidateIntrinsicContentSize() }
    }

    var horizontalPadding: CGFloat = 28 {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        return NSSize(width: base.width + horizontalPadding, height: max(preferredHeight, base.height + 14))
    }
}

private final class OverlayIconButton: NSButton {
    var preferredSize: CGFloat = 34 {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: preferredSize, height: preferredSize) }
}

final class OverlayView: NSView {
    private let cameraContainer = NSView()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let noCameraLabel = NSTextField(labelWithString: "摄像头不可用")
    private let frameLayer = CAShapeLayer()
    private let hoverToolbarContainer = NSView()
    private let hoverToolbar = NSStackView()
    private let lockButton = OverlayToolbarButton(title: "锁定位置", target: nil, action: nil)
    private let ratioButton = OverlayToolbarButton(title: "锁定比例", target: nil, action: nil)
    private let controlsButton = OverlayToolbarButton(title: "打开设置", target: nil, action: nil)
    private let hideButton = OverlayToolbarButton(title: "隐藏窗口", target: nil, action: nil)
    private let closeButton = OverlayIconButton(title: "", target: nil, action: nil)
    private var trackingAreaRef: NSTrackingArea?
    private var currentResizeCursor: NSCursor?
    private var toolbarSymbolSize: CGFloat = 16

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
        let sideInset = max(10, min(18, bounds.width * 0.028))
        let topInset = max(10, min(16, bounds.height * 0.05))
        let bottomInset = max(10, min(16, bounds.height * 0.05))
        let toolbarHeight = max(38, min(48, bounds.height * 0.16))
        let spacing = max(8, min(14, bounds.width * 0.018))
        let buttonPadding = max(18, min(30, bounds.width * 0.04))
        toolbarSymbolSize = max(15, min(20, toolbarHeight * 0.42))

        [lockButton, ratioButton, controlsButton, hideButton].forEach {
            $0.preferredHeight = toolbarHeight
            $0.horizontalPadding = buttonPadding
        }
        hoverToolbar.spacing = spacing
        refreshToolbarIcons()

        hoverToolbarContainer.frame = NSRect(
            x: sideInset,
            y: bounds.height - toolbarHeight - topInset,
            width: max(0, bounds.width - sideInset * 2),
            height: toolbarHeight
        )
        hoverToolbar.frame = NSRect(
            x: 0,
            y: 0,
            width: hoverToolbarContainer.bounds.width,
            height: hoverToolbarContainer.bounds.height
        )
        let closeSize = max(32, min(40, bounds.height * 0.14))
        closeButton.preferredSize = closeSize
        closeButton.frame = NSRect(
            x: bounds.width - sideInset - closeSize,
            y: bottomInset,
            width: closeSize,
            height: closeSize
        )
        styleCloseButton()
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
            $0.isBordered = false
            $0.setButtonType(.momentaryChange)
            $0.focusRingType = .none
            $0.contentTintColor = .white
            $0.wantsLayer = true
            $0.imagePosition = .imageOnly
            $0.imageScaling = .scaleProportionallyDown
        }

        closeButton.isBordered = false
        closeButton.setButtonType(.momentaryChange)
        closeButton.focusRingType = .none
        closeButton.wantsLayer = true
        closeButton.contentTintColor = .white
        closeButton.image = closeButtonImage()
        closeButton.imagePosition = .imageOnly

        lockButton.target = self
        lockButton.action = #selector(toggleLock)
        ratioButton.target = self
        ratioButton.action = #selector(toggleRatioLock)
        controlsButton.target = self
        controlsButton.action = #selector(openControls)
        hideButton.target = self
        hideButton.action = #selector(hideOverlay)
        closeButton.target = self
        closeButton.action = #selector(requestQuit)

        hoverToolbar.orientation = .horizontal
        hoverToolbar.distribution = .fillEqually
        hoverToolbar.alignment = .centerY
        hoverToolbar.spacing = 8
        hoverToolbar.edgeInsets = NSEdgeInsetsZero
        hoverToolbar.addArrangedSubview(lockButton)
        hoverToolbar.addArrangedSubview(ratioButton)
        hoverToolbar.addArrangedSubview(controlsButton)
        hoverToolbar.addArrangedSubview(hideButton)

        hoverToolbarContainer.addSubview(hoverToolbar)
        hoverToolbarContainer.isHidden = true
        hoverToolbarContainer.alphaValue = 0.0
        addSubview(hoverToolbarContainer)
        closeButton.isHidden = true
        closeButton.alphaValue = 0.0
        addSubview(closeButton)

        applySettings()
    }

    private func setToolbarVisible(_ visible: Bool) {
        hoverToolbarContainer.isHidden = !visible
        hoverToolbarContainer.alphaValue = visible ? 1.0 : 0.0
        closeButton.isHidden = !visible
        closeButton.alphaValue = visible ? 1.0 : 0.0
        if visible {
            bringSubviewToFront(hoverToolbarContainer)
            bringSubviewToFront(closeButton)
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
        styleCloseButton()
        refreshToolbarIcons()
        let mousePoint = convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
        setToolbarVisible(bounds.contains(mousePoint) && !settings.clickThrough)
        updateResizeCursor(for: mousePoint)
        updateFramePath()
    }

    private func style(button: OverlayToolbarButton, active: Bool) {
        button.layer?.cornerRadius = max(10, button.preferredHeight * 0.28)
        button.layer?.borderWidth = 1
        button.layer?.borderColor = (active ? NSColor.systemOrange.withAlphaComponent(0.65) : NSColor.white.withAlphaComponent(0.22)).cgColor
        button.layer?.backgroundColor = (active
            ? NSColor.systemOrange.withAlphaComponent(0.40)
            : NSColor(calibratedWhite: 0.08, alpha: 0.54)).cgColor
        button.layer?.shadowColor = NSColor.black.withAlphaComponent(0.22).cgColor
        button.layer?.shadowOpacity = 1
        button.layer?.shadowRadius = 8
        button.layer?.shadowOffset = NSSize(width: 0, height: -1)
    }

    private func styleCloseButton() {
        closeButton.layer?.cornerRadius = closeButton.bounds.height / 2
        closeButton.layer?.borderWidth = 1
        closeButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.24).cgColor
        closeButton.layer?.backgroundColor = NSColor(calibratedRed: 0.46, green: 0.13, blue: 0.13, alpha: 0.86).cgColor
        closeButton.layer?.shadowColor = NSColor.black.withAlphaComponent(0.24).cgColor
        closeButton.layer?.shadowOpacity = 1
        closeButton.layer?.shadowRadius = 8
        closeButton.layer?.shadowOffset = NSSize(width: 0, height: -1)
    }

    private func refreshToolbarIcons() {
        setToolbarIcon(
            lockButton,
            systemName: settings.lockFrame ? "lock.fill" : "lock.open",
            description: settings.lockFrame ? "已锁定位置与尺寸" : "解除锁定，可拖动与缩放"
        )
        setToolbarIcon(
            ratioButton,
            systemName: settings.lockAspectRatio ? "aspectratio.fill" : "aspectratio",
            description: settings.lockAspectRatio ? "已锁定视频比例" : "锁定视频比例"
        )
        setToolbarIcon(
            controlsButton,
            systemName: "gearshape.fill",
            description: "打开设置"
        )
        setToolbarIcon(
            hideButton,
            systemName: "eye.slash.fill",
            description: "隐藏窗口"
        )
    }

    private func setToolbarIcon(_ button: NSButton, systemName: String, description: String) {
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: description) else {
            button.image = nil
            button.toolTip = description
            return
        }
        image.isTemplate = true
        image.size = NSSize(width: toolbarSymbolSize, height: toolbarSymbolSize)
        button.image = image
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.attributedAlternateTitle = NSAttributedString(string: "")
        button.toolTip = description
    }

    private func closeButtonImage() -> NSImage? {
        guard let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭程序") else {
            return nil
        }
        image.isTemplate = true
        image.size = NSSize(width: 11, height: 11)
        return image
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
    @objc private func requestQuit() { actionHandler?.requestQuit() }
    @objc private func toggleLock() { actionHandler?.toggleLockFrame() }
    @objc private func toggleRatioLock() { actionHandler?.toggleAspectRatioLock() }
}
