import XCTest
import LuneKit
@testable import Lune

final class LocationStoreTests: XCTestCase {
    private func makeStore() -> LocationStore {
        LocationStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    func testRoundTripsStoredPlace() {
        let store = makeStore()
        let place = StoredPlace(location: GeoLocation(latitude: 48.85, longitude: 2.35),
                                timeZoneID: "Europe/Paris", name: "Paris",
                                savedAt: Date(timeIntervalSince1970: 1_700_000_000))
        store.current = place
        XCTAssertEqual(store.current, place)
    }

    func testResolveCurrentWithoutStoredLocationReturnsNil() {
        XCTAssertNil(resolveCurrent(store: makeStore()))
    }
}
