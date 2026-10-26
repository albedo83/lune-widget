import XCTest
import LuneKit
import CoreLocation
@testable import Lune

final class CurrentPlaceLocatorTests: XCTestCase {
    private let when = Date(timeIntervalSince1970: 1_000)

    func testUsesLocalityAndTimeZone() {
        let info = PlacemarkInfo(locality: "Paris", name: "10 Rue X", timeZone: TimeZone(identifier: "Europe/Paris"))
        let p = CurrentPlaceLocator.makePlace(latitude: 48.85, longitude: 2.35, placemark: info, savedAt: when)
        XCTAssertEqual(p, StoredPlace(location: GeoLocation(latitude: 48.85, longitude: 2.35),
                                      timeZoneID: "Europe/Paris", name: "Paris", savedAt: when))
    }

    func testFallsBackToNameWhenNoLocality() {
        let info = PlacemarkInfo(locality: nil, name: "Mont Blanc", timeZone: nil)
        let p = CurrentPlaceLocator.makePlace(latitude: 1, longitude: 2, placemark: info, savedAt: when)
        XCTAssertEqual(p.name, "Mont Blanc")
        XCTAssertEqual(p.timeZoneID, TimeZone.current.identifier)
    }

    func testEmptyNameAndTimeZoneWithoutPlacemark() {
        let p = CurrentPlaceLocator.makePlace(latitude: 1, longitude: 2, placemark: nil, savedAt: when)
        XCTAssertEqual(p.name, "")
        XCTAssertEqual(p.timeZoneID, TimeZone.current.identifier)
    }

    func testAuthorizationStatuses() {
        XCTAssertTrue(CurrentPlaceLocator.isAuthorized(.authorizedAlways))
        XCTAssertFalse(CurrentPlaceLocator.isAuthorized(.denied))
        XCTAssertFalse(CurrentPlaceLocator.isAuthorized(.restricted))
        XCTAssertFalse(CurrentPlaceLocator.isAuthorized(.notDetermined))
    }
}
