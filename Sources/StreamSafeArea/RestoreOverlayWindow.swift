import AppKit

private final class RestoreFloatingButtonView: NSView {
    var onActivate: (() -> Void)?
    var onDragStart: (() -> Void)?

    private let backgroundLayer = CAShapeLayer()
    private let stackView = NSStackView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "显示预览")
    private var trackingAreaRef: NSTrackingArea?
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?
    private var hasDragged = false
    private var cursorPushed = false
    private var isHovered = false
    private var isPressed = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override func layout() {
        super.layout()
        backgroundLayer.frame = bounds
        let radius = bounds.height / 2
        let pathRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        backgroundLayer.path = CGPath(
            roundedRect: pathRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin
        hasDragged = false
        isPressed = true
        updateAppearance()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartMouseLocation,
              let dragStartWindowOrigin,
              let window else { return }

        let currentMouseLocation = NSEvent.mouseLocation
        let deltaX = currentMouseLocation.x - dragStartMouseLocation.x
        let deltaY = currentMouseLocation.y - dragStartMouseLocation.y

        if !hasDragged, hypot(deltaX, deltaY) >= 3 {
            hasDragged = true
            onDragStart?()
            if !cursorPushed {
                NSCursor.closedHand.push()
                cursorPushed = true
            }
        }

        guard hasDragged else { return }

        let proposedOrigin = NSPoint(x: dragStartWindowOrigin.x + deltaX, y: dragStartWindowOrigin.y + deltaY)
        let targetScreen =
            NSScreen.screens.first(where: { NSMouseInRect(currentMouseLocation, $0.frame, false) }) ??
            window.screen ??
            NSScreen.main
        window.setFrameOrigin(clampedOrigin(for: window.frame.size, proposed: proposedOrigin, on: targetScreen))
    }

    override func mouseUp(with event: NSEvent) {
        if hasDragged {
            if cursorPushed {
                NSCursor.pop()
                cursorPushed = false
            }
        } else {
            onActivate?()
        }

        dragStartMouseLocation = nil
        dragStartWindowOrigin = nil
        hasDragged = false
        isPressed = false
        updateAppearance()
    }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
        backgroundLayer.lineWidth = 1
        layer?.addSublayer(backgroundLayer)

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        if let image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "显示预览") {
            image.isTemplate = true
            iconView.image = image
        }
        iconView.contentTintColor = NSColor.white.withAlphaComponent(0.9)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.92)
        titleLabel.backgroundColor = .clear

        addSubview(stackView)
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 42),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 132)
        ])

        updateAppearance()
    }

    private func updateAppearance() {
        let backgroundColor: NSColor
        if isPressed {
            backgroundColor = NSColor(calibratedRed: 0.17, green: 0.19, blue: 0.23, alpha: 0.96)
        } else if isHovered {
            backgroundColor = NSColor(calibratedRed: 0.21, green: 0.23, blue: 0.27, alpha: 0.95)
        } else {
            backgroundColor = NSColor(calibratedRed: 0.15, green: 0.17, blue: 0.20, alpha: 0.93)
        }

        backgroundLayer.fillColor = backgroundColor.cgColor
        backgroundLayer.strokeColor = NSColor.white.withAlphaComponent(isHovered ? 0.22 : 0.14).cgColor
    }

    private func clampedOrigin(for size: NSSize, proposed origin: NSPoint, on screen: NSScreen?) -> NSPoint {
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(origin: .zero, size: size)
        let inset: CGFloat = 8
        let x = min(max(origin.x, visibleFrame.minX + inset), visibleFrame.maxX - size.width - inset)
        let y = min(max(origin.y, visibleFrame.minY + inset), visibleFrame.maxY - size.height - inset)
        return NSPoint(x: x, y: y)
    }
}

@MainActor
final class RestoreOverlayWindow: NSPanel {
    private let floatingButtonView = RestoreFloatingButtonView(frame: NSRect(x: 0, y: 0, width: 132, height: 42))
    private var usesCustomPosition = false

    weak var actionHandler: OverlayActionHandling?

    init(actionHandler: OverlayActionHandling?) {
        let frame = NSRect(x: 0, y: 0, width: 132, height: 42)
        self.actionHandler = actionHandler
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        worksWhenModal = true
        isReleasedWhenClosed = false
        contentView = floatingButtonView
        floatingButtonView.autoresizingMask = [.width, .height]
        floatingButtonView.onActivate = { [weak self] in
            self?.actionHandler?.showOverlay()
        }
        floatingButtonView.onDragStart = { [weak self] in
            self?.usesCustomPosition = true
        }
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(near overlayFrame: NSRect, on screen: NSScreen?) {
        let nextFrame = usesCustomPosition ? clampedCurrentFrame(on: screen) : positionedFrame(near: overlayFrame, on: screen)
        setFrame(nextFrame, display: true)
        orderFrontRegardless()
    }

    func syncVisiblePosition(near overlayFrame: NSRect, on screen: NSScreen?) {
        guard isVisible else { return }
        let nextFrame = usesCustomPosition ? clampedCurrentFrame(on: screen) : positionedFrame(near: overlayFrame, on: screen)
        setFrame(nextFrame, display: true)
    }

    private func positionedFrame(near overlayFrame: NSRect, on screen: NSScreen?) -> NSRect {
        let size = frame.size
        let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let x = min(max(overlayFrame.minX, visible.minX + 12), visible.maxX - size.width - 12)
        let y = min(max(overlayFrame.maxY - size.height, visible.minY + 12), visible.maxY - size.height - 12)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func clampedCurrentFrame(on screen: NSScreen?) -> NSRect {
        let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
        let inset: CGFloat = 8
        let x = min(max(frame.origin.x, visible.minX + inset), visible.maxX - frame.width - inset)
        let y = min(max(frame.origin.y, visible.minY + inset), visible.maxY - frame.height - inset)
        return NSRect(x: x, y: y, width: frame.width, height: frame.height)
    }
}
