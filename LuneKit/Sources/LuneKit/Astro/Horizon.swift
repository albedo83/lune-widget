import Foundation

/// Altitudes above the horizon for an observer at sea level.
public enum Horizon {
    private static let earthRadiusKm = 6378.14
    private static let earthAxisRatio = 0.99664719  // b/a, Meeus ch. 11

    /// Geocentric altitude of the Sun, degrees (solar parallax, 8.8″, is neglected).
    public static func sunAltitude(at date: Date, from location: GeoLocation) -> Double {
        geocentricAltitude(of: SunEphemeris.apparent(at: date), at: date, from: location)
    }

    /// Topocentric altitude of the Moon's centre, degrees: parallax from the actual distance (Meeus ch. 40),
    /// no refraction.
    public static func moonAltitude(at date: Date, from location: GeoLocation) -> Double {
        let moon = MoonEphemeris.apparent(at: date)
        let phi = AngleMath.rad(location.latitude)
        let u = atan(earthAxisRatio * tan(phi))
        let rhoSinPhi = earthAxisRatio * sin(u)
        let rhoCosPhi = cos(u)
        let sinPi = earthRadiusKm / moon.distanceKm

        let h = AngleMath.rad(hourAngle(of: moon, at: date, from: location))
        let dec = AngleMath.rad(moon.declination)
        let denom = cos(dec) - rhoCosPhi * sinPi * cos(h)
        let dAlpha = atan2(-rhoCosPhi * sinPi * sin(h), denom)
        let topoDec = atan2((sin(dec) - rhoSinPhi * sinPi) * cos(dAlpha), denom)
        return altitude(hourAngle: h - dAlpha, declination: topoDec, latitude: phi)
    }

    /// Apparent Greenwich sidereal time, degrees 0..<360 (Meeus 12.4 plus the equation of the equinoxes).
    static func apparentSiderealTime(at date: Date) -> Double {
        let jd = JulianDay.jd(date)
        let tu = (jd - 2451545.0) / 36525
        let mean = 280.46061837 + 360.98564736629 * (jd - 2451545.0)
            + 0.000387933 * tu * tu - tu * tu * tu / 38710000
        let t = EarthOrientation.centuries(date)
        let nutation = EarthOrientation.nutation(t).longitude * cos(AngleMath.rad(EarthOrientation.trueObliquity(t)))
        return AngleMath.normalize(mean + nutation)
    }

    /// Geocentric altitude of a body, degrees.
    static func geocentricAltitude(of body: Equatorial, at date: Date, from location: GeoLocation) -> Double {
        altitude(
            hourAngle: AngleMath.rad(hourAngle(of: body, at: date, from: location)),
            declination: AngleMath.rad(body.declination),
            latitude: AngleMath.rad(location.latitude)
        )
    }

    /// Local hour angle in degrees (east longitude positive).
    private static func hourAngle(of body: Equatorial, at date: Date, from location: GeoLocation) -> Double {
        apparentSiderealTime(at: date) + location.longitude - body.rightAscension
    }

    /// Altitude in degrees from radians inputs (Meeus 13.6).
    private static func altitude(hourAngle h: Double, declination dec: Double, latitude phi: Double) -> Double {
        AngleMath.deg(asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(h)))
    }
}
