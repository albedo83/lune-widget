import CoreLocation
import Foundation
import LuneKit
import WidgetKit

/// A resolved place: where to compute and how to label it.
struct ResolvedPlace: Sendable {
    var location: GeoLocation
    var timeZone: TimeZone
    var name: String?
    var isCurrentLocation: Bool
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NightEntry {
        NightEntry.sample(at: .now)
    }

    func snapshot(for configuration: LuneConfigurationIntent, in context: Context) async -> NightEntry {
        if context.isPreview { return NightEntry.sample(at: .now) }
        let now = Date()
        return entry(at: now, now: now, place: await resolve(configuration.place ?? .current))
    }

    func timeline(for configuration: LuneConfigurationIntent, in context: Context) async -> Timeline<NightEntry> {
        let now = Date()
        guard let place = await resolve(configuration.place ?? .current) else {
            // No location yet: retry later in case the permission or a stored place appears.
            return Timeline(entries: [entry(at: now, now: now, place: nil)], policy: .after(now.addingTimeInterval(3600)))
        }
        let dates = TimelinePlanner.refreshDates(after: now, location: place.location, timeZone: place.timeZone)
        let entries = ([now] + dates).map { entry(at: $0, now: $0, place: place) }
        return Timeline(entries: entries, policy: .after(dates.last ?? now.addingTimeInterval(3600)))
    }

    private func entry(at date: Date, now: Date, place: ResolvedPlace?) -> NightEntry {
        guard let place else {
            return NightEntry(date: date, placeName: nil, report: nil, latitude: 0, timeZone: .current)
        }
        return NightEntry(date: date, placeName: place.name,
                          report: NightCalculator.report(at: now, location: place.location, timeZone: place.timeZone),
                          latitude: place.location.latitude, timeZone: place.timeZone,
                          isCurrentLocation: place.isCurrentLocation)
    }

    private func resolve(_ place: PlaceEntity) async -> ResolvedPlace? {
        if !place.isCurrent, let lat = place.latitude, let lon = place.longitude {
            let tz = place.timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
            return ResolvedPlace(location: GeoLocation(latitude: lat, longitude: lon), timeZone: tz,
                                 name: place.name, isCurrentLocation: false)
        }
        let store = LocationStore()
        if let fresh = await CurrentPlaceLocator.fetch() { store.current = fresh }
        guard let stored = store.current else { return nil }
        return ResolvedPlace(location: stored.location,
                             timeZone: TimeZone(identifier: stored.timeZoneID) ?? .current,
                             name: stored.name.isEmpty ? nil : stored.name, isCurrentLocation: true)
    }
}
