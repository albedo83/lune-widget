import Testing
import Foundation
@testable import LuneKit

@Suite struct PhaseTests {
    static func utc(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

    @Test(arguments: [
        (PrincipalPhase.full, "2026-10-20T00:00:00Z", "2026-10-26T04:12:00Z"),
        (.lastQuarter, "2026-10-27T00:00:00Z", "2026-11-01T20:28:00Z"),
        (.new, "2026-10-27T00:00:00Z", "2026-11-09T07:02:00Z"),
        (.firstQuarter, "2026-11-10T00:00:00Z", "2026-11-17T11:48:00Z"),
        (.full, "2026-11-10T00:00:00Z", "2026-11-24T14:53:00Z"),
    ])
    func nextPhase(phase: PrincipalPhase, after: String, expected: String) {
        let d = MoonPhases.next(phase, after: Self.utc(after))
        let diff = d.timeIntervalSince(Self.utc(expected))
        print("PHASE \(phase) computed \(d) usno \(expected) diff \(Int(diff)) s")
        #expect(abs(diff) <= 300)
    }

    @Test func principalInInterval() {
        let full = Self.utc("2026-10-26T04:12:00Z")
        #expect(MoonPhases.principal(in: DateInterval(start: full.addingTimeInterval(-12 * 3600), duration: 25 * 3600)) == .full)
        #expect(MoonPhases.principal(in: DateInterval(start: full.addingTimeInterval(24 * 3600), duration: 25 * 3600)) == nil)
        let new = Self.utc("2026-11-09T07:02:00Z")
        #expect(MoonPhases.principal(in: DateInterval(start: new.addingTimeInterval(-10 * 3600), duration: 25 * 3600)) == .new)
    }

    @Test func names() {
        #expect(MoonPhaseName(principalInPeriod: nil, elongationAtReference: 20) == .waxingCrescent)
        #expect(MoonPhaseName(principalInPeriod: nil, elongationAtReference: 200) == .waningGibbous)
        #expect(MoonPhaseName(principalInPeriod: .full, elongationAtReference: 178) == .fullMoon)
        #expect(MoonPhaseName(principalInPeriod: nil, elongationAtReference: 359.9) == .waningCrescent)
        #expect(MoonPhaseName(principalInPeriod: nil, elongationAtReference: 100) == .waxingGibbous)
    }
}
