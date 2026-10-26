import Foundation

public enum NightCalculator {
    /// Shortest dark window kept, seconds.
    private static let minimumWindow: TimeInterval = 60

    /// The night shown at `now`: local noon day J → local noon day J+1 in `timeZone`, where night J starts being
    /// shown at sunrise on day J (or local noon if the Sun does not rise that morning).
    public static func displayedPeriod(at now: Date, location: GeoLocation, timeZone: TimeZone) -> DateInterval {
        let cal = calendar(timeZone)
        let midnight = cal.startOfDay(for: now)
        let noon = localNoon(of: midnight, cal)
        let sunrise = EventSearch.crossings(in: DateInterval(start: midnight, end: noon), threshold: Altitudes.riseSet) {
            Horizon.sunAltitude(at: $0, from: location)
        }.first { $0.isRising }?.date
        let nightDay = now < (sunrise ?? noon) ? cal.date(byAdding: .day, value: -1, to: midnight)! : midnight
        let nextDay = cal.date(byAdding: .day, value: 1, to: nightDay)!
        return DateInterval(start: localNoon(of: nightDay, cal), end: localNoon(of: nextDay, cal))
    }

    public static func report(at now: Date, location: GeoLocation, timeZone: TimeZone) -> NightReport {
        let period = displayedPeriod(at: now, location: location, timeZone: timeZone)
        let moonAltitude: (Date) -> Double = { Horizon.moonAltitude(at: $0, from: location) }

        let moonEvents = EventSearch.crossings(in: period, threshold: Altitudes.riseSet, moonAltitude)
        let astro = astroNight(in: period, location: location)

        let darkDomain: DateInterval?
        switch astro {
        case .none: darkDomain = nil
        case .wholePeriod: darkDomain = period
        case .interval(let i): darkDomain = i
        }
        let darkWindows = darkDomain.map { belowIntervals(in: $0, threshold: Altitudes.riseSet, moonAltitude) }?
            .filter { $0.duration >= minimumWindow } ?? []

        let reference = midpoint(darkDomain ?? period)
        let elongation = MoonPhases.elongation(at: reference)
        let isWaxing = elongation < 180
        // Chosen at the period end, not at the reference: a principal phase between the two must not be repeated.
        let nextPhase: PrincipalPhase = MoonPhases.elongation(at: period.end) < 180 ? .full : .new

        return NightReport(
            period: period,
            moonrise: moonEvents.first { $0.isRising }?.date,
            moonset: moonEvents.first { !$0.isRising }?.date,
            astroNight: astro,
            darkWindows: darkWindows,
            referenceDate: reference,
            illumination: MoonPhases.illumination(at: reference),
            isWaxing: isWaxing,
            phaseName: MoonPhaseName(principalInPeriod: MoonPhases.principal(in: period), elongationAtReference: elongation),
            nextPhase: nextPhase,
            nextPhaseDate: MoonPhases.next(nextPhase, after: period.end)
        )
    }

    // MARK: - Helpers

    private static func astroNight(in period: DateInterval, location: GeoLocation) -> AstroNight {
        let sunAltitude: (Date) -> Double = { Horizon.sunAltitude(at: $0, from: location) }
        let below = belowIntervals(in: period, threshold: Altitudes.astronomical, sunAltitude)
        guard let first = below.first else { return .none }
        if first == period { return .wholePeriod }
        // From the first descent (or the period start) to the following ascent (or the period end).
        return .interval(first)
    }

    /// Maximal sub-intervals of `interval` where `f` is below `threshold`.
    private static func belowIntervals(
        in interval: DateInterval, threshold: Double, _ f: (Date) -> Double
    ) -> [DateInterval] {
        var result: [DateInterval] = []
        var start: Date? = f(interval.start) < threshold ? interval.start : nil
        for c in EventSearch.crossings(in: interval, threshold: threshold, f) {
            if c.isRising {
                if let s = start { result.append(DateInterval(start: s, end: c.date)) }
                start = nil
            } else {
                start = c.date
            }
        }
        if let s = start { result.append(DateInterval(start: s, end: interval.end)) }
        return result
    }

    private static func midpoint(_ i: DateInterval) -> Date { i.start.addingTimeInterval(i.duration / 2) }

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    private static func localNoon(of day: Date, _ cal: Calendar) -> Date {
        cal.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
    }
}
