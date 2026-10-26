import CoreLocation
import XCTest
@testable import Lune

@MainActor
final class AuthorizationWaiterTests: XCTestCase {
    func testTimesOutWhenNoDecisionArrives() async {
        let waiter = AuthorizationWaiter()
        let result = await waiter.wait(timeout: .milliseconds(50)) {}
        XCTAssertNil(result)
        waiter.deliver(.authorizedAlways) // late delivery after timeout must be a harmless no-op
    }

    func testReturnsDeliveredStatusAndIgnoresUndetermined() async {
        let waiter = AuthorizationWaiter()
        let result = await waiter.wait(timeout: .seconds(5)) {
            waiter.deliver(.notDetermined)
            Task { @MainActor in waiter.deliver(.denied) }
        }
        XCTAssertEqual(result, .denied)
    }
}
