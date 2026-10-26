# Lune Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A medium macOS desktop widget showing moon phase, moonrise/moonset, astronomical night and the "dark window" for deep-sky photography, at the Mac's location or a chosen city, in 5 languages, ready for the Mac App Store.

**Architecture:** All astronomy lives in a pure Swift package `LuneKit` (no UI, no network), developed test-first with `swift test`. An XcodeGen-generated project holds a small companion app and a WidgetKit extension that both depend on `LuneKit` and share SwiftUI views, a String Catalog and an App Group store for the last known location.

**Tech Stack:** Swift 6, SwiftUI, WidgetKit, App Intents, CoreLocation, MapKit (city search), Swift Testing, XcodeGen, macOS 14+.

**Spec:** `docs/superpowers/specs/2026-10-26-lune-widget-design.md` (French). Read it before any task.

## Global Constraints

- Deployment target: macOS 14.0. Swift 6 language mode.
- No third-party dependencies. Algorithms from Meeus, *Astronomical Algorithms* 2nd ed.
- Team `8Y86E7HK7M`; bundle IDs `com.albedo83.lune` (app), `com.albedo83.lune.widget` (extension); App Group `group.com.albedo83.lune`.
- App Sandbox on for both targets; no analytics, no data collection.
- Languages: English (development language), French, German, Spanish, Italian. Every user-visible string goes through `Shared/Localizable.xcstrings`.
- Times: 24 h in the chosen place's time zone; dates and durations formatted with the user's locale.
- Accuracy: rise/set and twilight within ±2 min of USNO; principal phase instants within ±5 min.
- Sun rise/set and moon rise/set use altitude threshold −0.833° (moon: topocentric altitude of its centre). Astronomical night: sun altitude < −18°.
- "Night J" = period from local noon on day J to local noon on day J+1 (place's time zone).
- Display switches from night J−1 to night J at sunrise on day J (local noon if the sun does not rise that day).
- Phase / illumination / drawing are computed at the reference instant: midpoint of the astronomical night if it is an interval, otherwise midpoint of the period.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Time zone ≠ Mac time zone (city chosen on another continent): all times and the noon/sunrise switch must use the place's time zone — Task 5 test `reportUsesPlaceTimeZone`.
2. DST change night (Paris 2026-10-24→25, 25 h period): period bounds must stay local noon to local noon — Task 5 test `periodAcrossDSTIsLocalNoonToNoon`.
3. Southern hemisphere: drawing must flip the lit side — Task 8 test `litSideFlipsInSouthernHemisphere`.
4. Location permission denied / no stored location: the widget must show a "choose a city" message, never a blank or a crash — Task 7 test `resolveCurrentWithoutStoredLocationReturnsNil` and Task 8 view state.
5. Widget left for days: timeline must always contain the next display switch so yesterday's night is never shown after sunrise — Task 6 test `refreshDatesIncludeNextSwitch`.

---

### Task 1: LuneKit package, Julian day and Sun position

**Files:**
- Create: `LuneKit/Package.swift` (library `LuneKit`, test target `LuneKitTests`, `platforms: [.macOS(.v14)]`, swift-tools 6.0)
- Create: `LuneKit/Sources/LuneKit/Astro/JulianDay.swift`
- Create: `LuneKit/Sources/LuneKit/Astro/SunEphemeris.swift`
- Create: `LuneKit/Sources/LuneKit/Astro/Types.swift`
- Test: `LuneKit/Tests/LuneKitTests/SunTests.swift`

**Interfaces:**
- Produces:
  - `public struct GeoLocation: Sendable, Hashable, Codable { public var latitude: Double; public var longitude: Double }` (degrees, east positive)
  - `public struct Equatorial: Sendable { public var rightAscension: Double; public var declination: Double; public var distanceKm: Double }` (degrees)
  - `public enum JulianDay { static func jd(_ date: Date) -> Double; static func date(jd: Double) -> Date; static func jde(_ date: Date) -> Double }` (`jde` adds ΔT; use ΔT = 69 s constant)
  - `public enum SunEphemeris { static func apparentLongitude(at: Date) -> Double; static func apparent(at: Date) -> Equatorial }` (Meeus ch. 25, low accuracy, with nutation/aberration correction)

- [ ] **Step 1: Write failing tests** (Swift Testing)

```swift
@Test func julianDayOfJ2000() {
    let d = ISO8601DateFormatter().date(from: "2000-01-01T12:00:00Z")!
    #expect(abs(JulianDay.jd(d) - 2451545.0) < 1e-6)
}
@Test func sunMeeusExample25a() {   // 1992-10-13 0h TD
    let d = JulianDay.date(jd: 2448908.5 - 69.0/86400)
    let s = SunEphemeris.apparent(at: d)
    #expect(abs(s.rightAscension - 198.38083) < 0.01)
    #expect(abs(s.declination - (-7.78507)) < 0.01)
}
```

- [ ] **Step 2:** `cd LuneKit && swift test` → FAIL (symbols missing)
- [ ] **Step 3:** Implement the types above.
- [ ] **Step 4:** `swift test` → PASS
- [ ] **Step 5:** Commit `feat(LuneKit): julian day and sun position`

### Task 2: Moon position, illumination and altitude

**Files:**
- Create: `LuneKit/Sources/LuneKit/Astro/MoonEphemeris.swift`
- Create: `LuneKit/Sources/LuneKit/Astro/Horizon.swift`
- Test: `LuneKit/Tests/LuneKitTests/MoonTests.swift`

**Interfaces:**
- Consumes: Task 1 types.
- Produces:
  - `public enum MoonEphemeris { static func apparentLongitude(at: Date) -> Double; static func apparent(at: Date) -> Equatorial }` — Meeus ch. 47 with the **full** periodic-term tables 47.A and 47.B.
  - `public enum MoonPhases { static func elongation(at: Date) -> Double /* (λmoon − λsun) mod 360 */; static func illumination(at: Date) -> Double /* 0…1, Meeus ch. 48 */ }` (file `MoonPhases.swift`, created here, extended in Task 4)
  - `public enum Horizon { static func sunAltitude(at: Date, from: GeoLocation) -> Double; static func moonAltitude(at: Date, from: GeoLocation) -> Double /* topocentric, parallax from distance */ }` — sidereal time Meeus ch. 12, parallax ch. 40 (sea level).

- [ ] **Step 1: Write failing tests**

```swift
@Test func moonMeeusExample47a() {  // 1992-04-12 0h TD
    let d = JulianDay.date(jd: 2448724.5 - 69.0/86400)
    let m = MoonEphemeris.apparent(at: d)
    #expect(abs(m.rightAscension - 134.688470) < 0.005)
    #expect(abs(m.declination - 13.768368) < 0.005)
    #expect(abs(m.distanceKm - 368409.7) < 5)
}
@Test func illuminationMeeusExample48a() {
    let d = JulianDay.date(jd: 2448724.5 - 69.0/86400)
    #expect(abs(MoonPhases.illumination(at: d) - 0.6786) < 0.002)
}
@Test func sunNoonAltitudeParis() { // 2026-10-26 11:35 UTC = solar noon
    let paris = GeoLocation(latitude: 48.8566, longitude: 2.3522)
    let d = ISO8601DateFormatter().date(from: "2026-10-26T11:35:00Z")!
    #expect(abs(Horizon.sunAltitude(at: d, from: paris) - 28.7) < 0.3)
}
```

- [ ] **Step 2:** `swift test` → FAIL
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `swift test` → PASS
- [ ] **Step 5:** Commit `feat(LuneKit): moon position, illumination, altitudes`

### Task 3: Event search (rise, set, twilight)

**Files:**
- Create: `LuneKit/Sources/LuneKit/Astro/EventSearch.swift`
- Test: `LuneKit/Tests/LuneKitTests/RiseSetTests.swift`

**Interfaces:**
- Produces:
  - `public struct Crossing: Sendable, Equatable { public var date: Date; public var isRising: Bool }`
  - `public enum EventSearch { static func crossings(in interval: DateInterval, threshold: Double, step: TimeInterval = 600, _ f: (Date) -> Double) -> [Crossing] }` — sample every `step`, bisect each sign change down to 1 s; sorted by date. No assumption that events exist (polar cases).
  - `public enum Altitudes { static let riseSet = -0.833; static let astronomical = -18.0 }`

- [ ] **Step 1: Write failing tests** — USNO reference values, Paris (48.8566, 2.3522), tolerance 120 s. Helper `paris(_ "2026-10-26 17:21", tz: "Europe/Paris") -> Date`.

| day (search 00:00–24:00 local) | body | rising | expected local |
|---|---|---|---|
| 2026-10-26 | moon | true | 17:21 |
| 2026-10-26 | moon | false | 07:57 |
| 2026-10-27 | moon | false | 09:23 |
| 2026-11-10 | moon | false | 17:20 |
| 2026-11-11 | moon | true | 10:34 |
| 2026-10-26 | sun | true / false | 07:28 / 17:41 |
| 2026-06-21 | moon | true | 13:30 |

Plus `@Test func noAstronomicalNightParisJune21()`: sun crossings of −18° between 2026-06-21 12:00 and 06-22 12:00 Paris is empty.
Plus `@Test func astroDuskIsMinus18()`: first descending −18° crossing on 2026-10-26 evening has `Horizon.sunAltitude` within 0.01° of −18 and lies between 19:00 and 19:40 local.

- [ ] **Step 2:** `swift test` → FAIL
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `swift test` → PASS
- [ ] **Step 5:** Commit `feat(LuneKit): rise/set and twilight search`

### Task 4: Principal phases and phase names

**Files:**
- Modify: `LuneKit/Sources/LuneKit/Astro/MoonPhases.swift`
- Create: `LuneKit/Sources/LuneKit/Night/MoonPhaseName.swift`
- Test: `LuneKit/Tests/LuneKitTests/PhaseTests.swift`

**Interfaces:**
- Produces:
  - `public enum PrincipalPhase: Int, Sendable { case new = 0, firstQuarter, full, lastQuarter }` (target elongation = rawValue × 90°)
  - `MoonPhases.next(_ phase: PrincipalPhase, after: Date) -> Date` — root-find on elongation (unwrap around 0/360).
  - `MoonPhases.principal(in interval: DateInterval) -> PrincipalPhase?`
  - `public enum MoonPhaseName: String, CaseIterable, Sendable { case newMoon, waxingCrescent, firstQuarter, waxingGibbous, fullMoon, waningGibbous, lastQuarter, waningCrescent }`
  - `MoonPhaseName.init(principalInPeriod: PrincipalPhase?, elongationAtReference: Double)` — principal phase wins; otherwise elongation 0–90 waxingCrescent, 90–180 waxingGibbous, 180–270 waningGibbous, 270–360 waningCrescent.

- [ ] **Step 1: Write failing tests** — USNO phases (UTC), tolerance 300 s:
  - `next(.full, after: 2026-10-20)` → 2026-10-26 04:12Z
  - `next(.lastQuarter, after: 2026-10-27)` → 2026-11-01 20:28Z
  - `next(.new, after: 2026-10-27)` → 2026-11-09 07:02Z
  - `next(.firstQuarter, after: 2026-11-10)` → 2026-11-17 11:48Z
  - `next(.full, after: 2026-11-10)` → 2026-11-24 14:53Z
  - names: `(nil, 20)` → `.waxingCrescent`; `(nil, 200)` → `.waningGibbous`; `(.full, 178)` → `.fullMoon`; `(nil, 359.9)` → `.waningCrescent`
- [ ] **Step 2:** `swift test` → FAIL
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `swift test` → PASS
- [ ] **Step 5:** Commit `feat(LuneKit): principal phases and names`

### Task 5: Night report

**Files:**
- Create: `LuneKit/Sources/LuneKit/Night/NightReport.swift`
- Create: `LuneKit/Sources/LuneKit/Night/NightCalculator.swift`
- Test: `LuneKit/Tests/LuneKitTests/NightReportTests.swift`

**Interfaces:**
- Produces:
  - `public enum AstroNight: Sendable, Equatable { case none, wholePeriod, interval(DateInterval) }`
  - `public struct NightReport: Sendable, Equatable { period: DateInterval; moonrise: Date?; moonset: Date?; astroNight: AstroNight; darkWindows: [DateInterval]; referenceDate: Date; illumination: Double; isWaxing: Bool; phaseName: MoonPhaseName; nextPhase: PrincipalPhase /* .full or .new */; nextPhaseDate: Date }`
  - `public enum NightCalculator { static func displayedPeriod(at now: Date, location: GeoLocation, timeZone: TimeZone) -> DateInterval; static func report(at now: Date, location: GeoLocation, timeZone: TimeZone) -> NightReport }`

Rules (from spec, Global Constraints):
- `displayedPeriod`: let D = local calendar day of `now`; sunrise S = first rising −0.833° crossing in D's 00:00–12:00; if `now < S` (or no S and `now` before local noon) → night D−1, else night D.
- `astroNight`: sun < −18° crossings in period. No time below −18 → `.none`; whole period below → `.wholePeriod`; else `.interval(first descending … following ascending)`, clamped to period.
- `moonrise`/`moonset`: first moon crossing of each kind within period, else nil.
- `darkWindows`: sub-intervals of the astro night where moon altitude < −0.833° (0, 1 or 2), each ≥ 1 min.
- `nextPhase`: `.full` if `elongation(at: referenceDate) < 180` else `.new`; date = `next(_, after: period.end)`.

- [ ] **Step 1: Write failing tests** (Paris, `Europe/Paris`; times ±120 s)
  - `paris20261026`: `report(at: 2026-10-26 21:00)` → period 26 12:00–27 12:00; moonrise 26 17:21; moonset 27 09:23; astroNight `.interval` starting 19:00–19:40; `darkWindows` empty; phaseName `.waningGibbous`; illumination > 0.95; nextPhase `.new` on 2026-11-09 07:02Z ±300 s.
  - `paris20261110`: `report(at: 2026-11-10 20:00)` → moonset 10 17:20; moonrise 11 10:34; exactly one dark window equal to the astro night interval; phaseName `.waxingCrescent`; isWaxing; illumination < 0.08; nextPhase `.full` on 2026-11-24 14:53Z ±300 s.
  - `paris20260621`: astroNight `.none`, darkWindows empty, moonrise 21 13:30.
  - `northPoleWinter`: (89.0, 0.0), UTC, 2026-12-21 → `.wholePeriod`.
  - `switchesAtSunrise`: at 2026-10-27 07:00 Paris → period starts 26 12:00; at 07:45 → starts 27 12:00.
  - `periodAcrossDSTIsLocalNoonToNoon`: night 2026-10-24 → period is 24 12:00 CEST to 25 12:00 CET (duration 25 h).
  - `reportUsesPlaceTimeZone`: Sydney (−33.87, 151.21, `Australia/Sydney`), `now` = 2026-10-26T10:00Z → period start is local noon in Sydney.
- [ ] **Step 2:** `swift test` → FAIL
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `swift test` → PASS
- [ ] **Step 5:** Commit `feat(LuneKit): night report`

### Task 6: Timeline refresh dates

**Files:**
- Create: `LuneKit/Sources/LuneKit/Night/TimelinePlanner.swift`
- Test: `LuneKit/Tests/LuneKitTests/TimelinePlannerTests.swift`

**Interfaces:**
- Produces: `public enum TimelinePlanner { static func refreshDates(after now: Date, location: GeoLocation, timeZone: TimeZone) -> [Date] }` — sorted, unique, all `> now`, within 24 h: moonrise, moonset, astro-night bounds, dark-window bounds, next local midnight, and the **next display switch** (next sunrise, or next local noon if none). The widget builds one entry per date plus `now`, policy `.after(last date)`.

- [ ] **Step 1: Failing tests:** `refreshDatesIncludeNextSwitch` (Paris 2026-10-26 21:00 → contains 2026-10-27 sunrise ±120 s); `refreshDatesAreFutureSortedUnique`; `polarNoSunriseUsesNoon` (Tromsø 69.65, 18.96, `Europe/Oslo`, 2026-12-21 → contains local noon of 12-22).
- [ ] **Step 2:** FAIL → **Step 3:** implement → **Step 4:** PASS
- [ ] **Step 5:** Commit `feat(LuneKit): timeline refresh dates`

### Task 7: Xcode project, location, localization skeleton

**Files:**
- Create: `project.yml` (XcodeGen: targets `Lune` app and `LuneWidget` app-extension, local package `LuneKit`, team `8Y86E7HK7M`, deployment 14.0, `Shared/` sources in both targets, development language `en`, known regions en fr de es it)
- Create: `App/LuneApp.swift`, `App/Lune.entitlements`, `App/Info.plist` (`NSLocationUsageDescription`), `App/Assets.xcassets` (placeholder AppIcon)
- Create: `Widget/LuneWidgetBundle.swift`, `Widget/LuneWidget.entitlements`, `Widget/Info.plist` (`NSWidgetWantsLocation` = YES, `NSLocationUsageDescription`)
- Create: `Shared/LocationStore.swift`, `Shared/Localizable.xcstrings`, `Shared/PrivacyInfo.xcprivacy`
- Create: `LuneTests/LocationStoreTests.swift` (unit test target hosted by app)
- Modify: `.gitignore` (add `*.xcodeproj` — the project is generated)

Entitlements both targets: `com.apple.security.app-sandbox`, `com.apple.security.application-groups = [group.com.albedo83.lune]`, `com.apple.security.personal-information.location`, `com.apple.security.network.client` (city search / reverse geocoding).

**Interfaces:**
- Produces:
  - `struct StoredPlace: Codable, Equatable { var location: GeoLocation; var timeZoneID: String; var name: String; var savedAt: Date }`
  - `final class LocationStore { init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.albedo83.lune")!); var current: StoredPlace? { get set } }`
  - `func resolveCurrent(store: LocationStore) -> StoredPlace?`

- [ ] **Step 1: Failing tests** `roundTripsStoredPlace`, `resolveCurrentWithoutStoredLocationReturnsNil` (in-memory `UserDefaults(suiteName: UUID().uuidString)`).
- [ ] **Step 2:** `xcodegen && xcodebuild test -scheme Lune -destination 'platform=macOS'` → FAIL
- [ ] **Step 3:** Implement; app shows an empty window, widget bundle compiles with a placeholder widget.
- [ ] **Step 4:** same command → `** TEST SUCCEEDED **`
- [ ] **Step 5:** Commit `feat: Xcode project, entitlements, location store`

### Task 8: Widget configuration, views and provider

**Files:**
- Create: `Widget/PlaceEntity.swift`, `Widget/LuneConfigurationIntent.swift`, `Widget/Provider.swift`, `Widget/LuneWidget.swift`
- Create: `Shared/MoonView.swift`, `Shared/NightWidgetView.swift`, `Shared/Strings.swift`
- Modify: `Shared/Localizable.xcstrings`
- Test: `LuneTests/MoonGeometryTests.swift`, `LuneTests/StringsTests.swift`

**Interfaces:**
- Consumes: `NightCalculator.report`, `TimelinePlanner.refreshDates`, `LocationStore`, `StoredPlace`.
- Produces:
  - `struct PlaceEntity: AppEntity { id: String /* "current" or "lat,lon" */; name: String; latitude: Double?; longitude: Double?; timeZoneID: String? }` with `static let current` ("Current Location" localized). `EntityStringQuery`: `entities(matching:)` uses `MKLocalSearch` (address results, max 10) and fills `timeZoneID` from the placemark; `suggestedEntities()` → `[.current]`; default `.current`.
  - `struct LuneConfigurationIntent: WidgetConfigurationIntent { @Parameter(title: "Place") var place: PlaceEntity? }`
  - `struct NightEntry: TimelineEntry { date: Date; placeName: String?; report: NightReport?; latitude: Double }` — `report == nil` means no location: view shows "Choose a city: right-click › Edit Widget" (localized).
  - Provider: current location = `CLLocationManager` one-shot inside the extension (if authorized), saved to `LocationStore` with reverse-geocoded name and time zone; otherwise `LocationStore.current`; otherwise nil.
  - `struct MoonGeometry { static func terminatorScaleX(illumination: Double) -> Double /* 1 − 2k, in −1…1 */; static func litOnRight(isWaxing: Bool, latitude: Double) -> Bool }`
  - `MoonView(illumination: Double, isWaxing: Bool, latitude: Double)` — disk + terminator ellipse with `terminatorScaleX`, lit side from `litOnRight`.
  - `NightWidgetView(entry: NightEntry)` — layout of the approved mockup (spec "Maquette validée"); supports `widgetRenderingMode` `.accented` / `.vibrant` (no custom colours, use `.widgetAccentable()` on the moon and the dark-window chip).
  - `enum Strings { static func phase(_ n: MoonPhaseName) -> LocalizedStringResource; static func darkWindow(_ w: [DateInterval], tz: TimeZone, locale: Locale) -> String; static func nextPhase(_ p: PrincipalPhase, date: Date, now: Date, tz: TimeZone, locale: Locale) -> String }`
  - Widget kind `"LuneWidget"`, `.supportedFamilies([.systemMedium])`, `AppIntentConfiguration`.

Copy (English source; translations fr/de/es/it in the catalog): phase names; "Moonrise"/"Moonset" are icons only; "No dark window tonight"; "Dark window %@ → %@ (%@)"; "No astronomical night"; "All night"; "New moon in %lld d (%@)" / "Full moon in %lld d (%@)"; "Current Location"; "Choose a city: right-click › Edit Widget". French copy must match the spec exactly ("Pas de fenêtre noire ce soir", "Fenêtre noire 19:08 → 05:44 (10 h 36)", "Nouvelle lune dans 14 j (9 nov.)").

- [ ] **Step 1: Failing tests**
  - `terminatorAtFullIsMinusOne`, `terminatorAtNewIsOne`, `terminatorAtQuarterIsZero`
  - `litSideFlipsInSouthernHemisphere`: `litOnRight(true, 48)` true, `litOnRight(true, −33)` false
  - `frenchDarkWindow`: two dates 19:08 and 05:44 Paris, `fr_FR` → `"Fenêtre noire 19:08 → 05:44 (10 h 36)"`
  - `frenchNextPhase`: `.new`, 2026-11-09 08:02 Paris, now 2026-10-26 → `"Nouvelle lune dans 14 j (9 nov.)"`
  - `everyCatalogKeyHasFiveLanguages`: parse `Localizable.xcstrings`, each key has `en fr de es it` with state `translated`
- [ ] **Step 2:** `xcodebuild test …` → FAIL
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** `xcodebuild test …` → `** TEST SUCCEEDED **`
- [ ] **Step 5:** SwiftUI `#Preview(as: .systemMedium)` with Paris 2026-10-26 and 2026-11-10 entries; screenshot both previews in French and English and compare with the spec mockups.
- [ ] **Step 6:** Commit `feat: widget configuration, views, provider`

### Task 9: Companion app

**Files:**
- Modify: `App/LuneApp.swift`
- Create: `App/ContentView.swift`, `App/LocationAuthorizer.swift`

**Interfaces:**
- Consumes: `NightWidgetView`, `NightEntry`, `LocationStore`, `NightCalculator`.
- Produces: one window (≈ 480×420): title, one-paragraph explanation of the widget and how to add it ("Edit Widgets" on desktop), a "Use my location" button (requests `whenInUse`/`authorized` via `CLLocationManager`, then saves `StoredPlace` and calls `WidgetCenter.shared.reloadAllTimelines()`), and a live `NightWidgetView` preview for the stored place. All strings in the catalog.

- [ ] **Step 1:** Build and run the app; deny then grant location in System Settings; check the preview updates and `LocationStore.current` is filled (`defaults read group.com.albedo83.lune` inside the container).
- [ ] **Step 2:** Commit `feat: companion app`

### Task 10: Realistic moon (pre-rendered NASA phases)

User change request after Task 9: "une lune réaliste, pas un dessin". Spec section "Image de la lune" is binding.

**Files:**
- Create: `Tools/MoonRender/Package.swift` (executable `moonrender`, macOS 14, no dependencies; reads images with ImageIO/CoreGraphics)
- Create: `Tools/MoonRender/Sources/moonrender/main.swift`, `Tools/MoonRender/Sources/MoonRenderCore/Renderer.swift` (library target so it is testable)
- Create: `Tools/MoonRender/Tests/MoonRenderCoreTests/RendererTests.swift`
- Existing inputs (already downloaded, commit them): `Tools/MoonRender/nasa/lroc_color_2k.jpg` (2048×1024 sRGB, equirectangular, longitude −180…180 left→right, centre = lon 0), `Tools/MoonRender/nasa/ldem_4_uint.tif` (1440×720, uint16, half-metres relative to 1 727 400 m)
- Create: `Tools/MoonRender/README.md` (how to regenerate, NASA credit)
- Create (generated, committed): `Shared/Moon.xcassets/moon-000.imageset` … `moon-355.imageset` (72 frames, every 5° of elongation), `Shared/Moon.xcassets/Contents.json`
- Modify: `Shared/MoonView.swift` (replace the drawn shape with the frame image), `Shared/NightWidgetView.swift:60`, `LuneTests/MoonGeometryTests.swift` → `LuneTests/MoonFrameTests.swift`, `App/ContentView.swift` (credit line), `Shared/Localizable.xcstrings`, `README.md`, `project.yml` (asset catalog in both targets if not picked up automatically)

**Interfaces:**
- Consumes: `NightReport.illumination`, `NightReport.isWaxing`, `NightEntry.latitude`.
- Produces:
  - `MoonRenderCore.Renderer(colorMap: CGImage, heightMap: CGImage)` with `func render(elongation: Double, size: Int) -> CGImage` — transparent background, disk diameter = `size` minus a 2 px margin, viewer at sub-Earth point (lat 0, lon 0), north up, sun direction from `elongation` (0 = new, 90 = first quarter lit on the right, 180 = full).
  - `moonrender <out-dir> [--size 256] [--step 5]` writes `moon-EEE.png` + imageset `Contents.json` per frame.
  - `enum MoonFrame { static func elongation(illumination: Double, isWaxing: Bool) -> Double; static func name(illumination: Double, isWaxing: Bool, step: Int = 5) -> String /* "moon-090" */; static func rotation(latitude: Double) -> Angle /* 0° north, 180° south */ }` in `Shared/MoonView.swift`.
  - `MoonView(illumination: Double, isWaxing: Bool, latitude: Double, fullColor: Bool)` — same call signature as today, now `Image(MoonFrame.name(...)).resizable().rotationEffect(MoonFrame.rotation(...))`; in accented/vibrant modes use `.widgetAccentedRenderingMode(.desaturated)` on macOS 15+ (availability check), else the plain image.

Shading (decided): per pixel on the disk compute the sphere normal, its selenographic lat/lon, sample albedo (bilinear) from the colour map; perturb the normal with the height-map gradient (bump strength tuned so craters show relief near the terminator but the full moon stays flat-looking); reflectance = Lunar-Lambert blend `L·2μ0/(μ0+μ) + (1−L)·μ0` with L = 0.8; add faint earthshine on the night side proportional to (1 − illumination), max 3 % of full-moon brightness; antialias the limb (supersample 2×); sRGB output. Frames ≈ 256 px (shown at ~100 pt, @2x).

- [ ] **Step 1: Failing tests**
  - `RendererTests.fullMoonCentreIsBright`: render(180, 64) centre pixel luminance > 0.5, corner pixel alpha == 0.
  - `RendererTests.newMoonIsDark`: render(0, 64) mean luminance over the disk < 0.05.
  - `RendererTests.firstQuarterLitOnRight`: render(90, 64) mean luminance of right half > 5 × left half.
  - `RendererTests.lastQuarterLitOnLeft`: render(270, 64) left half > 5 × right half.
  - `MoonFrameTests`: `elongation(0, true)` = 0; `elongation(1, true)` = 180; `elongation(0.5, true)` = 90 ±0.01; `elongation(0.5, false)` = 270 ±0.01; `name(0.5, true)` = "moon-090"; `name(0.999, false)` = "moon-185" (elongation 182.6°, nearest 5° step); `name(0.0001, false)` = "moon-000" (358.9° wraps to 360 → 0); `rotation(48)` = 0°, `rotation(-33)` = 180°.
- [ ] **Step 2:** `cd Tools/MoonRender && swift test` and `scripts/test.sh` → FAIL
- [ ] **Step 3:** Implement renderer + CLI; run `swift run moonrender ../../Shared/Moon.xcassets`; implement `MoonFrame` and the new `MoonView`; add credit string "Moon imagery: NASA's Scientific Visualization Studio" (translated, 5 languages) under the preview in the app; README credit.
- [ ] **Step 4:** Both test commands → PASS (`** TEST SUCCEEDED **`, LuneKit 27/27, MoonRender tests pass). Check the asset catalog adds < 6 MB to the app.
- [ ] **Step 5:** Regenerate the widget preview PNGs (fr 2026-10-26, fr 2026-11-10, fr two-windows, en 2026-11-10) and a contact sheet of 8 frames (0, 45, 90, 135, 180, 225, 270, 315) into the task workspace for the user to look at.
- [ ] **Step 6:** Commit `feat: realistic NASA moon`.

### Task 11: On-desktop verification

- [ ] **Step 1:** Run the app once, add the widget to the desktop, check it against USNO for today at the current location (rise/set ±2 min).
- [ ] **Step 2:** Edit the widget → search "Sydney" → check times are in Sydney time; add a second widget with "Current Location", both coexist.
- [ ] **Step 3:** Switch the Mac language to English then German (`Lune` per-app language in System Settings) and check the strings.
- [ ] **Step 4:** Set desktop widgets to monochrome/tinted style and check legibility.
- [ ] **Step 5:** Archive (`xcodebuild archive`) and run `xcrun altool --validate-app` or Xcode Organizer "Validate" — expect no sandbox/entitlement errors. Do **not** upload.
- [ ] **Step 6:** Update `README.md` (what it does, how to build: `brew install xcodegen && xcodegen`), commit `docs: README`.
