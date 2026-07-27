import AppKit
import Foundation

struct CameraResolutionOption: Codable, Hashable {
    var id: String
    var label: String
    var width: Int32?
    var height: Int32?
    var frameRates: [Double]

    static let auto = CameraResolutionOption(
        id: "auto",
        label: "自动（推荐）",
        width: nil,
        height: nil,
        frameRates: []
    )

    func supports(frameRate: Double) -> Bool {
        matchingFrameRate(for: frameRate) != nil
    }

    func matchingFrameRate(for frameRate: Double) -> Double? {
        frameRates.first { abs($0 - frameRate) < 0.2 }
    }

    var preferredFrameRate: Double? {
        frameRates.min(by: { abs($0 - 30) < abs($1 - 30) })
    }

    var isPictureInPictureQualityPreset: Bool {
        if id == Self.auto.id {
            return true
        }
        return switch (width, height) {
        case (640, 480), (1280, 720), (1920, 1080):
            true
        default:
            false
        }
    }
}

struct CameraActiveFormatInfo: Equatable {
    var width: Int32
    var height: Int32
    var frameRate: Double?
}

enum OverlayAspectRatio: String, Codable, CaseIterable {
    case source
    case sixteenNine
    case fourThree
    case square
    case free

    var title: String {
        switch self {
        case .source: "原始画面比例（推荐）"
        case .sixteenNine: "16:9（横向）"
        case .fourThree: "4:3（传统）"
        case .square: "1:1（方形）"
        case .free: "自由调整"
        }
    }

    var fixedValue: Double? {
        switch self {
        case .sixteenNine: 16.0 / 9.0
        case .fourThree: 4.0 / 3.0
        case .square: 1
        case .source, .free: nil
        }
    }
}

enum VideoScalingMode: String, Codable, CaseIterable {
    case fill
    case fit

    var title: String {
        switch self {
        case .fill: "铺满窗口（可能裁切）"
        case .fit: "完整画面（可能留边）"
        }
    }
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
    var cameraFrameRate: Double?
    var aspectRatio: OverlayAspectRatio
    var videoScalingMode: VideoScalingMode

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
        cameraFrameRate: nil,
        aspectRatio: .source,
        videoScalingMode: .fill
    )
}

extension OverlaySettings {
    private enum CodingKeys: String, CodingKey {
        case lastSavedAt
        case x
        case y
        case width
        case height
        case targetScreenID
        case cornerRadius
        case mirrorCamera
        case cameraResolutionID
        case cameraFrameRate
        case aspectRatio
        case videoScalingMode
        case lockAspectRatio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.defaults

        lastSavedAt = try container.decodeIfPresent(Double.self, forKey: .lastSavedAt)
        x = try container.decodeIfPresent(Double.self, forKey: .x) ?? defaults.x
        y = try container.decodeIfPresent(Double.self, forKey: .y) ?? defaults.y
        width = try container.decodeIfPresent(Double.self, forKey: .width) ?? defaults.width
        height = try container.decodeIfPresent(Double.self, forKey: .height) ?? defaults.height
        targetScreenID = try container.decodeIfPresent(String.self, forKey: .targetScreenID)
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? defaults.cornerRadius
        mirrorCamera = try container.decodeIfPresent(Bool.self, forKey: .mirrorCamera) ?? defaults.mirrorCamera
        cameraResolutionID = try container.decodeIfPresent(String.self, forKey: .cameraResolutionID) ?? defaults.cameraResolutionID
        cameraFrameRate = try container.decodeIfPresent(Double.self, forKey: .cameraFrameRate)
        videoScalingMode = try container.decodeIfPresent(VideoScalingMode.self, forKey: .videoScalingMode) ?? defaults.videoScalingMode

        if let savedAspectRatio = try container.decodeIfPresent(OverlayAspectRatio.self, forKey: .aspectRatio) {
            aspectRatio = savedAspectRatio
        } else {
            let wasLocked = try container.decodeIfPresent(Bool.self, forKey: .lockAspectRatio) ?? false
            let currentRatio = height > 0 ? width / height : 16.0 / 9.0
            aspectRatio = wasLocked && abs(currentRatio - 16.0 / 9.0) < 0.03 ? .sixteenNine : .free
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(lastSavedAt, forKey: .lastSavedAt)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encodeIfPresent(targetScreenID, forKey: .targetScreenID)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(mirrorCamera, forKey: .mirrorCamera)
        try container.encode(cameraResolutionID, forKey: .cameraResolutionID)
        try container.encodeIfPresent(cameraFrameRate, forKey: .cameraFrameRate)
        try container.encode(aspectRatio, forKey: .aspectRatio)
        try container.encode(videoScalingMode, forKey: .videoScalingMode)
    }
}

extension Notification.Name {
    static let overlayDidChange = Notification.Name("overlayDidChange")
    static let cameraAvailabilityDidChange = Notification.Name("cameraAvailabilityDidChange")
}
