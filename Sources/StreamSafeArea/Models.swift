import AppKit
import AVFoundation
import Foundation

struct CameraResolutionOption: Codable, Hashable {
    var id: String
    var label: String
    var width: Int32?
    var height: Int32?
    var maxFPS: Double?
    var presetRawValue: String?

    static let auto = CameraResolutionOption(
        id: "auto",
        label: "自动",
        width: nil,
        height: nil,
        maxFPS: nil,
        presetRawValue: AVCaptureSession.Preset.high.rawValue
    )

    var sessionPreset: AVCaptureSession.Preset {
        guard let presetRawValue else { return .high }
        return AVCaptureSession.Preset(rawValue: presetRawValue)
    }
}

@MainActor
protocol OverlayActionHandling: AnyObject {
    func showControls()
    func toggleClickThrough()
    func toggleLockFrame()
    func toggleAspectRatioLock()
    func toggleDisplayMode()
    func currentSettings() -> OverlaySettings
}

struct OverlaySettings: Codable {
    enum DisplayMode: String, Codable {
        case frame
        case camera
    }

    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var borderAlpha: Double
    var fillAlpha: Double
    var lineWidth: Double
    var clickThrough: Bool
    var targetScreenID: String?
    var displayMode: DisplayMode
    var cameraAlpha: Double
    var cornerRadius: Double
    var mirrorCamera: Bool
    var showBorderInCameraMode: Bool
    var cameraResolutionID: String
    var lockFrame: Bool
    var lockAspectRatio: Bool

    static let defaults = OverlaySettings(
        x: 100,
        y: 100,
        width: 320,
        height: 180,
        borderAlpha: 0.9,
        fillAlpha: 0.08,
        lineWidth: 3,
        clickThrough: false,
        targetScreenID: nil,
        displayMode: .frame,
        cameraAlpha: 0.96,
        cornerRadius: 18,
        mirrorCamera: true,
        showBorderInCameraMode: true,
        cameraResolutionID: CameraResolutionOption.auto.id,
        lockFrame: false,
        lockAspectRatio: false
    )
}

extension Notification.Name {
    static let overlayDidChange = Notification.Name("overlayDidChange")
}
