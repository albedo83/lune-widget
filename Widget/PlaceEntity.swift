import AppIntents
import CoreLocation
import Foundation
import MapKit

/// The widget's "Place" parameter: the Mac's current location or a city found by name.
struct PlaceEntity: AppEntity, Hashable {
    static let currentID = "current"

    /// "current", or "lat,lon" with 5 decimals (~1 m).
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let timeZoneID: String?
    /// Region and country shown under the name in the search results.
    var subtitle: String?

    static let current = PlaceEntity(id: currentID, name: "", latitude: nil, longitude: nil, timeZoneID: nil)

    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Place") }
    static var defaultQuery: PlaceQuery { PlaceQuery() }

    var isCurrent: Bool { id == Self.currentID }

    var displayRepresentation: DisplayRepresentation {
        if isCurrent { return DisplayRepresentation(title: "Current Location") }
        if let subtitle { return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)") }
        return DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String, latitude: Double?, longitude: Double?, timeZoneID: String?, subtitle: String? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneID = timeZoneID
        self.subtitle = subtitle
    }

    init(name: String, latitude: Double, longitude: Double, timeZoneID: String, subtitle: String?) {
        self.init(id: String(format: "%.5f,%.5f", locale: Locale(identifier: "en_US_POSIX"), latitude, longitude),
                  name: name, latitude: latitude, longitude: longitude, timeZoneID: timeZoneID, subtitle: subtitle)
    }
}

/// Searched places keyed by id, so `entities(for:)` can restore name and time zone from an id alone.
enum PlaceCache {
    private static let key = "placeCache"
    private static let limit = 50
    private struct Item: Codable { var name: String; var timeZoneID: String; var subtitle: String?; var savedAt: Date }

    private static var defaults: UserDefaults { UserDefaults(suiteName: LocationStore.appGroupID) ?? .standard }

    static func save(_ places: [PlaceEntity]) {
        var all = load()
        for p in places where !p.isCurrent {
            all[p.id] = Item(name: p.name, timeZoneID: p.timeZoneID ?? TimeZone.current.identifier,
                             subtitle: p.subtitle, savedAt: Date())
        }
        // Keep only the most recent entries.
        if all.count > limit {
            all = Dictionary(uniqueKeysWithValues: all.sorted { $0.value.savedAt > $1.value.savedAt }.prefix(limit)
                .map { ($0.key, $0.value) })
        }
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: key) }
    }

    static func entity(for id: String) -> PlaceEntity? {
        if id == PlaceEntity.currentID { return .current }
        let parts = id.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        let item = load()[id]
        return PlaceEntity(id: id, name: item?.name ?? id, latitude: parts[0], longitude: parts[1],
                           timeZoneID: item?.timeZoneID, subtitle: item?.subtitle)
    }

    private static func load() -> [String: Item] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: Item].self, from: data)) ?? [:]
    }
}

struct PlaceQuery: EntityStringQuery {
    func entities(for identifiers: [PlaceEntity.ID]) async throws -> [PlaceEntity] {
        identifiers.compactMap(PlaceCache.entity(for:))
    }

    func entities(matching string: String) async throws -> [PlaceEntity] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = string
        request.resultTypes = .address
        let response = try await MKLocalSearch(request: request).start()
        let places = response.mapItems.prefix(10).map { item -> PlaceEntity in
            let placemark = item.placemark
            let tz = item.timeZone ?? placemark.timeZone ?? .current
            let name = placemark.locality ?? item.name ?? string
            let subtitle = [placemark.administrativeArea, placemark.country].compactMap { $0 }.joined(separator: ", ")
            return PlaceEntity(name: name, latitude: placemark.coordinate.latitude,
                               longitude: placemark.coordinate.longitude, timeZoneID: tz.identifier,
                               subtitle: subtitle.isEmpty ? nil : subtitle)
        }
        PlaceCache.save(places)
        return places
    }

    func suggestedEntities() async throws -> [PlaceEntity] { [.current] }

    func defaultResult() async -> PlaceEntity? { .current }
}
