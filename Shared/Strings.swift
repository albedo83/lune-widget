import Foundation
import LuneKit

/// User-visible text. Keys are the English source strings of `Localizable.xcstrings`; lookups pick the
/// `.lproj` matching the given locale so the text and its date/number formatting always agree.
enum Strings {
    private final class BundleToken {}
    static var bundle: Bundle { Bundle(for: BundleToken.self) }

    static let noDarkWindow = "No dark window tonight"
    static let noAstroNight = "No astronomical night"
    static let allNight = "All night"
    static let night = "night"
    static let currentLocation = "Current Location"
    static let chooseCity = "Choose a city: right-click › Edit Widget"

    /// Localized value of `key` in the language of `locale` (falls back to the bundle's preferred language).
    static func localized(_ key: String, locale: Locale) -> String {
        if let lang = locale.language.languageCode?.identifier,
           let path = bundle.path(forResource: lang, ofType: "lproj"),
           let lproj = Bundle(path: path) {
            return lproj.localizedString(forKey: key, value: key, table: nil)
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func phaseKey(_ n: MoonPhaseName) -> String {
        switch n {
        case .newMoon: "New moon"
        case .waxingCrescent: "Waxing crescent"
        case .firstQuarter: "First quarter"
        case .waxingGibbous: "Waxing gibbous"
        case .fullMoon: "Full moon"
        case .waningGibbous: "Waning gibbous"
        case .lastQuarter: "Last quarter"
        case .waningCrescent: "Waning crescent"
        }
    }

    static func phase(_ n: MoonPhaseName) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(phaseKey(n)), bundle: .atURL(bundle.bundleURL))
    }

    static func phaseText(_ n: MoonPhaseName, locale: Locale) -> String {
        localized(phaseKey(n), locale: locale)
    }

    /// "HH:mm", always 24 h, in `tz`, rounded to the nearest minute.
    static func time(_ date: Date, tz: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: roundedToMinute(date))
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }

    static func time(_ date: Date?, tz: TimeZone) -> String {
        date.map { time($0, tz: tz) } ?? "—"
    }

    /// "10 h 36" (fr), "10h 36m" (en)… from whole minutes.
    static func duration(minutes: Int, locale: Locale) -> String {
        String(format: localized("%lldh %02lldm", locale: locale), locale: locale, minutes / 60, minutes % 60)
    }

    /// The dark-window chip: "No dark window tonight", one window with its duration, or several with the total.
    static func darkWindow(_ w: [DateInterval], tz: TimeZone, locale: Locale) -> String {
        guard let first = w.first else { return localized(noDarkWindow, locale: locale) }
        let minutes = w.reduce(0) { $0 + wholeMinutes($1) }
        let total = duration(minutes: minutes, locale: locale)
        if w.count == 1 {
            return String(format: localized("Dark window %@ → %@ (%@)", locale: locale), locale: locale,
                          time(first.start, tz: tz), time(first.end, tz: tz), total)
        }
        let ranges = w.map { "\(time($0.start, tz: tz)) → \(time($0.end, tz: tz))" }.joined(separator: " · ")
        return String(format: localized("Dark windows %@ (%@)", locale: locale), locale: locale, ranges, total)
    }

    /// "Nouvelle lune dans 14 j (9 nov.)": calendar days between the local days of `now` and `date` in `tz`.
    static func nextPhase(_ p: PrincipalPhase, date: Date, now: Date, tz: TimeZone, locale: Locale) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        let day = date.formatted(Date.FormatStyle(locale: locale, timeZone: tz).day().month(.abbreviated))
        let key = p == .full ? "Full moon in %lld d (%@)" : "New moon in %lld d (%@)"
        return String(format: localized(key, locale: locale), locale: locale, days, day)
    }

    static func percent(_ illumination: Double, locale: Locale) -> String {
        illumination.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    private static func roundedToMinute(_ d: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (d.timeIntervalSinceReferenceDate / 60).rounded() * 60)
    }

    /// Minutes between the displayed (rounded) start and end, so the duration matches the shown times.
    private static func wholeMinutes(_ i: DateInterval) -> Int {
        Int((roundedToMinute(i.end).timeIntervalSince(roundedToMinute(i.start)) / 60).rounded())
    }
}
