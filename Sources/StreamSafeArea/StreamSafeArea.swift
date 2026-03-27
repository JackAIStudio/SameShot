import AppKit
import Foundation

struct OverlaySettings {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var borderAlpha: Double
    var fillAlpha: Double
    var lineWidth: Double
    var clickThrough: Bool
    var targetScreenID: String?

    static let defaults = OverlaySettings(
        x: 100,
        y: 100,
        width: 320,
        height: 180,
        borderAlpha: 0.9,
        fillAlpha: 0.08,
        lineWidth: 3,
        clickThrough: false,
        targetScreenID: nil
    )
}

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()
    private let defaults = UserDefaults.standard
    private let key = "StreamSafeArea.overlaySettings"

    func load() -> OverlaySettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(CodableOverlaySettings.self, from: data)
        else { return .defaults }
        return settings.value
    }

    func save(_ settings: OverlaySettings) {
        let wrapped = CodableOverlaySettings(value: settings)
        guard let data = try? JSONEncoder().encode(wrapped) else { return }
        defaults.set(data, forKey: key)
    }

    private struct CodableOverlaySettings: Codable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double
        var borderAlpha: Double
        var fillAlpha: Double
        var lineWidth: Double
        var clickThrough: Bool
        var targetScreenID: String?

        init(value: OverlaySettings) {
            x = value.x
            y = value.y
            width = value.width
            height = value.height
            borderAlpha = value.borderAlpha
            fillAlpha = value.fillAlpha
            lineWidth = value.lineWidth
            clickThrough = value.clickThrough
            targetScreenID = value.targetScreenID
        }

        var value: OverlaySettings {
            OverlaySettings(
                x: x,
                y: y,
                width: width,
                height: height,
                borderAlpha: borderAlpha,
                fillAlpha: fillAlpha,
                lineWidth: lineWidth,
                clickThrough: clickThrough,
                targetScreenID: targetScreenID
            )
        }
    }
}

extension Notification.Name {
    static let overlayDidChange = Notification.Name("overlayDidChange")
}

final class OverlayView: NSView {
    var settings: OverlaySettings = .defaults {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: settings.lineWidth / 2, dy: settings.lineWidth / 2)
        let fillColor = NSColor.systemOrange.withAlphaComponent(settings.fillAlpha)
        fillColor.setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        path.fill()

        let borderColor = NSColor.systemOrange.withAlphaComponent(settings.borderAlpha)
        borderColor.setStroke()
        path.lineWidth = settings.lineWidth
        path.stroke()
    }
}

final class OverlayWindow: NSWindow {
    var settings = OverlaySettings.defaults {
        didSet {
            persistFrame()
            updateBehaviors()
        }
    }

