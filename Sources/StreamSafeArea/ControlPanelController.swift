import AppKit

final class DragHandleView: NSView {
    var title: String = "宽" {
        didSet { label.stringValue = title }
    }
    var onDragDelta: ((Double) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var dragStart: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let point = event.locationInWindow
        let dx = point.x - dragStart.x
        let dy = dragStart.y - point.y
        let dominant = abs(dx) >= abs(dy) ? dx : dy
        let rounded = Int(dominant.rounded())
        guard rounded != 0 else { return }
        onDragDelta?(Double(rounded))
        self.dragStart = point
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        NSCursor.pop()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalToConstant: 72),
            heightAnchor.constraint(equalToConstant: 36)
        ])
    }
}

@MainActor
final class ControlPanelController: NSWindowController {
    private weak var scrollViewRef: NSScrollView?
    private let modeControl = NSSegmentedControl(labels: ["线框", "视频"], trackingMode: .selectOne, target: nil, action: nil)
    private let resolutionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sourceSizeLabel = NSTextField(labelWithString: "来源分辨率：自动")
    private let widthHandle = DragHandleView(frame: .zero)
    private let heightHandle = DragHandleView(frame: .zero)
    private let widthField = NSTextField(string: "")
    private let heightField = NSTextField(string: "")
    private let ratioLockButton = NSButton(title: "未锁定", target: nil, action: nil)
    private let borderSlider = NSSlider(value: 0.9, minValue: 0.1, maxValue: 1.0, target: nil, action: nil)
    private let fillSlider = NSSlider(value: 0.08, minValue: 0.0, maxValue: 0.4, target: nil, action: nil)
    private let lineSlider = NSSlider(value: 3.0, minValue: 1.0, maxValue: 10.0, target: nil, action: nil)
    private let cameraAlphaSlider = NSSlider(value: 0.96, minValue: 0.2, maxValue: 1.0, target: nil, action: nil)
    private let cornerSlider = NSSlider(value: 18, minValue: 0, maxValue: 40, target: nil, action: nil)
    private let clickThroughButton = NSButton(checkboxWithTitle: "点击穿透", target: nil, action: nil)
    private let lockFrameButton = NSButton(checkboxWithTitle: "锁定位置与尺寸", target: nil, action: nil)
    private let mirrorButton = NSButton(checkboxWithTitle: "镜像视频", target: nil, action: nil)
    private let showBorderInCameraButton = NSButton(checkboxWithTitle: "视频模式保留边框", target: nil, action: nil)
    private let infoLabel = NSTextField(labelWithString: "")

    private weak var overlayWindow: OverlayWindow?
    private var settings = OverlaySettings.defaults
    private var resolutionOptions: [CameraResolutionOption] = [.auto]

