import XCTest
import LuneKit
@testable import Lune

final class LocationStoreTests: XCTestCase {
    private func makeStore(_ defaults: UserDefaults = UserDefaults(suiteName: UUID().uuidString)!) -> LocationStore {
        LocationStore(defaults: defaults)
    }

    func testClearingStoredPlaceReturnsNil() {
        let store = makeStore()
        store.current = StoredPlace(location: GeoLocation(latitude: 1, longitude: 2),
                                    timeZoneID: "UTC", name: "X", savedAt: Date())
        store.current = nil
        XCTAssertNil(store.current)
    }

    func testCorruptDataReturnsNil() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(Data("not json".utf8), forKey: "storedPlace")
        XCTAssertNil(makeStore(defaults).current)
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
