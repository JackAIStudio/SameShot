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
    private var currentFrameRate: Double?
    private(set) var availability: CameraAvailability = .unavailable
    private(set) var availableResolutions: [CameraResolutionOption] = [.auto]

    var isAvailable: Bool {
        availability == .available
    }

    var activeFormatInfo: CameraActiveFormatInfo? {
        guard isAvailable, let device = currentDevice else { return nil }
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let activeFrameDuration = CMTimeGetSeconds(device.activeVideoMinFrameDuration)
        let frameRate = if activeFrameDuration.isFinite, activeFrameDuration > 0 {
            1 / activeFrameDuration
        } else {
            device.activeFormat.videoSupportedFrameRateRanges.map(\ .maxFrameRate).max()
        }
        return CameraActiveFormatInfo(
            width: dimensions.width,
            height: dimensions.height,
            frameRate: frameRate
        )
    }

    func attach(to previewLayer: AVCaptureVideoPreviewLayer, resolutionID: String, frameRate: Double?) {
        let configurationChanged =
            resolutionID != currentResolutionID ||
            !Self.frameRatesEqual(frameRate, currentFrameRate)
        currentResolutionID = resolutionID
        currentFrameRate = frameRate
        configureIfNeeded()
        if configurationChanged {
            applyCurrentCaptureConfiguration()
        }
        if previewLayer.session !== session {
            previewLayer.session = isAvailable ? session : nil
        }
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
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            availability = .unavailable
            availableResolutions = [.auto]
            return
        }

        session.addInput(input)
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        session.commitConfiguration()

        currentDevice = device
        availability = .available
        availableResolutions = Self.resolutionOptions(for: device)
        applyCurrentCaptureConfiguration()
        if !session.isRunning {
            session.startRunning()
        }
    }

    private func notifyAvailabilityChanged() {
        NotificationCenter.default.post(name: .cameraAvailabilityDidChange, object: self)
    }

    private func applyCurrentCaptureConfiguration() {
        guard isAvailable, let device = currentDevice else { return }

        guard currentResolutionID != CameraResolutionOption.auto.id else {
            session.beginConfiguration()
            if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }
            session.commitConfiguration()
            return
        }

        guard let option = availableResolutions.first(where: { $0.id == currentResolutionID }),
              let width = option.width,
              let height = option.height else {
            return
        }
        let requestedFrameRate =
            currentFrameRate.flatMap(option.matchingFrameRate) ??
            option.preferredFrameRate
        guard let requestedFrameRate,
              let format = Self.bestFormat(
                for: device,
                width: width,
                height: height,
                frameRate: requestedFrameRate
              ) else {
            return
        }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.activeFormat = format
            let duration = CMTime(seconds: 1 / requestedFrameRate, preferredTimescale: 1_000_000_000)
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
        } catch {
            return
        }
    }

    static func resolutionOptions(for device: AVCaptureDevice?) -> [CameraResolutionOption] {
        guard let device else { return [.auto] }
        struct ResolutionKey: Hashable {
            var width: Int32
            var height: Int32
        }

        var groupedFrameRates: [ResolutionKey: [Double]] = [:]
        for format in device.formats {
            let desc = format.formatDescription
            let dims = CMVideoFormatDescriptionGetDimensions(desc)
            let key = ResolutionKey(width: dims.width, height: dims.height)
            let rates = format.videoSupportedFrameRateRanges.flatMap(Self.userFacingFrameRates)
            groupedFrameRates[key, default: []].append(contentsOf: rates)
        }

        let customOptions = groupedFrameRates.compactMap { key, rates -> CameraResolutionOption? in
            let uniqueRates = Self.uniqueFrameRates(rates)
            guard !uniqueRates.isEmpty else { return nil }
            return CameraResolutionOption(
                id: "\(key.width)x\(key.height)",
                label: "\(key.width) × \(key.height)",
                width: key.width,
                height: key.height,
                frameRates: uniqueRates
            )
        }.sorted { lhs, rhs in
            let lhsPixels = Int64(lhs.width ?? 0) * Int64(lhs.height ?? 0)
            let rhsPixels = Int64(rhs.width ?? 0) * Int64(rhs.height ?? 0)
            if lhsPixels == rhsPixels {
                return (lhs.width ?? 0) > (rhs.width ?? 0)
            }
            return lhsPixels > rhsPixels
        }

        return [.auto] + customOptions
    }

    private static func userFacingFrameRates(for range: AVFrameRateRange) -> [Double] {
        let commonRates: [Double] = [24, 25, 30, 50, 60, 120, 240]
        var rates = commonRates.filter {
            $0 >= range.minFrameRate - 0.01 && $0 <= range.maxFrameRate + 0.01
        }
        if range.maxFrameRate >= 10,
           !rates.contains(where: { abs($0 - range.maxFrameRate) < 0.2 }) {
            rates.append(range.maxFrameRate)
        }
        return rates
    }

    private static func uniqueFrameRates(_ rates: [Double]) -> [Double] {
        rates.sorted().reduce(into: []) { result, rate in
            if !result.contains(where: { abs($0 - rate) < 0.2 }) {
                result.append(rate)
            }
        }
    }

    private static func bestFormat(
        for device: AVCaptureDevice,
        width: Int32,
        height: Int32,
        frameRate: Double
    ) -> AVCaptureDevice.Format? {
        device.formats
            .filter { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                guard dimensions.width == width, dimensions.height == height else { return false }
                return format.videoSupportedFrameRateRanges.contains {
                    frameRate >= $0.minFrameRate - 0.01 &&
                    frameRate <= $0.maxFrameRate + 0.01
                }
            }
            .min { lhs, rhs in
                let lhsMax = lhs.videoSupportedFrameRateRanges.map(\ .maxFrameRate).max() ?? .greatestFiniteMagnitude
                let rhsMax = rhs.videoSupportedFrameRateRanges.map(\ .maxFrameRate).max() ?? .greatestFiniteMagnitude
                return abs(lhsMax - frameRate) < abs(rhsMax - frameRate)
            }
    }

    private static func frameRatesEqual(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case let (lhs?, rhs?): abs(lhs - rhs) < 0.01
        default: false
        }
    }
}
