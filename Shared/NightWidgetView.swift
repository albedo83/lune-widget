import LuneKit
import SwiftUI
import WidgetKit

struct NightEntry: TimelineEntry {
    let date: Date
    let placeName: String?
    /// `nil` when no location is known: the view asks the user to choose a city.
    var report: NightReport?
    let latitude: Double
    /// Time zone of the place; every time and date is shown in it.
    let timeZone: TimeZone
    /// Shows the location arrow next to the name, like Weather.
    var isCurrentLocation = false
}

extension NightEntry {
    /// Entry for a fixed place and date, used by previews, the placeholder and snapshot tests.
    static func sample(at date: Date, name: String = "Paris", latitude: Double = 48.8566, longitude: Double = 2.3522,
                       timeZone: TimeZone = TimeZone(identifier: "Europe/Paris")!) -> NightEntry {
        let report = NightCalculator.report(at: date, location: GeoLocation(latitude: latitude, longitude: longitude),
                                            timeZone: timeZone)
        return NightEntry(date: date, placeName: name, report: report, latitude: latitude, timeZone: timeZone,
                          isCurrentLocation: true)
    }
}

/// Dark "night sky" background for full-colour rendering.
struct NightBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.16), Color(red: 0.01, green: 0.02, blue: 0.06)],
                       startPoint: .top, endPoint: .bottom)
    }
}

struct NightWidgetView: View {
    let entry: NightEntry
    @Environment(\.locale) private var locale
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var fullColor: Bool { renderingMode == .fullColor }
    private var tz: TimeZone { entry.timeZone }

    var body: some View {
        Group {
            if let report = entry.report {
                content(report)
            } else {
                Text(Strings.localized(Strings.chooseCity, locale: locale))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(fullColor ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
    }

    private func content(_ r: NightReport) -> some View {
        HStack(alignment: .center, spacing: 12) {
            MoonView(illumination: r.illumination, isWaxing: r.isWaxing, latitude: entry.latitude, fullColor: fullColor)
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 3) {
                header(r)
                Text(Strings.phaseText(r.phaseName, locale: locale))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                eventsGrid(r)
                darkWindowChip(r)
                nextPhaseLine(r)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(_ r: NightReport) -> some View {
        HStack(spacing: 4) {
            Text(entry.placeName.flatMap { $0.isEmpty ? nil : $0 }
                 ?? Strings.localized(Strings.currentLocation, locale: locale))
                .font(.system(size: 13, weight: .semibold))
            if entry.isCurrentLocation {
                Image(systemName: "location.fill").font(.system(size: 9))
            }
            Spacer(minLength: 4)
            Text(Strings.percent(r.illumination, locale: locale))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
        }
    }

    private func eventsGrid(_ r: NightReport) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
            GridRow {
                Text(verbatim: "☾")
                Text("↑ " + Strings.time(r.moonrise, tz: tz))
                Text("↓ " + Strings.time(r.moonset, tz: tz))
            }
            GridRow {
                Text(verbatim: "✦")
                switch r.astroNight {
                case .none:
                    Text(Strings.localized(Strings.noAstroNight, locale: locale)).gridCellColumns(2)
                case .wholePeriod:
                    Text(Strings.localized(Strings.allNight, locale: locale)).gridCellColumns(2)
                case .interval(let i):
                    Text(Strings.localized(Strings.night, locale: locale) + " " + Strings.time(i.start, tz: tz))
                    Text("→ " + Strings.time(i.end, tz: tz))
                }
            }
            .foregroundStyle(astroStyle(r))
        }
        .font(.system(size: 12).monospacedDigit())
    }

    private func astroStyle(_ r: NightReport) -> AnyShapeStyle {
        if r.astroNight == .none { return AnyShapeStyle(.secondary) }
        return fullColor ? AnyShapeStyle(Color(red: 0.70, green: 0.82, blue: 1.0)) : AnyShapeStyle(.primary)
    }

    @ViewBuilder
    private func darkWindowChip(_ r: NightReport) -> some View {
        if r.astroNight != .none {
            let hasWindow = !r.darkWindows.isEmpty
            Text(Strings.darkWindow(r.darkWindows, tz: tz, locale: locale))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .lineLimit(r.darkWindows.count > 1 ? 2 : 1)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(chipForeground(hasWindow))
                .background(chipBackground(hasWindow), in: RoundedRectangle(cornerRadius: 5))
                .widgetAccentable()
        }
    }

    private func chipForeground(_ hasWindow: Bool) -> AnyShapeStyle {
        guard fullColor else { return AnyShapeStyle(hasWindow ? .primary : .secondary) }
        return AnyShapeStyle(hasWindow ? Color(red: 0.55, green: 0.95, blue: 0.60) : Color(white: 0.62))
    }

    private func chipBackground(_ hasWindow: Bool) -> AnyShapeStyle {
        guard fullColor else { return AnyShapeStyle(.primary.opacity(hasWindow ? 0.2 : 0.08)) }
        return AnyShapeStyle(hasWindow ? Color(red: 0.10, green: 0.45, blue: 0.20).opacity(0.45)
                                       : Color(white: 1).opacity(0.10))
    }

    private func nextPhaseLine(_ r: NightReport) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: r.nextPhase == .full ? "○" : "●")
            Text(Strings.nextPhase(r.nextPhase, date: r.nextPhaseDate, now: entry.date, tz: tz, locale: locale))
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}
