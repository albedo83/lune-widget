import SwiftUI
import XCTest
@testable import Lune

final class MoonFrameTests: XCTestCase {
    func testElongationAtNewAndFull() {
        XCTAssertEqual(MoonFrame.elongation(illumination: 0, isWaxing: true), 0, accuracy: 1e-9)
        XCTAssertEqual(MoonFrame.elongation(illumination: 1, isWaxing: true), 180, accuracy: 1e-9)
    }

    func testElongationAtQuarters() {
        XCTAssertEqual(MoonFrame.elongation(illumination: 0.5, isWaxing: true), 90, accuracy: 0.01)
        XCTAssertEqual(MoonFrame.elongation(illumination: 0.5, isWaxing: false), 270, accuracy: 0.01)
    }

    func testFrameNames() {
        XCTAssertEqual(MoonFrame.name(illumination: 0.5, isWaxing: true), "moon-090")
        XCTAssertEqual(MoonFrame.name(illumination: 0.999, isWaxing: false), "moon-185")
        XCTAssertEqual(MoonFrame.name(illumination: 0.0001, isWaxing: false), "moon-000")
    }

    func testRotationFlipsInSouthernHemisphere() {
        XCTAssertEqual(MoonFrame.rotation(latitude: 48).degrees, 0, accuracy: 1e-9)
        XCTAssertEqual(MoonFrame.rotation(latitude: -33).degrees, 180, accuracy: 1e-9)
    }

    func testEveryFrameIsInTheAssetCatalog() {
        for e in stride(from: 0, to: 360, by: 5) {
            XCTAssertNotNil(MoonFrame.bundle.image(forResource: String(format: "moon-%03d", e)), "moon-\(e)")
        }
    }
}
