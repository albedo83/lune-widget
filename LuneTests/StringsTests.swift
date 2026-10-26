import XCTest
import LuneKit
@testable import Lune

final class StringsTests: XCTestCase {
    private let paris = TimeZone(identifier: "Europe/Paris")!
    private let fr = Locale(identifier: "fr_FR")

    private func parisDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = paris
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testFrenchDarkWindow() {
        let window = DateInterval(start: parisDate(2026, 11, 10, 19, 8), end: parisDate(2026, 11, 11, 5, 44))
        XCTAssertEqual(Strings.darkWindow([window], tz: paris, locale: fr), "Fenêtre noire 19:08 → 05:44 (10 h 36)")
    }

    func testFrenchNoDarkWindow() {
        XCTAssertEqual(Strings.darkWindow([], tz: paris, locale: fr), "Pas de fenêtre noire ce soir")
    }

    func testFrenchNextPhase() {
        let text = Strings.nextPhase(.new, date: parisDate(2026, 11, 9, 8, 2), now: parisDate(2026, 10, 26, 12, 0),
                                     tz: paris, locale: fr)
        XCTAssertEqual(text, "Nouvelle lune dans 14 j (9 nov.)")
    }

    func testEveryCatalogKeyHasFiveLanguages() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Shared/Localizable.xcstrings")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: Any])
        XCTAssertFalse(strings.isEmpty, "catalog is empty")
        for (key, value) in strings {
            let entry = try XCTUnwrap(value as? [String: Any], key)
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            for lang in ["en", "fr", "de", "es", "it"] {
                let unit = (localizations[lang] as? [String: Any])?["stringUnit"] as? [String: Any]
                XCTAssertEqual(unit?["state"] as? String, "translated", "\(key) [\(lang)]")
                XCTAssertFalse((unit?["value"] as? String ?? "").isEmpty, "\(key) [\(lang)]")
            }
        }
    }
}
