import CoreLocation
import Foundation
import LuneKit

/// The parts of a `CLPlacemark` we use (lets the fallbacks be tested without CoreLocation objects).
struct PlacemarkInfo: Sendable {
    var locality: String?
    var name: String?
    var timeZone: TimeZone?
}

/// One-shot location fix + reverse geocode, shared by the widget extension and the app. Bounded by a short
/// timeout so a timeline or the UI is never blocked.
enum CurrentPlaceLocator {
    static let timeout: Duration = .seconds(4)

    static func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedAlways || status == .authorized
    }

    /// Pure: name falls back locality → placemark name → "", time zone falls back to the current one.
    static func makePlace(latitude: Double, longitude: Double, placemark: PlacemarkInfo?, savedAt: Date) -> StoredPlace {
        let name = [placemark?.locality, placemark?.name].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        let tz = placemark?.timeZone ?? .current
        return StoredPlace(location: GeoLocation(latitude: latitude, longitude: longitude),
                           timeZoneID: tz.identifier, name: name, savedAt: savedAt)
    }

    /// Current place, or nil when not authorized or no fix arrives in time (the extension may rely on
    /// `isAuthorizedForWidgetUpdates`).
    static func fetch() async -> StoredPlace? {
        let manager = CLLocationManager()
        guard manager.isAuthorizedForWidgetUpdates || isAuthorized(manager.authorizationStatus) else { return nil }
        guard let location = await withTimeout(timeout, operation: { await firstLocation() }) else { return nil }
        // CLGeocoder ignores task cancellation: cancel the request itself when the deadline passes.
        let geocoder = GeocoderBox()
        let placemark = await withTimeout(timeout, operation: {
            try? await geocoder.value.reverseGeocodeLocation(location).first
        }, onTimeout: { geocoder.value.cancelGeocode() })
        let info = placemark.map { PlacemarkInfo(locality: $0.locality, name: $0.name, timeZone: $0.timeZone) }
        return makePlace(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                         placemark: info, savedAt: Date())
    }

    private static func firstLocation() async -> CLLocation? {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location { return location }
            }
        } catch {}
        return nil
    }
}

/// CLGeocoder is thread-safe for start/cancel but not marked Sendable.
private final class GeocoderBox: @unchecked Sendable {
    let value = CLGeocoder()
}
