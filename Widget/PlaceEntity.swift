import AppIntents
import CoreLocation
import Foundation
import MapKit

/// The widget's "Place" parameter: the Mac's current location or a city found by name.
struct PlaceEntity: AppEntity, Hashable {
    static let currentID = "current"

    /// "current", or a self-contained `PlaceID` (coordinates, time zone and name), or a legacy "lat,lon".
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

    /// Restores a place from its id alone: no cache involved. Legacy "lat,lon" ids have no name or time zone,
    /// so they are labelled with readable coordinates instead of the raw id.
    static func decode(id: String) -> PlaceEntity? {
        if id == currentID { return .current }
        guard let p = PlaceID.parse(id) else { return nil }
        let name = p.name.isEmpty ? PlaceID.coordinateLabel(latitude: p.latitude, longitude: p.longitude) : p.name
        return PlaceEntity(id: id, name: name, latitude: p.latitude, longitude: p.longitude, timeZoneID: p.timeZoneID)
    }

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
        self.init(id: PlaceID.make(latitude: latitude, longitude: longitude, timeZoneID: timeZoneID, name: name),
                  name: name, latitude: latitude, longitude: longitude, timeZoneID: timeZoneID, subtitle: subtitle)
    }
}

struct PlaceQuery: EntityStringQuery {
    func entities(for identifiers: [PlaceEntity.ID]) async throws -> [PlaceEntity] {
        identifiers.compactMap(PlaceEntity.decode(id:))
    }

    func entities(matching string: String) async throws -> [PlaceEntity] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = string
        request.resultTypes = .address
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.prefix(10).map { item -> PlaceEntity in
            let placemark = item.placemark
            let tz = item.timeZone ?? placemark.timeZone ?? .current
            let name = placemark.locality ?? item.name ?? string
            let subtitle = [placemark.administrativeArea, placemark.country].compactMap { $0 }.joined(separator: ", ")
            return PlaceEntity(name: name, latitude: placemark.coordinate.latitude,
                               longitude: placemark.coordinate.longitude, timeZoneID: tz.identifier,
                               subtitle: subtitle.isEmpty ? nil : subtitle)
        }
    }

    func suggestedEntities() async throws -> [PlaceEntity] { [.current] }

    func defaultResult() async -> PlaceEntity? { .current }
}
