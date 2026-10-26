import Testing
import Foundation
@testable import LuneKit

private let parisLoc = GeoLocation(latitude: 48.8566, longitude: 2.3522)
private let parisTZ = TimeZone(identifier: "Europe/Paris")!

private func local(_ s: String, tz: String = "Europe/Paris") -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: tz)
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}

private func utc(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

private func near(_ a: Date?, _ b: Date, _ tol: TimeInterval = 120) -> Bool {
    guard let a else { return false }
    return abs(a.timeIntervalSince(b)) <= tol
}

@Test func paris20261026() {
    let r = NightCalculator.report(at: local("2026-10-26 21:00"), location: parisLoc, timeZone: parisTZ)
    #expect(r.period == DateInterval(start: local("2026-10-26 12:00"), end: local("2026-10-27 12:00")))
    #expect(near(r.moonrise, local("2026-10-26 17:21")))
    #expect(near(r.moonset, local("2026-10-27 09:23")))
    guard case .interval(let astro) = r.astroNight else { Issue.record("expected interval, got \(r.astroNight)"); return }
    #expect(astro.start >= local("2026-10-26 19:00") && astro.start <= local("2026-10-26 19:40"))
    #expect(r.darkWindows.isEmpty)
    #expect(r.phaseName == .waningGibbous)
    #expect(r.illumination > 0.95)
    #expect(!r.isWaxing)
    #expect(r.nextPhase == .new)
    #expect(near(r.nextPhaseDate, utc("2026-11-09T07:02:00Z"), 300))
}

@Test func paris20261110() {
    let r = NightCalculator.report(at: local("2026-11-10 20:00"), location: parisLoc, timeZone: parisTZ)
    #expect(r.period == DateInterval(start: local("2026-11-10 12:00"), end: local("2026-11-11 12:00")))
    #expect(near(r.moonset, local("2026-11-10 17:20")))
    #expect(near(r.moonrise, local("2026-11-11 10:34")))
    guard case .interval(let astro) = r.astroNight else { Issue.record("expected interval, got \(r.astroNight)"); return }
    #expect(r.darkWindows == [astro])
    #expect(r.phaseName == .waxingCrescent)
    #expect(r.isWaxing)
    #expect(r.illumination < 0.08)
    #expect(r.nextPhase == .full)
    #expect(near(r.nextPhaseDate, utc("2026-11-24T14:53:00Z"), 300))
}

@Test func paris20260621() {
    let r = NightCalculator.report(at: local("2026-06-21 22:00"), location: parisLoc, timeZone: parisTZ)
    #expect(r.astroNight == .none)
    #expect(r.darkWindows.isEmpty)
    #expect(near(r.moonrise, local("2026-06-21 13:30")))
}

@Test func northPoleWinter() {
    let r = NightCalculator.report(
        at: utc("2026-12-21T18:00:00Z"),
        location: GeoLocation(latitude: 89, longitude: 0),
        timeZone: TimeZone(identifier: "UTC")!
    )
    #expect(r.astroNight == .wholePeriod)
}

@Test func switchesAtSunrise() {
    let before = NightCalculator.displayedPeriod(at: local("2026-10-27 07:00"), location: parisLoc, timeZone: parisTZ)
    #expect(before.start == local("2026-10-26 12:00"))
    let after = NightCalculator.displayedPeriod(at: local("2026-10-27 07:45"), location: parisLoc, timeZone: parisTZ)
    #expect(after.start == local("2026-10-27 12:00"))
}

@Test func periodAcrossDSTIsLocalNoonToNoon() {
    let p = NightCalculator.displayedPeriod(at: local("2026-10-24 21:00"), location: parisLoc, timeZone: parisTZ)
    #expect(p.start == utc("2026-10-24T10:00:00Z"))
    #expect(p.end == utc("2026-10-25T11:00:00Z"))
    #expect(p.duration == 90000)
}

@Test func reportUsesPlaceTimeZone() {
    let r = NightCalculator.report(
        at: utc("2026-10-26T10:00:00Z"),
        location: GeoLocation(latitude: -33.87, longitude: 151.21),
        timeZone: TimeZone(identifier: "Australia/Sydney")!
    )
    #expect(r.period.start == utc("2026-10-26T01:00:00Z"))
    #expect(r.period.start == local("2026-10-26 12:00", tz: "Australia/Sydney"))
}
