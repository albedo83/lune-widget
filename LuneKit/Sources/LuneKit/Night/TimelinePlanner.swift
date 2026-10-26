import Foundation

public enum TimelinePlanner {
    /// Dates after `now` at which the widget must re-render: moon and astro-night events, the next local midnight
    /// and the next display switch. Sorted, unique, all > `now`, within 24 h (the display switch is always kept,
    /// even if it falls a few minutes beyond, so the reload never lands before the switch).
    public static func refreshDates(after now: Date, location: GeoLocation, timeZone: TimeZone) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let horizon = now.addingTimeInterval(24 * 3600)
        let nextSwitch = NightCalculator.nextDisplaySwitch(after: now, location: location, timeZone: timeZone)

        var candidates: [Date] = []
        // The current night, and the one displayed right after the switch (its events may fall within 24 h).
        let reports = [
            NightCalculator.report(at: now, location: location, timeZone: timeZone),
            NightCalculator.report(at: nextSwitch.addingTimeInterval(1), location: location, timeZone: timeZone),
        ]
        for r in reports {
            candidates += [r.moonrise, r.moonset].compactMap { $0 }
            switch r.astroNight {
            case .interval(let i): candidates += [i.start, i.end]
            case .none, .wholePeriod: break
            }
            for w in r.darkWindows { candidates += [w.start, w.end] }
        }
        candidates.append(cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                                       matchingPolicy: .nextTime)!)

        var result = Set(candidates.filter { $0 > now && $0 <= horizon })
        result.insert(nextSwitch)
        return result.sorted()
    }
}