    convenience init() {
        let rect = NSRect(x: 0, y: 0, width: 520, height: 640)
        let window = NSPanel(contentRect: rect, styleMask: [.titled, .closable, .utilityWindow, .resizable], backing: .buffered, defer: false)
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 460, height: 560)
        self.init(window: window)
        setupUI()
    }

    func bind(window: OverlayWindow, settings: OverlaySettings) {
        self.overlayWindow = window
        self.settings = settings
        push(settings: settings)
        scrollToTop()
    }

    func setResolutionOptions(_ options: [CameraResolutionOption]) {
        resolutionOptions = options
        resolutionPopup.removeAllItems()
        resolutionPopup.addItems(withTitles: options.map(\ .label))
        if let idx = options.firstIndex(where: { $0.id == settings.cameraResolutionID }) {
            resolutionPopup.selectItem(at: idx)
        } else {
            resolutionPopup.selectItem(at: 0)
        }
        updateSourceSizeLabel()
    }

    func push(settings: OverlaySettings) {
        self.settings = settings
        modeControl.selectedSegment = settings.displayMode == .frame ? 0 : 1
        widthField.stringValue = String(Int(settings.width.rounded()))
        heightField.stringValue = String(Int(settings.height.rounded()))
        borderSlider.doubleValue = settings.borderAlpha
        fillSlider.doubleValue = settings.fillAlpha
        lineSlider.doubleValue = settings.lineWidth
        cameraAlphaSlider.doubleValue = settings.cameraAlpha
        cornerSlider.doubleValue = settings.cornerRadius
        clickThroughButton.state = settings.clickThrough ? .on : .off
        lockFrameButton.state = settings.lockFrame ? .on : .off
        mirrorButton.state = settings.mirrorCamera ? .on : .off
        showBorderInCameraButton.state = settings.showBorderInCameraMode ? .on : .off
        ratioLockButton.title = settings.lockAspectRatio ? "已锁定" : "未锁定"
        ratioLockButton.toolTip = settings.lockAspectRatio ? "已锁定当前比例" : "点击锁定当前比例"
        if let idx = resolutionOptions.firstIndex(where: { $0.id == settings.cameraResolutionID }) {
            resolutionPopup.selectItem(at: idx)
        }
        updateSourceSizeLabel()
        infoLabel.stringValue = "预览尺寸：\(Int(settings.width.rounded())) × \(Int(settings.height.rounded()))"
    }

    private func updateSourceSizeLabel() {
        if let option = resolutionOptions.first(where: { $0.id == settings.cameraResolutionID }),
           let w = option.width, let h = option.height {
            sourceSizeLabel.stringValue = "来源分辨率：\(w) × \(h)" + ((option.maxFPS ?? 0) > 0 ? "  ·  ≤\(Int((option.maxFPS ?? 0).rounded()))fps" : "")
        } else {
            sourceSizeLabel.stringValue = "来源分辨率：自动"
        }
    }

    private func setupUI() {
        guard let window else { return }
        window.title = "StreamSafeArea 控制面板"

        let root = NSView(frame: window.contentView!.bounds)
        root.autoresizingMask = [.width, .height]
        window.contentView = root

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        root.addSubview(scrollView)
        self.scrollViewRef = scrollView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 980))
        scrollView.documentView = documentView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 16),
            stack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor, constant: -32),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20)
        ])

        modeControl.target = self
        modeControl.action = #selector(changeDisplayMode)
        resolutionPopup.target = self
        resolutionPopup.action = #selector(changeResolution)
        widthField.target = self
        widthField.action = #selector(updateSize)
        heightField.target = self
        heightField.action = #selector(updateSize)
        ratioLockButton.target = self
        ratioLockButton.action = #selector(toggleAspectRatioLock)
        widthHandle.title = "宽 ←→"
        heightHandle.title = "高 ←→"
        widthHandle.onDragDelta = { [weak self] delta in self?.adjustPreviewSize(delta: delta, forWidth: true) }
        heightHandle.onDragDelta = { [weak self] delta in self?.adjustPreviewSize(delta: delta, forWidth: false) }
        [borderSlider, fillSlider, lineSlider, cameraAlphaSlider, cornerSlider].forEach {
            $0.target = self
            $0.action = #selector(updateSliders)
        }
        clickThroughButton.target = self
        clickThroughButton.action = #selector(toggleClickThrough)
        lockFrameButton.target = self
        lockFrameButton.action = #selector(toggleLockFrame)
        mirrorButton.target = self
        mirrorButton.action = #selector(toggleFlags)
        showBorderInCameraButton.target = self
        showBorderInCameraButton.action = #selector(toggleFlags)

        [widthField, heightField].forEach {
            $0.alignment = .center
            $0.controlSize = .large
            $0.font = .systemFont(ofSize: 16, weight: .medium)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalToConstant: 120).isActive = true
        }
        widthField.placeholderString = "输入宽度"
        heightField.placeholderString = "输入高度"

        ratioLockButton.bezelStyle = .rounded
        ratioLockButton.controlSize = .large
        ratioLockButton.font = .systemFont(ofSize: 13, weight: .medium)

        stack.addArrangedSubview(sectionLabel("显示模式"))
        stack.addArrangedSubview(modeControl)

        stack.addArrangedSubview(sectionLabel("来源视频"))
        resolutionPopup.translatesAutoresizingMaskIntoConstraints = false
        resolutionPopup.widthAnchor.constraint(equalToConstant: 260).isActive = true
        stack.addArrangedSubview(resolutionPopup)
        stack.addArrangedSubview(sourceSizeLabel)

        stack.addArrangedSubview(sectionLabel("预览尺寸"))
        let widthRow = NSStackView()
        widthRow.orientation = .horizontal
        widthRow.alignment = .centerY
        widthRow.spacing = 10
        widthRow.addArrangedSubview(widthHandle)
        widthRow.addArrangedSubview(widthField)

        let lockRow = NSStackView()
        lockRow.orientation = .horizontal
        lockRow.alignment = .centerY
        lockRow.spacing = 10
        lockRow.addArrangedSubview(label("比例"))
        lockRow.addArrangedSubview(ratioLockButton)

        let heightRow = NSStackView()
        heightRow.orientation = .horizontal
        heightRow.alignment = .centerY
        heightRow.spacing = 10
        heightRow.addArrangedSubview(heightHandle)
        heightRow.addArrangedSubview(heightField)

        stack.addArrangedSubview(widthRow)
        stack.addArrangedSubview(lockRow)
        stack.addArrangedSubview(heightRow)
        stack.addArrangedSubview(helpLabel("左侧拖移区只负责鼠标拖动改值；右侧输入框只负责正常输入。"))

        stack.addArrangedSubview(sectionLabel("边框透明度"))
        stack.addArrangedSubview(fullWidth(borderSlider))
        stack.addArrangedSubview(sectionLabel("线框填充透明度"))
        stack.addArrangedSubview(fullWidth(fillSlider))
        stack.addArrangedSubview(sectionLabel("边框粗细"))
        stack.addArrangedSubview(fullWidth(lineSlider))
        stack.addArrangedSubview(sectionLabel("视频透明度"))
        stack.addArrangedSubview(fullWidth(cameraAlphaSlider))
        stack.addArrangedSubview(sectionLabel("圆角"))
        stack.addArrangedSubview(fullWidth(cornerSlider))

        stack.addArrangedSubview(clickThroughButton)
        stack.addArrangedSubview(lockFrameButton)
        stack.addArrangedSubview(mirrorButton)
        stack.addArrangedSubview(showBorderInCameraButton)
        stack.addArrangedSubview(infoLabel)

        let actionRow = NSStackView()
        actionRow.orientation = .horizontal
        actionRow.spacing = 8
        actionRow.addArrangedSubview(button("记住当前位置和尺寸", #selector(rememberCurrentState)))
        actionRow.addArrangedSubview(button("吸附右下角", #selector(snapToBottomRight)))
        actionRow.addArrangedSubview(button("到鼠标屏幕", #selector(moveToMouseScreen)))
        actionRow.addArrangedSubview(button("隐藏窗口", #selector(hideOverlay)))
        actionRow.addArrangedSubview(button("显示窗口", #selector(showOverlay)))
        stack.addArrangedSubview(actionRow)
    }

    private func adjustPreviewSize(delta: Double, forWidth: Bool) {
        mutateSettings(preservePosition: false) { settings in
            let rounded = Int(delta.rounded())
            guard rounded != 0 else { return }
            let step = Double(rounded)
            if settings.lockAspectRatio, settings.height > 0 {
                let ratio = settings.width / settings.height
                if forWidth {
                    let newWidth = max(80, settings.width + step)
                    settings.width = newWidth
                    settings.height = max(80, newWidth / ratio)
                } else {
                    let newHeight = max(80, settings.height + step)
                    settings.height = newHeight
                    settings.width = max(80, newHeight * ratio)
                }
            } else {
                if forWidth {
                    settings.width = max(80, settings.width + step)
                } else {
                    settings.height = max(80, settings.height + step)
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        return label
    }

    private func helpLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func label(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        return label
    }

    private func fullWidth(_ view: NSView) -> NSView {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        return view
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func changeDisplayMode() {
        mutateSettings { $0.displayMode = modeControl.selectedSegment == 1 ? .camera : .frame }
    }

    @objc private func changeResolution() {
        let idx = resolutionPopup.indexOfSelectedItem
        guard idx >= 0 && idx < resolutionOptions.count else { return }
        let option = resolutionOptions[idx]
        mutateSettings(preservePosition: false) {
            $0.cameraResolutionID = option.id
            if let w = option.width, let h = option.height {
                $0.width = Double(w)
                $0.height = Double(h)
            }
        }
    }

    @objc private func updateSize() {
        guard let width = Double(widthField.stringValue),
              let height = Double(heightField.stringValue),
              width >= 80, height >= 80 else { return }
        let widthFocused = window?.firstResponder === widthField.currentEditor()
        let heightFocused = window?.firstResponder === heightField.currentEditor()
        mutateSettings(preservePosition: false) { settings in
            if settings.lockAspectRatio, settings.height > 0 {
                let ratio = settings.width / settings.height
                if widthFocused && !heightFocused {
                    settings.width = width
                    settings.height = max(80, width / ratio)
                } else if heightFocused && !widthFocused {
                    settings.height = height
                    settings.width = max(80, height * ratio)
                } else {
                    settings.width = width
                    settings.height = max(80, width / ratio)
                }
            } else {
                settings.width = width
                settings.height = height
            }
        }
    }

    @objc private func updateSliders() {
        mutateSettings {
            $0.borderAlpha = borderSlider.doubleValue
            $0.fillAlpha = fillSlider.doubleValue
            $0.lineWidth = lineSlider.doubleValue
            $0.cameraAlpha = cameraAlphaSlider.doubleValue
            $0.cornerRadius = cornerSlider.doubleValue
        }
    }

    @objc private func toggleClickThrough() {
        mutateSettings { $0.clickThrough = (clickThroughButton.state == .on) }
    }

    @objc private func toggleLockFrame() {
        mutateSettings { $0.lockFrame = (lockFrameButton.state == .on) }
    }

    @objc private func toggleAspectRatioLock() {
        mutateSettings { $0.lockAspectRatio.toggle() }
    }

    @objc private func toggleFlags() {
        mutateSettings {
            $0.mirrorCamera = (mirrorButton.state == .on)
            $0.showBorderInCameraMode = (showBorderInCameraButton.state == .on)
        }
    }

    @objc private func snapToBottomRight() {
        guard let window = overlayWindow, let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let rect = NSRect(x: visible.maxX - settings.width - 40, y: visible.minY + 40, width: settings.width, height: settings.height)
        window.move(to: rect)
        push(settings: window.settings)
    }

    @objc private func moveToMouseScreen() {
        guard let window = overlayWindow else { return }
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let rect = NSRect(
            x: min(max(mouse.x - settings.width / 2, visible.minX + 20), visible.maxX - settings.width - 20),
            y: min(max(mouse.y - settings.height / 2, visible.minY + 20), visible.maxY - settings.height - 20),
            width: settings.width,
            height: settings.height
        )
        var next = settings
        next.targetScreenID = AppDelegate.screenID(for: screen)
        window.apply(next)
        window.move(to: rect)
        push(settings: window.settings)
    }

    @objc private func rememberCurrentState() {
        guard let window = overlayWindow else { return }
        var saved = window.settings
        if let screenNumber = window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            saved.targetScreenID = String(screenNumber.intValue)
        }
        SettingsStore.shared.save(saved)
        push(settings: saved)
    }

    @objc private func hideOverlay() { overlayWindow?.orderOut(nil) }
    @objc private func showOverlay() { overlayWindow?.orderFrontRegardless() }

    private func mutateSettings(preservePosition: Bool = true, _ body: (inout OverlaySettings) -> Void) {
        guard let window = overlayWindow else { return }
        var next = window.settings
        body(&next)
        window.apply(next, preservePosition: preservePosition)
        push(settings: window.settings)
    }

    func scrollToTop() {
        guard let scrollView = scrollViewRef else { return }
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}
