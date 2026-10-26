import Foundation

public enum JulianDay {
    /// Constant ΔT (TT - UT) in seconds.
    static let deltaT = 69.0
    private static let unixEpochJD = 2440587.5

    /// Julian day (UT) of a date.
    public static func jd(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86400 + unixEpochJD
    }

    /// Date for a Julian day (UT).
    public static func date(jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - unixEpochJD) * 86400)
    }

    /// Julian ephemeris day (dynamical time): JD plus ΔT.
    public static func jde(_ date: Date) -> Double {
        jd(date) + deltaT / 86400
    }
}
