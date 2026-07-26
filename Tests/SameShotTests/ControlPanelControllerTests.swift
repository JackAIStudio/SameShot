import AppKit
@testable import SameShot
import XCTest

final class ControlPanelControllerTests: XCTestCase {
    func testControlPanelCanInitialize() async {
        await MainActor.run {
            _ = NSApplication.shared
            let controller = ControlPanelController()

            XCTAssertNotNil(controller.window)
        }
    }
}
