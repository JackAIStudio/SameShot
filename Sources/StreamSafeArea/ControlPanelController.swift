import AppKit

@MainActor
final class ControlPanelController: NSWindowController {
    private let modeControl = NSSegmentedControl(labels: ["线框", "视频"], trackingMode: .selectOne, target: nil, action: nil)
    private let resolutionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let widthField = NSTextField(string: "")
    private let heightField = NSTextField(string: "")
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
        let rect = NSRect(x: 0, y: 0, width: 440, height: 490)
        let window = NSWindow(contentRect: rect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        self.init(window: window)
        setupUI()
    }

    func bind(window: OverlayWindow, settings: OverlaySettings) {
        self.overlayWindow = window
        self.settings = settings
        push(settings: settings)
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
        if let idx = resolutionOptions.firstIndex(where: { $0.id == settings.cameraResolutionID }) {
            resolutionPopup.selectItem(at: idx)
        }
        infoLabel.stringValue = "位置: (\(Int(settings.x.rounded())), \(Int(settings.y.rounded())))  尺寸: \(Int(settings.width.rounded()))×\(Int(settings.height.rounded()))"
    }

    private func setupUI() {
        guard let window else { return }
        window.title = "StreamSafeArea 控制面板"
        let content = NSView(frame: window.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        window.contentView = content

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16)
        ])

        modeControl.target = self
        modeControl.action = #selector(changeDisplayMode)
        resolutionPopup.target = self
        resolutionPopup.action = #selector(changeResolution)
        widthField.target = self
        widthField.action = #selector(updateSize)
        heightField.target = self
        heightField.action = #selector(updateSize)
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

        stack.addArrangedSubview(label("显示模式"))
        stack.addArrangedSubview(modeControl)
        stack.addArrangedSubview(label("摄像头分辨率"))
        stack.addArrangedSubview(resolutionPopup)

        let sizeRow = NSStackView(views: [label("宽"), widthField, label("高"), heightField])
        sizeRow.spacing = 8
        stack.addArrangedSubview(sizeRow)
        stack.addArrangedSubview(label("边框透明度"))
        stack.addArrangedSubview(borderSlider)
        stack.addArrangedSubview(label("线框填充透明度"))
        stack.addArrangedSubview(fillSlider)
        stack.addArrangedSubview(label("边框粗细"))
        stack.addArrangedSubview(lineSlider)
        stack.addArrangedSubview(label("视频透明度"))
        stack.addArrangedSubview(cameraAlphaSlider)
        stack.addArrangedSubview(label("圆角"))
        stack.addArrangedSubview(cornerSlider)
        stack.addArrangedSubview(clickThroughButton)
        stack.addArrangedSubview(lockFrameButton)
        stack.addArrangedSubview(mirrorButton)
        stack.addArrangedSubview(showBorderInCameraButton)
        stack.addArrangedSubview(infoLabel)

        let row = NSStackView()
        row.spacing = 8
        row.addArrangedSubview(button("吸附右下角", #selector(snapToBottomRight)))
        row.addArrangedSubview(button("到鼠标屏幕", #selector(moveToMouseScreen)))
        row.addArrangedSubview(button("隐藏窗口", #selector(hideOverlay)))
        row.addArrangedSubview(button("显示窗口", #selector(showOverlay)))
        stack.addArrangedSubview(row)
    }

    private func label(_ text: String) -> NSTextField { NSTextField(labelWithString: text) }
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
        mutateSettings { $0.cameraResolutionID = resolutionOptions[idx].id }
    }

    @objc private func updateSize() {
        guard let width = Double(widthField.stringValue),
              let height = Double(heightField.stringValue),
              width >= 80, height >= 80 else { return }
        mutateSettings(preservePosition: false) {
            $0.width = width
            $0.height = height
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

    @objc private func hideOverlay() { overlayWindow?.orderOut(nil) }
    @objc private func showOverlay() { overlayWindow?.orderFrontRegardless() }

    private func mutateSettings(preservePosition: Bool = true, _ body: (inout OverlaySettings) -> Void) {
        guard let window = overlayWindow else { return }
        var next = window.settings
        body(&next)
        window.apply(next, preservePosition: preservePosition)
        push(settings: window.settings)
    }
}
