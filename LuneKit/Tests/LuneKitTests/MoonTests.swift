import Testing
import Foundation
@testable import LuneKit

@Test func moonMeeusExample47a() {  // 1992-04-12 0h TD
    let d = JulianDay.date(jd: 2448724.5 - 69.0/86400)
    let m = MoonEphemeris.apparent(at: d)
    #expect(abs(m.rightAscension - 134.688470) < 0.005)
    #expect(abs(m.declination - 13.768368) < 0.005)
    #expect(abs(m.distanceKm - 368409.7) < 5)
}

@Test func moonGeometricMeeusExample47a() {  // series check, tighter than the brief
    let d = JulianDay.date(jd: 2448724.5 - 69.0/86400)
    let g = MoonEphemeris.geometric(at: d)
    #expect(abs(g.longitude - 133.162655) < 0.00001)
    #expect(abs(g.latitude - (-3.229126)) < 0.00001)
    #expect(abs(g.distanceKm - 368409.7) < 0.1)
    #expect(abs(MoonEphemeris.apparentLongitude(at: d) - 133.167265) < 0.0002)
}

@Test func illuminationMeeusExample48a() {
    let d = JulianDay.date(jd: 2448724.5 - 69.0/86400)
    #expect(abs(MoonPhases.illumination(at: d) - 0.6786) < 0.002)
}

@Test func elongationIsMoonMinusSunLongitude() {
    let d = JulianDay.date(jd: 2448724.5 - 69.0/86400)
    let expected = AngleMath.normalize(MoonEphemeris.apparentLongitude(at: d) - SunEphemeris.apparentLongitude(at: d))
    #expect(abs(MoonPhases.elongation(at: d) - expected) < 1e-9)
    #expect(expected > 90 && expected < 180)  // waxing gibbous, k ≈ 0.68
}

@Test func siderealTimeMeeusExample12a() {  // 1987-04-10 0h UT
    let d = JulianDay.date(jd: 2446895.5)
    #expect(abs(Horizon.apparentSiderealTime(at: d) - 197.692230) < 0.0005)  // 13h10m46.1351s
}

@Test func sunNoonAltitudeParis() { // 2026-10-26 11:35 UTC = solar noon
    let paris = GeoLocation(latitude: 48.8566, longitude: 2.3522)
    let d = ISO8601DateFormatter().date(from: "2026-10-26T11:35:00Z")!
    #expect(abs(Horizon.sunAltitude(at: d, from: paris) - 28.7) < 0.3)
}

@Test func moonAltitudeIncludesParallax() {
    // Topocentric altitude is lower than geocentric by ≈ π·cos h (π ≈ 0.9–1.0°).
    let paris = GeoLocation(latitude: 48.8566, longitude: 2.3522)
    let d = ISO8601DateFormatter().date(from: "2026-10-26T20:00:00Z")!
    let topo = Horizon.moonAltitude(at: d, from: paris)
    let geo = Horizon.geocentricAltitude(of: MoonEphemeris.apparent(at: d), at: d, from: paris)
    let parallax = AngleMath.deg(asin(6378.14 / MoonEphemeris.apparent(at: d).distanceKm))
    #expect(abs((geo - topo) - parallax * cos(AngleMath.rad(geo))) < 0.02)
}
