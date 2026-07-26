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

struct CameraActiveFormatInfo: Equatable {
    var width: Int32
    var height: Int32
    var maxFPS: Double?
}

@MainActor
protocol OverlayVisibilityHandling: AnyObject {
    func showOverlay()
    func hideOverlay()
}

struct OverlaySettings: Codable {
    var lastSavedAt: Double?

    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var targetScreenID: String?
    var cornerRadius: Double
    var mirrorCamera: Bool
    var cameraResolutionID: String
    var lockAspectRatio: Bool

    static let defaults = OverlaySettings(
        lastSavedAt: nil,
        x: 100,
        y: 100,
        width: 320,
        height: 180,
        targetScreenID: nil,
        cornerRadius: 18,
        mirrorCamera: true,
        cameraResolutionID: CameraResolutionOption.auto.id,
        lockAspectRatio: false
    )
}

extension Notification.Name {
    static let overlayDidChange = Notification.Name("overlayDidChange")
    static let cameraAvailabilityDidChange = Notification.Name("cameraAvailabilityDidChange")
}
