import Testing
import Foundation
@testable import LuneKit

@Test func julianDayOfJ2000() {
    let d = ISO8601DateFormatter().date(from: "2000-01-01T12:00:00Z")!
    #expect(abs(JulianDay.jd(d) - 2451545.0) < 1e-6)
}

@Test func julianDayRoundTrip() {
    let d = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(abs(JulianDay.date(jd: JulianDay.jd(d)).timeIntervalSince(d)) < 1e-3)
}

@Test func sunMeeusExample25a() {   // 1992-10-13 0h TD
    let d = JulianDay.date(jd: 2448908.5 - 69.0/86400)
    let s = SunEphemeris.apparent(at: d)
    #expect(abs(s.rightAscension - 198.38083) < 0.01)
    #expect(abs(s.declination - (-7.78507)) < 0.01)
    #expect(abs(s.distanceKm / 149_597_870.7 - 0.99766) < 0.0005)
}
