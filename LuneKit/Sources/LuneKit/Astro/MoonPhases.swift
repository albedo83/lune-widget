import Foundation

/// Lunar phase quantities (Meeus ch. 48).
public enum MoonPhases {
    /// Elongation in apparent ecliptic longitude, (λmoon − λsun) mod 360, degrees.
    /// 0 = new moon, 90 = first quarter, 180 = full moon, 270 = last quarter.
    public static func elongation(at date: Date) -> Double {
        AngleMath.normalize(MoonEphemeris.apparentLongitude(at: date) - SunEphemeris.apparentLongitude(at: date))
    }

    /// Illuminated fraction of the disk, 0…1 (Meeus 48.2–48.3, k = (1 + cos i) / 2).
    public static func illumination(at date: Date) -> Double {
        let moon = MoonEphemeris.apparent(at: date)
        let sun = SunEphemeris.apparent(at: date)
        let d0 = AngleMath.rad(sun.declination), d = AngleMath.rad(moon.declination)
        let cosPsi = sin(d0) * sin(d) + cos(d0) * cos(d) * cos(AngleMath.rad(sun.rightAscension - moon.rightAscension))
        let psi = acos(max(-1, min(1, cosPsi)))
        let phaseAngle = atan2(sun.distanceKm * sin(psi), moon.distanceKm - sun.distanceKm * cos(psi))
        return (1 + cos(phaseAngle)) / 2
    }
}
