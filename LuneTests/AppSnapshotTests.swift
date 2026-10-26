import AppKit
import SwiftUI
import XCTest
import LuneKit
@testable import Lune

/// Renders the companion window for Paris; writes PNGs when `LUNE_SNAPSHOT_DIR` is set.
@MainActor
final class AppSnapshotTests: XCTestCase {
    private let paris = StoredPlace(location: GeoLocation(latitude: 48.8566, longitude: 2.3522),
                                    timeZoneID: "Europe/Paris", name: "Paris", savedAt: Date())

    private func render(place: StoredPlace?, lang: String, name: String) throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))!
        let store = LocationStore(defaults: UserDefaults(suiteName: "lune.test.\(UUID().uuidString)")!)
        let view = ContentView(store: store, place: place, now: now)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.locale, Locale(identifier: lang == "fr" ? "fr_FR" : "en_US"))
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        guard let dir = ProcessInfo.processInfo.environment["LUNE_SNAPSHOT_DIR"] else { return }
        let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)-\(lang).png"))
    }

    func testRenderCompanionWindow() throws {
        for lang in ["fr", "en"] { try render(place: paris, lang: lang, name: "task-9-app") }
        try render(place: nil, lang: "fr", name: "task-9-app-empty")
    }
}
