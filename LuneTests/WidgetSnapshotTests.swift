import AppKit
import SwiftUI
import XCTest
@testable import Lune

/// Renders the widget view for Paris to PNG files when `LUNE_SNAPSHOT_DIR` is set (pass it to xcodebuild as
/// `TEST_RUNNER_LUNE_SNAPSHOT_DIR=…`); otherwise only checks that the view renders.
@MainActor
final class WidgetSnapshotTests: XCTestCase {
    private func parisNoon(_ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        return cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func render(_ entry: NightEntry, lang: String, name: String, to dir: URL?) throws {
        let view = ZStack {
            NightBackground()
            NightWidgetView(entry: entry).padding(16)
        }
        .frame(width: 344, height: 162)
        .environment(\.locale, Locale(identifier: lang == "fr" ? "fr_FR" : "en_US"))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        guard let dir else { return }
        let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: dir.appendingPathComponent("task-8-preview-\(lang)-\(name).png"))
    }

    func testRenderParisPreviews() throws {
        let dir = ProcessInfo.processInfo.environment["LUNE_SNAPSHOT_DIR"].map(URL.init(fileURLWithPath:))
        for lang in ["fr", "en"] {
            for (m, d) in [(10, 26), (11, 10)] {
                try render(.sample(at: parisNoon(m, d)), lang: lang, name: String(format: "2026-%02d-%02d", m, d),
                           to: dir)
            }
        }
        // Edge layouts: no astronomical night (June), and two dark windows (synthetic).
        try render(.sample(at: parisNoon(6, 21)), lang: "fr", name: "2026-06-21", to: dir)
        var two = NightEntry.sample(at: parisNoon(11, 10))
        let night = try XCTUnwrap(two.report?.darkWindows.first)
        two.report?.darkWindows = [DateInterval(start: night.start, duration: 9000),
                                   DateInterval(start: night.end.addingTimeInterval(-9000), end: night.end)]
        try render(two, lang: "fr", name: "two-windows", to: dir)
    }
}
