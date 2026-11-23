import Foundation

/// Self-contained id of a searched place: `v1|lat|lon|timeZoneID|name` (name percent-encoded), so the
/// widget can restore everything from the id alone. Legacy ids are just "lat,lon".
enum PlaceID {
    typealias Parsed = (latitude: Double, longitude: Double, timeZoneID: String?, name: String)
    private static let posix = Locale(identifier: "en_US_POSIX")

    static func make(latitude: Double, longitude: Double, timeZoneID: String, name: String) -> String {
        let n = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return String(format: "v1|%.5f|%.5f|%@|%@", locale: posix, latitude, longitude, timeZoneID, n)
    }

    static func parse(_ id: String) -> Parsed? {
        if id.hasPrefix("v1|") {
            let f = id.split(separator: "|", maxSplits: 4, omittingEmptySubsequences: false)
            guard f.count == 5, let lat = Double(f[1]), let lon = Double(f[2]),
                  let name = String(f[4]).removingPercentEncoding else { return nil }
            return (lat, lon, f[3].isEmpty ? nil : String(f[3]), name)
        }
        let f = id.split(separator: ",", omittingEmptySubsequences: false)
        guard f.count == 2, let lat = Double(f[0]), let lon = Double(f[1]) else { return nil }
        return (lat, lon, nil, "")
    }

    /// "43.45° N, 5.56° E": shown for legacy ids that carry no name.
    static func coordinateLabel(latitude: Double, longitude: Double) -> String {
        String(format: "%.2f° %@, %.2f° %@", locale: posix, abs(latitude), latitude < 0 ? "S" : "N",
               abs(longitude), longitude < 0 ? "W" : "E")
    }
}
