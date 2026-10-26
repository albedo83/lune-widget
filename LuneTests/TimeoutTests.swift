import XCTest
@testable import Lune

final class TimeoutTests: XCTestCase {
    /// An operation that ignores cancellation and only finishes after 30 s.
    private static func stubborn() async -> Int? {
        await withUnsafeContinuation { c in
            DispatchQueue.global().asyncAfter(deadline: .now() + 30) { c.resume(returning: 1) }
        }
    }

    func testReturnsNilAtDeadlineEvenIfOperationIgnoresCancellation() async {
        let timedOut = expectation(description: "onTimeout called")
        let start = Date()
        let value = await withTimeout(.milliseconds(300), operation: { await Self.stubborn() },
                                      onTimeout: { timedOut.fulfill() })
        XCTAssertNil(value)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
        await fulfillment(of: [timedOut], timeout: 1)
    }

    func testReturnsValueWhenOperationFinishesInTime() async {
        let value = await withTimeout(.seconds(5), operation: { 42 }, onTimeout: { XCTFail("timed out") })
        XCTAssertEqual(value, 42)
    }
}
