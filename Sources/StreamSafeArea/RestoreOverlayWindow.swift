import AppKit

@MainActor
final class RestoreOverlayWindow: NSPanel {
    private let containerView = NSView()
    private let restoreButton = NSButton(title: "显示预览", target: nil, action: nil)

    weak var actionHandler: OverlayActionHandling?

    init(actionHandler: OverlayActionHandling?) {
        let frame = NSRect(x: 0, y: 0, width: 116, height: 46)
        self.actionHandler = actionHandler
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

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
        contentView = containerView
        setupViews()
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(near overlayFrame: NSRect, on screen: NSScreen?) {
        setFrame(positionedFrame(near: overlayFrame, on: screen), display: true)
        orderFrontRegardless()
    }

    private func setupViews() {
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor

        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.bezelStyle = .rounded
        restoreButton.setButtonType(.momentaryPushIn)
        restoreButton.font = .systemFont(ofSize: 12, weight: .semibold)
        restoreButton.contentTintColor = .white
        restoreButton.target = self
        restoreButton.action = #selector(restoreOverlay)
        containerView.addSubview(restoreButton)

        NSLayoutConstraint.activate([
            restoreButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            restoreButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            restoreButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            restoreButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8)
        ])
    }

    private func positionedFrame(near overlayFrame: NSRect, on screen: NSScreen?) -> NSRect {
        let size = frame.size
        let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let x = min(max(overlayFrame.minX, visible.minX + 12), visible.maxX - size.width - 12)
        let y = min(max(overlayFrame.maxY - size.height, visible.minY + 12), visible.maxY - size.height - 12)
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    @objc private func restoreOverlay() {
        actionHandler?.showOverlay()
    }
}
