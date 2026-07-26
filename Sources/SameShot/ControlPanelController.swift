import AppKit

@MainActor
final class ControlPanelController: NSWindowController {
    private weak var scrollViewRef: NSScrollView?

    private let captureQualityPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sourceInfoLabel = NSTextField(wrappingLabelWithString: "")
    private let captureHintLabel = NSTextField(wrappingLabelWithString: "")

    private let sizePresetControl = NSSegmentedControl(
        labels: ["小 240", "中 320", "大 480", "自定义"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let customSizeStack = NSStackView()
    private weak var customSizeRow: NSView?
    private let widthField = NSTextField(string: "")
    private let heightField = NSTextField(string: "")
    private let sizeInfoLabel = NSTextField(wrappingLabelWithString: "")
    private let aspectRatioPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let scalingModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let scalingHintLabel = NSTextField(wrappingLabelWithString: "")

    private let cornerSlider = NSSlider(value: 18, minValue: 0, maxValue: 40, target: nil, action: nil)
    private let mirrorButton = NSButton(checkboxWithTitle: "镜像画面", target: nil, action: nil)

    private weak var overlayWindow: OverlayWindow?
    private weak var cameraController: CameraSessionController?
    private var settings = OverlaySettings.defaults
    private var resolutionOptions: [CameraResolutionOption] = [.auto]

    convenience init() {
        let rect = NSRect(x: 0, y: 0, width: 520, height: 600)
        let window = NSPanel(
            contentRect: rect,
            styleMask: [.titled, .closable, .utilityWindow, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 460, height: 500)
        self.init(window: window)
        setupUI()
    }

    func bind(
        window: OverlayWindow,
        settings: OverlaySettings,
        cameraController: CameraSessionController
    ) {
        overlayWindow = window
        self.cameraController = cameraController
        push(settings: settings)
        scrollToTop()
    }

    func setResolutionOptions(_ options: [CameraResolutionOption]) {
        resolutionOptions = options
        reloadCaptureQualityMenu()
        push(settings: settings)
    }

    func push(settings: OverlaySettings) {
        self.settings = settings

        selectCurrentCaptureQuality()
        updateCaptureHint()
        updateSourceInfo()

        widthField.stringValue = String(Int(settings.width.rounded()))
        heightField.stringValue = String(Int(settings.height.rounded()))
        updateSizePresetSelection()
        updateSizeInfo()

        if let index = OverlayAspectRatio.allCases.firstIndex(of: settings.aspectRatio) {
            aspectRatioPopup.selectItem(at: index)
        }
        if let index = VideoScalingMode.allCases.firstIndex(of: settings.videoScalingMode) {
            scalingModePopup.selectItem(at: index)
        }
        updateScalingHint()

        cornerSlider.doubleValue = settings.cornerRadius
        mirrorButton.state = settings.mirrorCamera ? .on : .off
    }

    private var displayedCaptureQualityOptions: [CameraResolutionOption] {
        var options: [CameraResolutionOption] = [.auto]
        let dimensions: [(Int32, Int32)] = [
            (640, 480),
            (1280, 720),
            (1920, 1080)
        ]
        for (width, height) in dimensions {
            if let option = resolutionOptions.first(where: {
                $0.width == width && $0.height == height
            }) {
                options.append(option)
            }
        }
        return options
    }

    private func reloadCaptureQualityMenu() {
        captureQualityPopup.removeAllItems()
        captureQualityPopup.addItems(withTitles: displayedCaptureQualityOptions.map(Self.captureQualityTitle))
        selectCurrentCaptureQuality()
    }

    private func selectCurrentCaptureQuality() {
        let index = displayedCaptureQualityOptions.firstIndex {
            $0.id == settings.cameraResolutionID
        } ?? 0
        captureQualityPopup.selectItem(at: index)
    }

    private func selectedCaptureQualityOption() -> CameraResolutionOption? {
        let index = captureQualityPopup.indexOfSelectedItem
        guard index >= 0, index < displayedCaptureQualityOptions.count else { return nil }
        return displayedCaptureQualityOptions[index]
    }

    private func updateSourceInfo() {
        if let info = cameraController?.activeFormatInfo {
            let frameRateText = info.frameRate.map { " · \(Self.frameRateTitle($0))" } ?? ""
            sourceInfoLabel.stringValue = "当前输入：\(info.width) × \(info.height)\(frameRateText)"
            return
        }

        switch cameraController?.availability ?? .unavailable {
        case .requestingPermission:
            sourceInfoLabel.stringValue = "当前输入：正在请求摄像头权限…"
        case .permissionDenied:
            sourceInfoLabel.stringValue = "当前输入：尚未获得摄像头权限"
        case .available, .unavailable:
            sourceInfoLabel.stringValue = "当前输入：未检测到可用摄像头"
        }
    }

    private func updateCaptureHint() {
        let selectedOption = resolutionOptions.first {
            $0.id == settings.cameraResolutionID
        }
        captureHintLabel.stringValue = switch (selectedOption?.width, selectedOption?.height) {
        case (640, 480): "更省资源，适合小号画中画"
        case (1280, 720): "清晰度与性能均衡，适合大多数画中画"
        case (1920, 1080): "画面更清晰，适合大号画中画"
        default: "优先使用 720p · 30 fps，不支持时自动选择接近规格"
        }
    }

    private static func captureQualityTitle(_ option: CameraResolutionOption) -> String {
        switch (option.width, option.height) {
        case (640, 480): "480p（更省资源）"
        case (1280, 720): "720p（均衡）"
        case (1920, 1080): "1080p（更清晰）"
        default: "自动（推荐：720p / 30 fps）"
        }
    }

    private static func frameRateTitle(_ frameRate: Double) -> String {
        let rounded = frameRate.rounded()
        if abs(frameRate - rounded) < 0.1 {
            return "\(Int(rounded)) fps"
        }
        return String(format: "%.2f fps", frameRate)
    }

    private func setupUI() {
        guard let window else { return }
        window.title = "SameShot 控制面板"

        let root = NSView(frame: window.contentView?.bounds ?? .zero)
        root.autoresizingMask = [.width, .height]
        window.contentView = root

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        root.addSubview(scrollView)
        scrollViewRef = scrollView

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 600))
        scrollView.documentView = documentView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20),
            stack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor, constant: -40),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -24)
        ])

        configureControls()

        stack.addArrangedSubview(sectionLabel("摄像头"))
        stack.addArrangedSubview(formRow(title: "摄像头画质", control: captureQualityPopup))
        stack.addArrangedSubview(formRow(title: "", control: captureHintLabel))

        sourceInfoLabel.font = .systemFont(ofSize: 12)
        sourceInfoLabel.textColor = .secondaryLabelColor
        let sourceInfoRow = formRow(title: "", control: sourceInfoLabel)
        stack.addArrangedSubview(sourceInfoRow)
        stack.setCustomSpacing(24, after: sourceInfoRow)

        stack.addArrangedSubview(sectionLabel("画中画"))
        stack.addArrangedSubview(formRow(title: "大小", control: sizePresetControl))

        customSizeStack.orientation = .horizontal
        customSizeStack.alignment = .centerY
        customSizeStack.spacing = 8
        customSizeStack.addArrangedSubview(widthField)
        customSizeStack.addArrangedSubview(label("×"))
        customSizeStack.addArrangedSubview(heightField)
        let customSizeRow = formRow(title: "自定义", control: customSizeStack)
        self.customSizeRow = customSizeRow
        stack.addArrangedSubview(customSizeRow)
        stack.addArrangedSubview(formRow(title: "", control: sizeInfoLabel))

        stack.addArrangedSubview(formRow(title: "比例", control: aspectRatioPopup))
        let scalingModeRow = formRow(title: "显示方式", control: scalingModePopup)
        stack.addArrangedSubview(scalingModeRow)
        let scalingHintRow = formRow(title: "", control: scalingHintLabel)
        stack.addArrangedSubview(scalingHintRow)
        stack.setCustomSpacing(24, after: scalingHintRow)

        stack.addArrangedSubview(sectionLabel("外观"))
        stack.addArrangedSubview(formRow(title: "圆角", control: cornerSlider))
        stack.addArrangedSubview(formRow(title: "", control: mirrorButton))
    }

    private func configureControls() {
        captureQualityPopup.target = self
        captureQualityPopup.action = #selector(changeCaptureQuality)

        sizePresetControl.target = self
        sizePresetControl.action = #selector(changeSizePreset)

        [widthField, heightField].forEach {
            $0.alignment = .center
            $0.controlSize = .large
            $0.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalToConstant: 92).isActive = true
            $0.target = self
            $0.action = #selector(updateCustomSize)
        }
        widthField.placeholderString = "宽度"
        heightField.placeholderString = "高度"

        aspectRatioPopup.addItems(withTitles: OverlayAspectRatio.allCases.map(\ .title))
        aspectRatioPopup.target = self
        aspectRatioPopup.action = #selector(changeAspectRatio)

        scalingModePopup.addItems(withTitles: VideoScalingMode.allCases.map(\ .title))
        scalingModePopup.target = self
        scalingModePopup.action = #selector(changeScalingMode)

        cornerSlider.target = self
        cornerSlider.action = #selector(updateCornerRadius)
        mirrorButton.target = self
        mirrorButton.action = #selector(toggleMirror)

        [captureHintLabel, sourceInfoLabel, sizeInfoLabel, scalingHintLabel].forEach {
            $0.font = .systemFont(ofSize: 12)
            $0.textColor = .secondaryLabelColor
            $0.preferredMaxLayoutWidth = 280
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalToConstant: 280).isActive = true
        }

        [captureQualityPopup, aspectRatioPopup, scalingModePopup].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalToConstant: 280).isActive = true
        }
        sizePresetControl.translatesAutoresizingMaskIntoConstraints = false
        sizePresetControl.widthAnchor.constraint(equalToConstant: 280).isActive = true
        cornerSlider.translatesAutoresizingMaskIntoConstraints = false
        cornerSlider.widthAnchor.constraint(equalToConstant: 280).isActive = true
    }

    private func updateSizePresetSelection() {
        let presetWidths: [Double] = [240, 320, 480]
        if let index = presetWidths.firstIndex(where: { abs($0 - settings.width) < 1 }) {
            sizePresetControl.selectedSegment = index
            customSizeRow?.isHidden = true
        } else {
            sizePresetControl.selectedSegment = 3
            customSizeRow?.isHidden = false
        }
    }

    private func updateSizeInfo() {
        let width = Int(settings.width.rounded())
        let height = Int(settings.height.rounded())
        let presetDescription = switch sizePresetControl.selectedSegment {
        case 0: " · 小号"
        case 1: " · 中号（默认）"
        case 2: " · 大号"
        default: ""
        }
        sizeInfoLabel.stringValue = "当前尺寸：\(width) × \(height)\(presetDescription)；预设数字为窗口宽度"
    }

    private func updateScalingHint() {
        if settings.aspectRatio == .source {
            scalingHintLabel.stringValue = "跟随摄像头比例时，通常不会发生裁切或留边"
            return
        }
        scalingHintLabel.stringValue = switch settings.videoScalingMode {
        case .fill: "窗口没有留边；比例不一致时会裁掉画面边缘"
        case .fit: "保留完整画面；比例不一致时可能出现留边"
        }
    }

    private func resolvedAspectRatio(for settings: OverlaySettings) -> Double {
        if let fixedValue = settings.aspectRatio.fixedValue {
            return fixedValue
        }
        if settings.aspectRatio == .source,
           let info = cameraController?.activeFormatInfo,
           info.height > 0 {
            return Double(info.width) / Double(info.height)
        }
        return settings.height > 0 ? settings.width / settings.height : 16.0 / 9.0
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 15, weight: .semibold)
        return field
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 13)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func formRow(title: String, control: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: 72).isActive = true

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(control)
        return row
    }

    @objc private func changeCaptureQuality() {
        guard let option = selectedCaptureQualityOption() else { return }
        mutateSettings {
            $0.cameraResolutionID = option.id
            $0.cameraFrameRate = option.id == CameraResolutionOption.auto.id
                ? nil
                : option.preferredFrameRate
        }
        alignWindowToCameraSourceIfNeeded()
    }

    @objc private func changeSizePreset() {
        let index = sizePresetControl.selectedSegment
        guard index >= 0 else { return }
        guard index < 3 else {
            customSizeRow?.isHidden = false
            return
        }

        let widths: [Double] = [240, 320, 480]
        mutateSettings(preservePosition: false) { settings in
            let ratio = resolvedAspectRatio(for: settings)
            settings.width = widths[index]
            settings.height = max(80, settings.width / ratio)
        }
    }

    @objc private func updateCustomSize() {
        guard let width = Double(widthField.stringValue),
              let height = Double(heightField.stringValue),
              width >= 80,
              height >= 80 else {
            push(settings: settings)
            return
        }

        let widthFocused = window?.firstResponder === widthField.currentEditor()
        let heightFocused = window?.firstResponder === heightField.currentEditor()
        mutateSettings(preservePosition: false) { settings in
            guard settings.aspectRatio != .free else {
                settings.width = width
                settings.height = height
                return
            }

            let ratio = resolvedAspectRatio(for: settings)
            if heightFocused && !widthFocused {
                settings.height = height
                settings.width = max(80, height * ratio)
            } else {
                settings.width = width
                settings.height = max(80, width / ratio)
            }
        }
    }

    @objc private func changeAspectRatio() {
        let index = aspectRatioPopup.indexOfSelectedItem
        guard index >= 0, index < OverlayAspectRatio.allCases.count else { return }
        let aspectRatio = OverlayAspectRatio.allCases[index]

        mutateSettings(preservePosition: aspectRatio == .free) { settings in
            settings.aspectRatio = aspectRatio
            guard aspectRatio != .free else { return }
            let ratio = resolvedAspectRatio(for: settings)
            settings.height = max(80, settings.width / ratio)
        }
    }

    @objc private func changeScalingMode() {
        let index = scalingModePopup.indexOfSelectedItem
        guard index >= 0, index < VideoScalingMode.allCases.count else { return }
        mutateSettings { $0.videoScalingMode = VideoScalingMode.allCases[index] }
    }

    @objc private func updateCornerRadius() {
        mutateSettings { $0.cornerRadius = cornerSlider.doubleValue }
    }

    @objc private func toggleMirror() {
        mutateSettings { $0.mirrorCamera = mirrorButton.state == .on }
    }

    private func mutateSettings(
        preservePosition: Bool = true,
        _ body: (inout OverlaySettings) -> Void
    ) {
        guard let window = overlayWindow else { return }
        var next = window.settings
        body(&next)
        window.apply(next, preservePosition: preservePosition)
        push(settings: window.settings)
    }

    private func alignWindowToCameraSourceIfNeeded() {
        guard let window = overlayWindow,
              window.settings.aspectRatio == .source,
              let info = cameraController?.activeFormatInfo,
              info.height > 0 else {
            return
        }
        var next = window.settings
        let sourceRatio = Double(info.width) / Double(info.height)
        let alignedHeight = max(80, next.width / sourceRatio)
        guard abs(next.height - alignedHeight) >= 0.5 else { return }
        next.height = alignedHeight
        window.apply(next, preservePosition: false)
        push(settings: window.settings)
    }

    func scrollToTop() {
        guard let scrollView = scrollViewRef else { return }
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}
