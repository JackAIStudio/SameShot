import Foundation
@testable import SameShot
import XCTest

final class SettingsStoreTests: XCTestCase {
    func testLegacySettingsMigrateIntoCanonicalPreferencesDomain() async throws {
        try await MainActor.run {
            let canonicalSuiteName = "SameShotTests.canonical.\(UUID().uuidString)"
            let legacySuiteName = "SameShotTests.legacy.\(UUID().uuidString)"
            guard let canonicalDefaults = UserDefaults(suiteName: canonicalSuiteName),
                  let legacyDefaults = UserDefaults(suiteName: legacySuiteName) else {
                XCTFail("无法创建测试偏好域")
                return
            }
            defer {
                UserDefaults.standard.removePersistentDomain(forName: canonicalSuiteName)
                UserDefaults.standard.removePersistentDomain(forName: legacySuiteName)
            }

            var legacySettings = OverlaySettings.defaults
            legacySettings.mirrorCamera = false
            legacySettings.cameraResolutionID = "1280x720"
            legacySettings.cameraFrameRate = 30
            let data = try JSONEncoder().encode(legacySettings)
            legacyDefaults.set(data, forKey: "SameShot.overlaySettings")

            let store = SettingsStore(
                defaults: canonicalDefaults,
                legacyDefaults: [legacyDefaults]
            )
            let loaded = store.load()

            XCTAssertFalse(loaded.mirrorCamera)
            XCTAssertEqual(loaded.cameraResolutionID, "1280x720")
            XCTAssertEqual(loaded.cameraFrameRate, 30)
            XCTAssertEqual(
                canonicalDefaults.data(forKey: "SameShot.overlaySettings"),
                data
            )
        }
    }
}
