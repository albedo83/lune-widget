import Foundation
import LuneKit

public struct StoredPlace: Codable, Equatable, Sendable {
    public var location: GeoLocation
    public var timeZoneID: String
    public var name: String
    public var savedAt: Date

    public init(location: GeoLocation, timeZoneID: String, name: String, savedAt: Date) {
        self.location = location
        self.timeZoneID = timeZoneID
        self.name = name
        self.savedAt = savedAt
    }
}

/// Persists the chosen place in the shared App Group so the app and the widget agree.
public final class LocationStore: @unchecked Sendable {
    public static let appGroupID = "group.com.albedo83.lune"
    private static let key = "storedPlace"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = UserDefaults(suiteName: LocationStore.appGroupID)!) {
        self.defaults = defaults
    }

    public var current: StoredPlace? {
        get {
            guard let data = defaults.data(forKey: Self.key) else { return nil }
            return try? JSONDecoder().decode(StoredPlace.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}

public func resolveCurrent(store: LocationStore) -> StoredPlace? {
    store.current
}
