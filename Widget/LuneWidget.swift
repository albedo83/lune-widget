import LuneKit
import SwiftUI
import WidgetKit

struct LuneWidget: Widget {
    static let kind = "LuneWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: LuneConfigurationIntent.self, provider: Provider()) { entry in
            NightWidgetView(entry: entry)
                .containerBackground(for: .widget) { NightBackground() }
        }
        .configurationDisplayName("Lune")
        .description("Moon phase, moonrise and moonset, and tonight's dark window.")
        .supportedFamilies([.systemMedium])
    }
}

private func parisPreviewDate(_ month: Int, _ day: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Paris")!
    return cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
}

#Preview("Paris", as: .systemMedium) {
    LuneWidget()
} timeline: {
    NightEntry.sample(at: parisPreviewDate(10, 26))
    NightEntry.sample(at: parisPreviewDate(11, 10))
}
