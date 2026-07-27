import AppKit

@MainActor
final class ControlPanelController: NSWindowController {
    private weak var scrollViewRef: NSScrollView?

    private let captureQualityPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sourceInfoLabel = NSTextField(wrappingLabelWithString: "")
    private let captureHintLabel = NSTextField(wrappingLabelWithString: "")

    private let sizeControlStack = NSStackView()
    private let resizeHintLabel = NSTextField(labelWithString: "拖动画中画边缘调整大小")
    private let resetSizeButton = NSButton(title: "恢复默认大小", target: nil, action: nil)
    private let aspectRatioPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let aspectRatioHintLabel = NSTextField(wrappingLabelWithString: "")
    private let scalingModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let scalingHintLabel = NSTextField(wrappingLabelWithString: "")
    private weak var scalingModeRow: NSView?
    private weak var scalingHintRow: NSView?

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

        if let index = OverlayAspectRatio.allCases.firstIndex(of: settings.aspectRatio) {
            aspectRatioPopup.selectItem(at: index)
        }
        updateAspectRatioHint()
        if let index = VideoScalingMode.allCases.firstIndex(of: settings.videoScalingMode) {
            scalingModePopup.selectItem(at: index)
        }
        updateScalingHint()

        cornerSlider.doubleValue = settings.cornerRadius
        mirrorButton.state = settings.mirrorCamera ? .on : .off
    }

    private var displayedCaptureQualityOptions: [CameraResolutionOption] {
        let cameraOptions = resolutionOptions.filter {
            $0.id != CameraResolutionOption.auto.id &&
                $0.width != nil &&
                $0.height != nil
        }
        return [.auto] + CameraSessionController.sortedByIncreasingResolution(cameraOptions)
    }

    private func reloadCaptureQualityMenu() {
        captureQualityPopup.removeAllItems()
        captureQualityPopup.addItems(withTitles: displayedCaptureQualityOptions.map(captureQualityTitle))
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
        guard selectedOption?.id != CameraResolutionOption.auto.id,
              let selectedOption else {
            if let recommended = CameraSessionController.automaticResolutionOption(
                from: resolutionOptions
            ) {
                captureHintLabel.stringValue =
                    "优先使用最低分辨率 \(recommended.label)，帧率自动选择最接近 30 fps"
            } else {
                captureHintLabel.stringValue = "优先使用摄像头可用的最低分辨率与接近 30 fps 的帧率"
            }
            return
        }
        captureHintLabel.stringValue =
            "使用摄像头原生\(Self.captureShapeTitle(selectedOption))画面，帧率自动选择最接近 30 fps"
    }

    private func captureQualityTitle(_ option: CameraResolutionOption) -> String {
        if option.id == CameraResolutionOption.auto.id {
            guard let recommended = CameraSessionController.automaticResolutionOption(
                from: resolutionOptions
            ) else {
                return "自动（推荐最低分辨率）"
            }
            let frameRate = recommended.preferredFrameRate.map {
                " / \(Self.frameRateTitle($0))"
            } ?? ""
            return "自动（推荐：\(recommended.label)\(frameRate)）"
        }
        guard let width = option.width,
              let height = option.height else {
            return option.label
        }
        return "\(width) × \(height)（\(Self.captureAspectTitle(width: width, height: height))）"
    }

    private static func captureShapeTitle(_ option: CameraResolutionOption) -> String {
        guard let width = option.width, let height = option.height else { return "" }
        if width == height {
            return "方形"
        }
        return width > height ? "横屏" : "竖屏"
    }

    private static func captureAspectTitle(width: Int32, height: Int32) -> String {
        guard height > 0 else { return "原始比例" }
        let ratio = Double(width) / Double(height)
        let candidates: [(ratio: Double, title: String)] = [
            (16.0 / 9.0, "16:9 横屏"),
            (4.0 / 3.0, "4:3 横屏"),
            (1.0, "1:1 方形"),
            (3.0 / 4.0, "3:4 竖屏"),
            (9.0 / 16.0, "9:16 竖屏")
        ]
        if let match = candidates.first(where: { abs(ratio - $0.ratio) < 0.02 }) {
            return match.title
        }
        return width > height ? "横屏" : "竖屏"
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
        sizeControlStack.orientation = .horizontal
        sizeControlStack.alignment = .centerY
        sizeControlStack.spacing = 10
        sizeControlStack.addArrangedSubview(resizeHintLabel)
        sizeControlStack.addArrangedSubview(resetSizeButton)
        stack.addArrangedSubview(formRow(title: "大小", control: sizeControlStack))

        stack.addArrangedSubview(formRow(title: "画面比例", control: aspectRatioPopup))
        stack.addArrangedSubview(formRow(title: "", control: aspectRatioHintLabel))
        let scalingModeRow = formRow(title: "显示方式", control: scalingModePopup)
        self.scalingModeRow = scalingModeRow
        stack.addArrangedSubview(scalingModeRow)
        let scalingHintRow = formRow(title: "", control: scalingHintLabel)
        self.scalingHintRow = scalingHintRow
        stack.addArrangedSubview(scalingHintRow)
        stack.setCustomSpacing(24, after: scalingHintRow)

        stack.addArrangedSubview(sectionLabel("外观"))
        stack.addArrangedSubview(formRow(title: "圆角", control: cornerSlider))
        stack.addArrangedSubview(formRow(title: "", control: mirrorButton))
    }

    private func configureControls() {
        captureQualityPopup.target = self
        captureQualityPopup.action = #selector(changeCaptureQuality)

        resizeHintLabel.font = .systemFont(ofSize: 12)
        resizeHintLabel.textColor = .secondaryLabelColor
        resetSizeButton.controlSize = .small
        resetSizeButton.bezelStyle = .rounded
        resetSizeButton.target = self
        resetSizeButton.action = #selector(resetOverlaySize)

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

        [captureHintLabel, sourceInfoLabel, aspectRatioHintLabel, scalingHintLabel].forEach {
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
        sizeControlStack.translatesAutoresizingMaskIntoConstraints = false
        sizeControlStack.widthAnchor.constraint(equalToConstant: 280).isActive = true
        cornerSlider.translatesAutoresizingMaskIntoConstraints = false
        cornerSlider.widthAnchor.constraint(equalToConstant: 280).isActive = true
    }

    private func updateAspectRatioHint() {
        aspectRatioHintLabel.stringValue = settings.aspectRatio == .free
            ? "可分别调整窗口宽度和高度"
            : "拖动边缘时会保持所选比例"
    }

    private func updateScalingHint() {
        let usesOriginalAspectRatio = settings.aspectRatio == .source
        scalingModeRow?.isHidden = usesOriginalAspectRatio
        scalingHintRow?.isHidden = usesOriginalAspectRatio
        if usesOriginalAspectRatio {
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

    @objc private func resetOverlaySize() {
        overlayWindow?.resetToDefaultSize()
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
