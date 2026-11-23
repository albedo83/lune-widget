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

@Test func refreshDatesIncludeNextSwitch() {
    let dates = TimelinePlanner.refreshDates(after: local("2026-10-26 21:00"), location: parisLoc, timeZone: parisTZ)
    // Paris sunrise 2026-10-27 is about 07:29 local (CET, DST ended 10-25).
    let sunrise = local("2026-10-27 07:29")
    #expect(dates.contains { abs($0.timeIntervalSince(sunrise)) <= 120 })
    // Precise check: the displayed period changes right at that date.
    let switchDate = dates.first { abs($0.timeIntervalSince(sunrise)) <= 120 }!
    let before = NightCalculator.displayedPeriod(at: switchDate.addingTimeInterval(-120), location: parisLoc, timeZone: parisTZ)
    let after = NightCalculator.displayedPeriod(at: switchDate.addingTimeInterval(120), location: parisLoc, timeZone: parisTZ)
    #expect(before != after)
}

@Test func refreshDatesAreFutureSortedUnique() {
    let now = local("2026-10-26 21:00")
    let dates = TimelinePlanner.refreshDates(after: now, location: parisLoc, timeZone: parisTZ)
    #expect(!dates.isEmpty)
    #expect(dates.allSatisfy { $0 > now })
    #expect(dates == dates.sorted())
    #expect(Set(dates).count == dates.count)
    #expect(dates.contains(local("2026-10-27 00:00")))
    #expect(dates.last! <= now.addingTimeInterval(25 * 3600))
}

@Test func polarNoSunriseUsesNoon() {
    let tz = TimeZone(identifier: "Europe/Oslo")!
    let loc = GeoLocation(latitude: 69.65, longitude: 18.96)
    let dates = TimelinePlanner.refreshDates(after: local("2026-12-21 21:00", tz: "Europe/Oslo"), location: loc, timeZone: tz)
    #expect(dates.contains(local("2026-12-22 12:00", tz: "Europe/Oslo")))
}

@Test func refreshDatesIncludeSunset() {
    let dates = TimelinePlanner.refreshDates(after: local("2026-10-26 13:00"), location: parisLoc, timeZone: parisTZ)
    let sunset = local("2026-10-26 17:41")
    #expect(dates.contains { abs($0.timeIntervalSince(sunset)) <= 120 })
}

@Test func refreshDatesExcludeDarkWindowBounds() {
    // Dark-window bounds are no longer planning inputs: only moon, sun and astro-night events remain.
    let now = local("2026-11-20 20:00")
    let dates = TimelinePlanner.refreshDates(after: now, location: parisLoc, timeZone: parisTZ)
    let nextSwitch = NightCalculator.nextDisplaySwitch(after: now, location: parisLoc, timeZone: parisTZ)
    var allowed: Set<Date> = [nextSwitch, local("2026-11-21 00:00")]
    var windowBounds: Set<Date> = []
    for t in [now, nextSwitch.addingTimeInterval(1)] {
        let r = NightCalculator.report(at: t, location: parisLoc, timeZone: parisTZ)
        allowed.formUnion([r.moonrise, r.moonset, r.sunset, r.sunrise].compactMap { $0 })
        if case .interval(let i) = r.astroNight { allowed.formUnion([i.start, i.end]) }
        for w in r.darkWindows { windowBounds.formUnion([w.start, w.end]) }
    }
    #expect(!windowBounds.isEmpty)
    #expect(dates.allSatisfy { allowed.contains($0) })
    // A dark-window bound that is not another event must not be scheduled.
    for d in windowBounds.subtracting(allowed) { #expect(!dates.contains(d)) }
}
