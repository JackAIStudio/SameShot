import AVFoundation
import CoreMedia
import Foundation

enum CameraAvailability {
    case available
    case requestingPermission
    case permissionDenied
    case unavailable
}

@MainActor
final class CameraSessionController: NSObject {
    private let session = AVCaptureSession()
    private var configured = false
    private var currentDevice: AVCaptureDevice?
    private var currentResolutionID: String = CameraResolutionOption.auto.id
    private(set) var availability: CameraAvailability = .unavailable
    private(set) var availableResolutions: [CameraResolutionOption] = [.auto]

    var isAvailable: Bool {
        availability == .available
    }

    func attach(to previewLayer: AVCaptureVideoPreviewLayer, resolutionID: String) {
        configureIfNeeded()
        updateResolutionIfNeeded(resolutionID)
        if previewLayer.session !== session {
            previewLayer.session = isAvailable ? session : nil
        }
        previewLayer.videoGravity = .resizeAspectFill
        if isAvailable, !session.isRunning {
            session.startRunning()
        }
    }

    func refreshAvailableResolutions() {
        let previousAvailability = availability
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if currentDevice == nil,
           (authorizationStatus == .authorized) != (availability == .available) {
            configured = false
        }
        if currentDevice == nil {
            configureIfNeeded()
        }
        availableResolutions = Self.resolutionOptions(for: currentDevice)
        if availability != previousAvailability {
            notifyAvailabilityChanged()
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {
        case .notDetermined:
            availability = .requestingPermission
            availableResolutions = [.auto]
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.configured = false
                    self.configureIfNeeded()
                    self.notifyAvailabilityChanged()
                }
            }
            return
        case .denied, .restricted:
            availability = .permissionDenied
            availableResolutions = [.auto]
            return
        case .authorized:
            break
        @unknown default:
            availability = .unavailable
            availableResolutions = [.auto]
            return
        }

        session.beginConfiguration()
        defer {
            session.commitConfiguration()
            if isAvailable, !session.isRunning {
                session.startRunning()
            }
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            availability = .unavailable
            availableResolutions = [.auto]
            return
        }

        session.addInput(input)
        currentDevice = device
        availability = .available
        availableResolutions = Self.resolutionOptions(for: device)
        updateResolutionIfNeeded(currentResolutionID)
    }

    private func notifyAvailabilityChanged() {
        NotificationCenter.default.post(name: .cameraAvailabilityDidChange, object: self)
    }

    private func updateResolutionIfNeeded(_ resolutionID: String) {
        guard resolutionID != currentResolutionID || !configured else { return }
        currentResolutionID = resolutionID
        guard isAvailable else { return }
        let option = availableResolutions.first(where: { $0.id == resolutionID }) ?? .auto
        let preset = option.sessionPreset
        if session.sessionPreset != preset, session.canSetSessionPreset(preset) {
            session.beginConfiguration()
            session.sessionPreset = preset
            session.commitConfiguration()
        }
    }

    static func resolutionOptions(for device: AVCaptureDevice?) -> [CameraResolutionOption] {
        guard let device else { return [.auto] }
        var seen = Set<String>()
        var items: [CameraResolutionOption] = [.auto]

        for format in device.formats {
            let desc = format.formatDescription
            let dims = CMVideoFormatDescriptionGetDimensions(desc)
            let maxFPS = format.videoSupportedFrameRateRanges.map(\ .maxFrameRate).max() ?? 0
            let preset = presetFor(width: dims.width, height: dims.height)
            let key = "\(dims.width)x\(dims.height):\(preset?.rawValue ?? "none")"
            if seen.contains(key) { continue }
            seen.insert(key)
            let fpsText = maxFPS > 0 ? " · ≤\(Int(maxFPS.rounded()))fps" : ""
            items.append(
                CameraResolutionOption(
                    id: key,
                    label: "\(dims.width)×\(dims.height)\(fpsText)",
                    width: dims.width,
                    height: dims.height,
                    maxFPS: maxFPS,
                    presetRawValue: preset?.rawValue
                )
            )
        }

        return items.sorted { lhs, rhs in
            switch (lhs.width, rhs.width) {
            case (nil, _): return true
            case (_, nil): return false
            case let (lw?, rw?):
                if lw == rw { return (lhs.height ?? 0) < (rhs.height ?? 0) }
                return lw < rw
            }
        }
    }

    private static func presetFor(width: Int32, height: Int32) -> AVCaptureSession.Preset? {
        let pair = (max(width, height), min(width, height))
        switch pair {
        case (3840, 2160): return .hd4K3840x2160
        case (1920, 1080): return .hd1920x1080
        case (1280, 720): return .hd1280x720
        case (640, 480): return .vga640x480
        default: return .high
        }
    }
}
