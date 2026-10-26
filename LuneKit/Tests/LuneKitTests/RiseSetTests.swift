import Testing
import Foundation
@testable import LuneKit

private let parisLocation = GeoLocation(latitude: 48.8566, longitude: 2.3522)

private func paris(_ s: String, tz: String = "Europe/Paris") -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: tz)
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}

private func dayInterval(_ day: String) -> DateInterval {
    let start = paris("\(day) 00:00")
    return DateInterval(start: start, end: Calendar.parisCalendar.date(byAdding: .day, value: 1, to: start)!)
}

private extension Calendar {
    static var parisCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris")!
        return c
    }
}

private func riseSet(body: String, day: String, rising: Bool) -> Date? {
    let loc = parisLocation
    let f: (Date) -> Double = body == "moon"
        ? { Horizon.moonAltitude(at: $0, from: loc) }
        : { Horizon.sunAltitude(at: $0, from: loc) }
    return EventSearch.crossings(in: dayInterval(day), threshold: Altitudes.riseSet, f)
        .first { $0.isRising == rising }?.date
}

private struct Ref: Sendable, CustomTestStringConvertible {
    let day: String, body: String, rising: Bool, local: String
    var testDescription: String { "\(body) \(rising ? "rise" : "set") \(day)" }
}

@Test(arguments: [
    Ref(day: "2026-10-26", body: "moon", rising: true, local: "17:21"),
    Ref(day: "2026-10-26", body: "moon", rising: false, local: "07:57"),
    Ref(day: "2026-10-27", body: "moon", rising: false, local: "09:23"),
    Ref(day: "2026-11-10", body: "moon", rising: false, local: "17:20"),
    Ref(day: "2026-11-11", body: "moon", rising: true, local: "10:34"),
    Ref(day: "2026-10-26", body: "sun", rising: true, local: "07:28"),
    Ref(day: "2026-10-26", body: "sun", rising: false, local: "17:41"),
    Ref(day: "2026-06-21", body: "moon", rising: true, local: "13:30"),
])
private func riseSetMatchesUSNO(_ r: Ref) throws {
    let got = try #require(riseSet(body: r.body, day: r.day, rising: r.rising))
    let expected = paris("\(r.day) \(r.local)")
    let diff = got.timeIntervalSince(expected)
    #expect(abs(diff) <= 120, "\(r.testDescription): got \(got), expected \(expected), diff \(diff) s")
}

@Test func noAstronomicalNightParisJune21() {
    let loc = parisLocation
    let interval = DateInterval(start: paris("2026-06-21 12:00"), end: paris("2026-06-22 12:00"))
    let c = EventSearch.crossings(in: interval, threshold: Altitudes.astronomical) {
        Horizon.sunAltitude(at: $0, from: loc)
    }
    #expect(c.isEmpty)
}

@Test func astroDuskIsMinus18() throws {
    let loc = parisLocation
    let interval = DateInterval(start: paris("2026-10-26 12:00"), end: paris("2026-10-27 00:00"))
    let c = EventSearch.crossings(in: interval, threshold: Altitudes.astronomical) {
        Horizon.sunAltitude(at: $0, from: loc)
    }
    let dusk = try #require(c.first { !$0.isRising })
    #expect(abs(Horizon.sunAltitude(at: dusk.date, from: loc) + 18) < 0.01)
    #expect(dusk.date >= paris("2026-10-26 19:00") && dusk.date <= paris("2026-10-26 19:40"))
}
