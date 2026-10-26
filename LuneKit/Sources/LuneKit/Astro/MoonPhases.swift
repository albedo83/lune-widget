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

/// Principal lunar phases; target elongation = rawValue × 90°.
public enum PrincipalPhase: Int, Sendable {
    case new = 0, firstQuarter, full, lastQuarter

    public var targetElongation: Double { Double(rawValue) * 90 }
}

extension MoonPhases {
    /// Elongation shifted so the target maps to 180 and wraps far from it: a rising crossing of 180 is the phase.
    private static func shifted(_ phase: PrincipalPhase, _ date: Date) -> Double {
        AngleMath.normalize(elongation(at: date) - phase.targetElongation + 180)
    }

    private static func phaseCrossings(_ phase: PrincipalPhase, in interval: DateInterval, step: TimeInterval) -> [Date] {
        // The wrap (360 -> 0) shows up as a falling crossing; only rising ones are the phase.
        EventSearch.crossings(in: interval, threshold: 180, step: step) { shifted(phase, $0) }
            .filter(\.isRising).map(\.date)
    }

    /// Next instant strictly after `date` when the elongation reaches the phase's target.
    public static func next(_ phase: PrincipalPhase, after date: Date) -> Date {
        // Synodic month ≈ 29.53 d (elongation rate never below ~10°/day), so 31 d always contains one.
        let window = DateInterval(start: date, duration: 31 * 86400)
        return phaseCrossings(phase, in: window, step: 3600).first ?? date
    }

    /// The principal phase whose exact instant falls inside `interval`, if any.
    public static func principal(in interval: DateInterval) -> PrincipalPhase? {
        let hits = [PrincipalPhase.new, .firstQuarter, .full, .lastQuarter].compactMap { p in
            phaseCrossings(p, in: interval, step: 3600).first.map { (p, $0) }
        }
        return hits.min { $0.1 < $1.1 }?.0
    }
}
