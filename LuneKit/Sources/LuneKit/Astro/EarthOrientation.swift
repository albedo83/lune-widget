import Foundation

/// Shared time and Earth-orientation quantities (Meeus ch. 22).
enum EarthOrientation {
    /// Julian centuries of dynamical time since J2000.0.
    static func centuries(_ date: Date) -> Double {
        (JulianDay.jde(date) - 2451545.0) / 36525
    }

    /// Mean obliquity of the ecliptic in degrees (Meeus 22.2).
    static func meanObliquity(_ t: Double) -> Double {
        23.0 + 26.0 / 60 + 21.448 / 3600
            - (46.8150 * t + 0.00059 * t * t - 0.001813 * t * t * t) / 3600
    }

    /// Nutation in longitude and obliquity, degrees (Meeus ch. 22 abridged: 0.5″ / 0.1″).
    static func nutation(_ t: Double) -> (longitude: Double, obliquity: Double) {
        let omega = AngleMath.rad(125.04452 - 1934.136261 * t)
        let sunL = AngleMath.rad(280.4665 + 36000.7698 * t)
        let moonL = AngleMath.rad(218.3165 + 481267.8813 * t)
        let dPsi = -17.20 * sin(omega) - 1.32 * sin(2 * sunL) - 0.23 * sin(2 * moonL) + 0.21 * sin(2 * omega)
        let dEps = 9.20 * cos(omega) + 0.57 * cos(2 * sunL) + 0.10 * cos(2 * moonL) - 0.09 * cos(2 * omega)
        return (dPsi / 3600, dEps / 3600)
    }

    /// True obliquity (mean + nutation), degrees.
    static func trueObliquity(_ t: Double) -> Double {
        meanObliquity(t) + nutation(t).obliquity
    }
}
