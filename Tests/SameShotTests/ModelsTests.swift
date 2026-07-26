import Foundation
import CoreMedia
@testable import SameShot
import XCTest

final class ModelsTests: XCTestCase {
    func testLegacyLockedSettingsMigrateToSixteenNine() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "x": 100,
            "y": 100,
            "width": 320,
            "height": 180,
            "cornerRadius": 18,
            "mirrorCamera": true,
            "cameraResolutionID": "auto",
            "lockAspectRatio": true
        ])

        let settings = try JSONDecoder().decode(OverlaySettings.self, from: data)

        XCTAssertEqual(settings.aspectRatio, .sixteenNine)
        XCTAssertEqual(settings.videoScalingMode, .fill)
        XCTAssertNil(settings.cameraFrameRate)
    }

    func testLegacyUnlockedSettingsRemainFreelyResizable() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "x": 100,
            "y": 100,
            "width": 343,
            "height": 193,
            "cornerRadius": 18,
            "mirrorCamera": true,
            "cameraResolutionID": "auto",
            "lockAspectRatio": false
        ])

        let settings = try JSONDecoder().decode(OverlaySettings.self, from: data)

        XCTAssertEqual(settings.aspectRatio, .free)
    }

    func testResolutionOptionChoosesThirtyFPSAndMatchesFractionalRate() {
        let option = CameraResolutionOption(
            id: "1920x1080",
            label: "1920 × 1080",
            width: 1920,
            height: 1080,
            frameRates: [24, 29.97, 60]
        )

        XCTAssertEqual(option.preferredFrameRate, 29.97)
        XCTAssertTrue(option.supports(frameRate: 30))
        XCTAssertEqual(option.matchingFrameRate(for: 30), 29.97)
        XCTAssertFalse(option.supports(frameRate: 50))
        XCTAssertTrue(option.isPictureInPictureQualityPreset)
    }

    func testAutomaticCapturePrefers720pAtThirtyFPS() async {
        await MainActor.run {
            let options = [
                CameraResolutionOption.auto,
                CameraResolutionOption(
                    id: "1920x1080",
                    label: "1920 × 1080",
                    width: 1920,
                    height: 1080,
                    frameRates: [30, 60]
                ),
                CameraResolutionOption(
                    id: "1280x720",
                    label: "1280 × 720",
                    width: 1280,
                    height: 720,
                    frameRates: [24, 30, 60]
                )
            ]

            let selected = CameraSessionController.automaticResolutionOption(from: options)

            XCTAssertEqual(selected?.id, "1280x720")
            XCTAssertEqual(selected?.preferredFrameRate, 30)
        }
    }

    func testFrameDurationIsClampedInsideCameraRange() async {
        await MainActor.run {
            let minimum = CMTime(value: 1, timescale: 30)
            let maximum = CMTime(value: 1, timescale: 15)

            let duration = CameraSessionController.clampedFrameDuration(
                for: 30,
                minimum: minimum,
                maximum: maximum
            )

            XCTAssertEqual(duration, minimum)
        }
    }
}
