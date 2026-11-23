import XCTest
@testable import Lune

final class PlaceIDTests: XCTestCase {
    private func roundTrip(_ name: String, _ lat: Double, _ lon: Double, _ tz: String,
                           file: StaticString = #filePath, line: UInt = #line) throws {
        let id = PlaceID.make(latitude: lat, longitude: lon, timeZoneID: tz, name: name)
        let p = try XCTUnwrap(PlaceID.parse(id), id, file: file, line: line)
        XCTAssertEqual(p.name, name, file: file, line: line)
        XCTAssertEqual(p.timeZoneID, tz, file: file, line: line)
        XCTAssertEqual(p.latitude, lat, accuracy: 1e-5, file: file, line: line)
        XCTAssertEqual(p.longitude, lon, accuracy: 1e-5, file: file, line: line)
    }

    func testRoundTrip() throws {
        try roundTrip("Fuveau", 43.4539, 5.56093, "Europe/Paris")
    }

    func testAwkwardNamesRoundTrip() throws {
        try roundTrip("Saint-Étienne", 45.4397, 4.3872, "Europe/Paris")
        try roundTrip("Rio de Janeiro", -22.9068, -43.1729, "America/Sao_Paulo")
        try roundTrip("A|B,C", 1.5, -2.5, "UTC")
        try roundTrip("Lune 🌙", 10, 20, "Asia/Tokyo")
    }

    func testLegacyIDHasCoordinatesOnly() throws {
        let p = try XCTUnwrap(PlaceID.parse("43.45390,5.56093"))
        XCTAssertEqual(p.latitude, 43.4539, accuracy: 1e-5)
        XCTAssertEqual(p.longitude, 5.56093, accuracy: 1e-5)
        XCTAssertEqual(p.name, "")
        XCTAssertNil(p.timeZoneID)
    }

    func testCurrentAndGarbageAreNil() {
        for id in ["current", "", "abc", "v1|x|y|UTC|n", "v1|1|2", "1,2,3", "v2|1|2|UTC|n"] {
            XCTAssertNil(PlaceID.parse(id), id)
        }
    }

    func testCoordinateLabel() {
        XCTAssertEqual(PlaceID.coordinateLabel(latitude: 43.4539, longitude: 5.56093), "43.45° N, 5.56° E")
        XCTAssertEqual(PlaceID.coordinateLabel(latitude: -22.9068, longitude: -43.1729), "22.91° S, 43.17° W")
    }
}
