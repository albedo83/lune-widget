import Foundation
import LuneKit

/// User-visible text. Keys are the English source strings of `Localizable.xcstrings`; lookups pick the
/// `.lproj` matching the given locale so the text and its date/number formatting always agree.
enum Strings {
    private final class BundleToken {}
    static var bundle: Bundle { Bundle(for: BundleToken.self) }

    static let noAstroNight = "No astronomical night"
    static let allNight = "All night"
    static let night = "night"
    static let currentLocation = "Current Location"
    static let howToAdd = "Add the widget: right-click the desktop, choose Edit Widgets, then search for “Lune”. To change the place, right-click the widget and choose Edit “Lune”."
    static let useMyLocation = "Use my location"
    static let locating = "Locating…"
    static let locationDenied = "Location access is off for Lune. Allow it in System Settings › Privacy & Security › Location Services."
    static let locationFailed = "Could not determine your location. Try again."
    static let preview = "Preview"
    static let previewHint = "Press “Use my location” to see tonight’s preview."
    static let chooseCity = "Choose a city: right-click › Edit Widget"
    static let moonCredit = "Moon imagery: NASA's Scientific Visualization Studio"

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

    /// "Nouvelle lune dans 14 j (9 nov.)": calendar days between the local days of `now` and `date` in `tz`.
    static func nextPhase(_ p: PrincipalPhase, date: Date, now: Date, tz: TimeZone, locale: Locale) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        let day = date.formatted(Date.FormatStyle(locale: locale, timeZone: tz).day().month(.abbreviated))
        if days <= 0 {
            let key = p == .full ? "Full moon today (%@)" : "New moon today (%@)"
            return String(format: localized(key, locale: locale), locale: locale, day)
        }
        let key = p == .full ? "Full moon in %lld d (%@)" : "New moon in %lld d (%@)"
        return String(format: localized(key, locale: locale), locale: locale, days, day)
    }

    static func percent(_ illumination: Double, locale: Locale) -> String {
        illumination.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    private static func roundedToMinute(_ d: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (d.timeIntervalSinceReferenceDate / 60).rounded() * 60)
    }
}
