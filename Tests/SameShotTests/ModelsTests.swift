import Foundation
import CoreMedia
@testable import SameShot
import XCTest

final class ModelsTests: XCTestCase {
    func testAspectRatioTitlesDescribeWindowBehavior() {
        XCTAssertEqual(OverlayAspectRatio.source.title, "原始画面比例（推荐）")
        XCTAssertEqual(OverlayAspectRatio.free.title, "自由调整")
    }

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
    }

    func testCaptureResolutionsAreSortedFromSmallestToLargest() async {
        await MainActor.run {
            let options = [
                CameraResolutionOption(
                    id: "1552x1552",
                    label: "1552 × 1552",
                    width: 1552,
                    height: 1552,
                    frameRates: [30]
                ),
                CameraResolutionOption(
                    id: "1920x1080",
                    label: "1920 × 1080",
                    width: 1920,
                    height: 1080,
                    frameRates: [30]
                ),
                CameraResolutionOption(
                    id: "640x480",
                    label: "640 × 480",
                    width: 640,
                    height: 480,
                    frameRates: [30]
                ),
                CameraResolutionOption(
                    id: "1080x1920",
                    label: "1080 × 1920",
                    width: 1080,
                    height: 1920,
                    frameRates: [30]
                )
            ]

            let sorted = CameraSessionController.sortedByIncreasingResolution(options)

            XCTAssertEqual(
                sorted.map(\.id),
                ["640x480", "1080x1920", "1920x1080", "1552x1552"]
            )
        }
    }

    func testAutomaticCapturePrefersLowestResolutionAtThirtyFPS() async {
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
                ),
                CameraResolutionOption(
                    id: "640x480",
                    label: "640 × 480",
                    width: 640,
                    height: 480,
                    frameRates: [24, 30]
                )
            ]

            let selected = CameraSessionController.automaticResolutionOption(from: options)

            XCTAssertEqual(selected?.id, "640x480")
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

    func testSavedCaptureQualitySurvivesTemporaryCameraUnavailability() async {
        await MainActor.run {
            var saved = OverlaySettings.defaults
            saved.cameraResolutionID = "1920x1080"
            saved.cameraFrameRate = 30

            let sanitized = AppDelegate.sanitizedCameraSettings(
                saved,
                availableResolutions: [.auto],
                cameraIsAvailable: false
            )

            XCTAssertEqual(sanitized.cameraResolutionID, "1920x1080")
            XCTAssertEqual(sanitized.cameraFrameRate, 30)
        }
    }

    func testUnsupportedCaptureQualityFallsBackAfterCameraBecomesAvailable() async {
        await MainActor.run {
            var saved = OverlaySettings.defaults
            saved.cameraResolutionID = "1920x1080"
            saved.cameraFrameRate = 30

            let sanitized = AppDelegate.sanitizedCameraSettings(
                saved,
                availableResolutions: [.auto],
                cameraIsAvailable: true
            )

            XCTAssertEqual(sanitized.cameraResolutionID, CameraResolutionOption.auto.id)
            XCTAssertNil(sanitized.cameraFrameRate)
        }
    }

    func testNativeSquareCaptureQualityRemainsSelected() async {
        await MainActor.run {
            let squareOption = CameraResolutionOption(
                id: "1552x1552",
                label: "1552 × 1552",
                width: 1552,
                height: 1552,
                frameRates: [24, 30]
            )
            var saved = OverlaySettings.defaults
            saved.cameraResolutionID = squareOption.id

            let sanitized = AppDelegate.sanitizedCameraSettings(
                saved,
                availableResolutions: [.auto, squareOption],
                cameraIsAvailable: true
            )

            XCTAssertEqual(sanitized.cameraResolutionID, squareOption.id)
            XCTAssertEqual(sanitized.cameraFrameRate, 30)
        }
    }
}
