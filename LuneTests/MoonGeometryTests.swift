import XCTest
@testable import Lune

final class MoonGeometryTests: XCTestCase {
    func testTerminatorAtFullIsMinusOne() {
        XCTAssertEqual(MoonGeometry.terminatorScaleX(illumination: 1), -1, accuracy: 1e-12)
    }

    func testTerminatorAtNewIsOne() {
        XCTAssertEqual(MoonGeometry.terminatorScaleX(illumination: 0), 1, accuracy: 1e-12)
    }

    func testTerminatorAtQuarterIsZero() {
        XCTAssertEqual(MoonGeometry.terminatorScaleX(illumination: 0.5), 0, accuracy: 1e-12)
    }

    func testLitSideFlipsInSouthernHemisphere() {
        XCTAssertTrue(MoonGeometry.litOnRight(isWaxing: true, latitude: 48))
        XCTAssertFalse(MoonGeometry.litOnRight(isWaxing: true, latitude: -33))
        XCTAssertFalse(MoonGeometry.litOnRight(isWaxing: false, latitude: 48))
        XCTAssertTrue(MoonGeometry.litOnRight(isWaxing: false, latitude: -33))
    }
}
