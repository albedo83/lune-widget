import Foundation

/// Low-accuracy solar position, Meeus ch. 25 (with nutation and aberration correction).
public enum SunEphemeris {
    private static let kmPerAU = 149_597_870.7

    /// Apparent geometric longitude in degrees, 0..<360.
    public static func apparentLongitude(at date: Date) -> Double {
        let t = centuries(date)
        let trueLongitude = geometricLongitude(t) + equationOfCenter(t)
        return AngleMath.normalize(trueLongitude - 0.00569 - 0.00478 * sin(AngleMath.rad(omega(t))))
    }

    /// Apparent equatorial coordinates (degrees) and distance.
    public static func apparent(at date: Date) -> Equatorial {
        let t = centuries(date)
        let lambda = AngleMath.rad(apparentLongitude(at: date))
        let eps0 = 23.0 + 26.0 / 60 + 21.448 / 3600
            - (46.8150 * t + 0.00059 * t * t - 0.001813 * t * t * t) / 3600
        let eps = AngleMath.rad(eps0 + 0.00256 * cos(AngleMath.rad(omega(t))))
        let ra = AngleMath.deg(atan2(cos(eps) * sin(lambda), cos(lambda)))
        let dec = AngleMath.deg(asin(sin(eps) * sin(lambda)))

        let m = meanAnomaly(t)
        let e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t
        let v = AngleMath.rad(m + equationOfCenter(t))
        let r = 1.000001018 * (1 - e * e) / (1 + e * cos(v))
        return Equatorial(rightAscension: AngleMath.normalize(ra), declination: dec, distanceKm: r * kmPerAU)
    }

    // MARK: - Private

    private static func centuries(_ date: Date) -> Double {
        (JulianDay.jde(date) - 2451545.0) / 36525
    }

    private static func geometricLongitude(_ t: Double) -> Double {
        AngleMath.normalize(280.46646 + 36000.76983 * t + 0.0003032 * t * t)
    }

    private static func meanAnomaly(_ t: Double) -> Double {
        AngleMath.normalize(357.52911 + 35999.05029 * t - 0.0001537 * t * t)
    }

    private static func omega(_ t: Double) -> Double {
        125.04 - 1934.136 * t
    }

    private static func equationOfCenter(_ t: Double) -> Double {
        let m = AngleMath.rad(meanAnomaly(t))
        return (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(m)
            + (0.019993 - 0.000101 * t) * sin(2 * m)
            + 0.000289 * sin(3 * m)
    }
}