    init(settings: OverlaySettings) {
        let rect = NSRect(x: settings.x, y: settings.y, width: settings.width, height: settings.height)
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        self.settings = settings
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        contentView = OverlayView(frame: rect)
        contentView?.wantsLayer = true
        if let overlayView = contentView as? OverlayView {
            overlayView.settings = settings
        }
        updateBehaviors()
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        syncFromFrame()
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: flag, animate: animateFlag)
        syncFromFrame()
    }

    private func syncFromFrame() {
        settings.x = frame.origin.x
        settings.y = frame.origin.y
        settings.width = frame.size.width
        settings.height = frame.size.height
        if let overlayView = contentView as? OverlayView {
            overlayView.settings = settings
        }
        NotificationCenter.default.post(name: .overlayDidChange, object: nil)
    }

    private func persistFrame() {
        SettingsStore.shared.save(settings)
    }

    func apply(_ settings: OverlaySettings) {
        self.settings = settings
        let frame = NSRect(x: settings.x, y: settings.y, width: settings.width, height: settings.height)
        super.setFrame(frame, display: true)
        if let overlayView = contentView as? OverlayView {
            overlayView.settings = settings
        }
    }

    private func updateBehaviors() {
        ignoresMouseEvents = settings.clickThrough
        if let overlayView = contentView as? OverlayView {
            overlayView.settings = settings
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: OverlayWindow!
    private var settings = SettingsStore.shared.load()
    private let panelController = ControlPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let resolved = resolveInitialSettings(settings)
        settings = resolved
        window = OverlayWindow(settings: resolved)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        panelController.bind(window: window, settings: settings)
        buildMenu()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncWindowState),
            name: .overlayDidChange,
            object: nil
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func syncWindowState() {
        settings = window.settings
        panelController.push(settings: settings)
        SettingsStore.shared.save(settings)
    }

    private func resolveInitialSettings(_ current: OverlaySettings) -> OverlaySettings {
        var updated = current
        if let targetID = current.targetScreenID,
           let screen = NSScreen.screens.first(where: { Self.screenID(for: $0) == targetID }) {
            let visible = screen.visibleFrame
            if !visible.contains(NSPoint(x: current.x, y: current.y)) {
                updated.x = visible.maxX - current.width - 40
                updated.y = visible.minY + 40
            }
            return updated
        }

        if let screen = NSScreen.screens.last {
            let visible = screen.visibleFrame
            updated.targetScreenID = Self.screenID(for: screen)
            updated.x = visible.maxX - updated.width - 40
            updated.y = visible.minY + 40
        }
        return updated
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "控制面板", action: #selector(showControls), keyEquivalent: ",")
        appMenu.addItem(withTitle: "切换点击穿透", action: #selector(toggleClickThrough), keyEquivalent: "t")
        appMenu.addItem(withTitle: "吸附到右下角", action: #selector(snapToBottomRight), keyEquivalent: "b")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 StreamSafeArea", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        NSApp.mainMenu = mainMenu
    }

    @objc private func showControls() {
        panelController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleClickThrough() {
        settings.clickThrough.toggle()
        apply(settings)
    }

    @objc private func snapToBottomRight() {
        guard let screen = currentScreen() else { return }
        let visible = screen.visibleFrame
        settings.x = visible.maxX - settings.width - 40
        settings.y = visible.minY + 40
        apply(settings)
    }

    private func currentScreen() -> NSScreen? {
        if let id = settings.targetScreenID {
            return NSScreen.screens.first(where: { Self.screenID(for: $0) == id })
        }
        return window.screen ?? NSScreen.main
    }

    private func apply(_ newSettings: OverlaySettings) {
        settings = newSettings
        window.apply(newSettings)
        panelController.push(settings: newSettings)
        SettingsStore.shared.save(newSettings)
    }

    static func screenID(for screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return String(number.intValue)
    }
}

final class ControlPanelController: NSWindowController {
    private let widthField = NSTextField(string: "")
    private let heightField = NSTextField(string: "")
    private let borderSlider = NSSlider(value: 0.9, minValue: 0.1, maxValue: 1.0, target: nil, action: nil)
    private let fillSlider = NSSlider(value: 0.08, minValue: 0.0, maxValue: 0.4, target: nil, action: nil)
    private let lineSlider = NSSlider(value: 3.0, minValue: 1.0, maxValue: 10.0, target: nil, action: nil)
    private let clickThroughButton = NSButton(checkboxWithTitle: "点击穿透", target: nil, action: nil)
    private let infoLabel = NSTextField(labelWithString: "")

    private weak var overlayWindow: OverlayWindow?
    private var settings = OverlaySettings.defaults

    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 360, height: 240)
        let window = NSWindow(contentRect: contentRect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        self.init(window: window)
        setupUI()
    }

    func bind(window: OverlayWindow, settings: OverlaySettings) {
        self.overlayWindow = window
        self.settings = settings
        push(settings: settings)
    }

    func push(settings: OverlaySettings) {
        self.settings = settings
        widthField.stringValue = String(Int(settings.width.rounded()))
        heightField.stringValue = String(Int(settings.height.rounded()))
        borderSlider.doubleValue = settings.borderAlpha
        fillSlider.doubleValue = settings.fillAlpha
        lineSlider.doubleValue = settings.lineWidth
        clickThroughButton.state = settings.clickThrough ? .on : .off
        infoLabel.stringValue = "位置: (\(Int(settings.x.rounded())), \(Int(settings.y.rounded())))"
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

        widthField.placeholderString = "宽度"
        heightField.placeholderString = "高度"
        widthField.target = self
        widthField.action = #selector(updateSize)
        heightField.target = self
        heightField.action = #selector(updateSize)

        borderSlider.target = self
        borderSlider.action = #selector(updateSliders)
        fillSlider.target = self
        fillSlider.action = #selector(updateSliders)
        lineSlider.target = self
        lineSlider.action = #selector(updateSliders)
        clickThroughButton.target = self
        clickThroughButton.action = #selector(toggleClickThrough)

        let sizeRow = NSStackView(views: [label("宽"), widthField, label("高"), heightField])
        sizeRow.spacing = 8
        stack.addArrangedSubview(sizeRow)

        stack.addArrangedSubview(label("边框透明度"))
        stack.addArrangedSubview(borderSlider)
        stack.addArrangedSubview(label("填充透明度"))
        stack.addArrangedSubview(fillSlider)
        stack.addArrangedSubview(label("边框粗细"))
        stack.addArrangedSubview(lineSlider)
        stack.addArrangedSubview(clickThroughButton)
        stack.addArrangedSubview(infoLabel)

        let buttonRow = NSStackView()
        buttonRow.spacing = 8
        buttonRow.addArrangedSubview(button("吸附右下角", #selector(snapToBottomRight)))
        buttonRow.addArrangedSubview(button("隐藏窗口", #selector(hideOverlay)))
        buttonRow.addArrangedSubview(button("显示窗口", #selector(showOverlay)))
        stack.addArrangedSubview(buttonRow)
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func updateSize() {
        guard let width = Double(widthField.stringValue),
              let height = Double(heightField.stringValue),
              width >= 80, height >= 80,
              var current = overlayWindow?.settings else { return }
        current.width = width
        current.height = height
        overlayWindow?.apply(current)
    }

    @objc private func updateSliders() {
        guard var current = overlayWindow?.settings else { return }
        current.borderAlpha = borderSlider.doubleValue
        current.fillAlpha = fillSlider.doubleValue
        current.lineWidth = lineSlider.doubleValue
        overlayWindow?.apply(current)
    }

    @objc private func toggleClickThrough() {
        guard var current = overlayWindow?.settings else { return }
        current.clickThrough = (clickThroughButton.state == .on)
        overlayWindow?.apply(current)
    }

    @objc private func snapToBottomRight() {
        guard let window = overlayWindow else { return }
        guard let screen = window.screen ?? NSScreen.main else { return }
        var current = window.settings
        let visible = screen.visibleFrame
        current.x = visible.maxX - current.width - 40
        current.y = visible.minY + 40
        window.apply(current)
    }

    @objc private func hideOverlay() {
        overlayWindow?.orderOut(nil)
    }

    @objc private func showOverlay() {
        overlayWindow?.makeKeyAndOrderFront(nil)
        overlayWindow?.orderFrontRegardless()
    }
}

@main
struct StreamSafeAreaApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}
