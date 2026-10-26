import Foundation

/// Geographic position in degrees, east longitude positive.
public struct GeoLocation: Sendable, Hashable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Equatorial coordinates in degrees, with distance in kilometres.
public struct Equatorial: Sendable {
    public var rightAscension: Double
    public var declination: Double
    public var distanceKm: Double

    public init(rightAscension: Double, declination: Double, distanceKm: Double) {
        self.rightAscension = rightAscension
        self.declination = declination
        self.distanceKm = distanceKm
    }
}

enum AngleMath {
    static func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }
    static func deg(_ radians: Double) -> Double { radians * 180 / .pi }

    /// Normalises an angle in degrees to 0..<360.
    static func normalize(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }
}
