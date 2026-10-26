import Foundation

/// Lunar position, Meeus ch. 47 (full periodic terms of tables 47.A and 47.B).
public enum MoonEphemeris {
    /// Geocentric ecliptic position referred to the mean equinox of date (no nutation).
    struct Ecliptic {
        var longitude: Double
        var latitude: Double
        var distanceKm: Double
    }

    /// Apparent ecliptic longitude in degrees (nutation included), 0..<360.
    public static func apparentLongitude(at date: Date) -> Double {
        let t = EarthOrientation.centuries(date)
        return AngleMath.normalize(geometric(at: date).longitude + EarthOrientation.nutation(t).longitude)
    }

    /// Apparent geocentric equatorial coordinates (degrees) and distance.
    public static func apparent(at date: Date) -> Equatorial {
        let t = EarthOrientation.centuries(date)
        let g = geometric(at: date)
        let lambda = AngleMath.rad(g.longitude + EarthOrientation.nutation(t).longitude)
        let beta = AngleMath.rad(g.latitude)
        let eps = AngleMath.rad(EarthOrientation.trueObliquity(t))
        let ra = atan2(sin(lambda) * cos(eps) - tan(beta) * sin(eps), cos(lambda))
        let dec = asin(sin(beta) * cos(eps) + cos(beta) * sin(eps) * sin(lambda))
        return Equatorial(
            rightAscension: AngleMath.normalize(AngleMath.deg(ra)),
            declination: AngleMath.deg(dec),
            distanceKm: g.distanceKm
        )
    }

    static func geometric(at date: Date) -> Ecliptic {
        let t = EarthOrientation.centuries(date)
        let t2 = t * t, t3 = t2 * t, t4 = t3 * t

        let lp = AngleMath.normalize(218.3164477 + 481267.88123421 * t - 0.0015786 * t2 + t3 / 538841 - t4 / 65194000)
        let d = AngleMath.normalize(297.8501921 + 445267.1114034 * t - 0.0018819 * t2 + t3 / 545868 - t4 / 113065000)
        let m = AngleMath.normalize(357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000)
        let mp = AngleMath.normalize(134.9633964 + 477198.8675055 * t + 0.0087414 * t2 + t3 / 69699 - t4 / 14712000)
        let f = AngleMath.normalize(93.2720950 + 483202.0175233 * t - 0.0036539 * t2 - t3 / 3526000 + t4 / 863310000)
        let a1 = AngleMath.rad(119.75 + 131.849 * t)
        let a2 = AngleMath.rad(53.09 + 479264.290 * t)
        let a3 = AngleMath.rad(313.45 + 481266.484 * t)
        let e = 1 - 0.002516 * t - 0.0000074 * t2

        func eccentricity(_ mCoef: Double) -> Double {
            switch abs(mCoef) {
            case 1: e
            case 2: e * e
            default: 1
            }
        }

        var sumL = 0.0, sumR = 0.0, sumB = 0.0
        for row in lrTerms {
            let arg = AngleMath.rad(row.d * d + row.m * m + row.mp * mp + row.f * f)
            let k = eccentricity(row.m)
            sumL += row.l * k * sin(arg)
            sumR += row.r * k * cos(arg)
        }
        for row in bTerms {
            let arg = AngleMath.rad(row.d * d + row.m * m + row.mp * mp + row.f * f)
            sumB += row.b * eccentricity(row.m) * sin(arg)
        }

        let lpr = AngleMath.rad(lp), mpr = AngleMath.rad(mp), fr = AngleMath.rad(f)
        sumL += 3958 * sin(a1) + 1962 * sin(lpr - fr) + 318 * sin(a2)
        sumB += -2235 * sin(lpr) + 382 * sin(a3) + 175 * sin(a1 - fr) + 175 * sin(a1 + fr)
            + 127 * sin(lpr - mpr) - 115 * sin(lpr + mpr)

        return Ecliptic(
            longitude: AngleMath.normalize(lp + sumL / 1_000_000),
            latitude: sumB / 1_000_000,
            distanceKm: 385000.56 + sumR / 1000
        )
    }

    // MARK: - Periodic terms

    private struct LRTerm { let d, m, mp, f, l, r: Double }
    private struct BTerm { let d, m, mp, f, b: Double }

    private static func lr(_ d: Double, _ m: Double, _ mp: Double, _ f: Double, _ l: Double, _ r: Double) -> LRTerm {
        LRTerm(d: d, m: m, mp: mp, f: f, l: l, r: r)
    }

    private static func b(_ d: Double, _ m: Double, _ mp: Double, _ f: Double, _ b: Double) -> BTerm {
        BTerm(d: d, m: m, mp: mp, f: f, b: b)
    }

    /// Table 47.A: arguments D, M, M′, F; coefficients of Σl (sine, 1e-6°) and Σr (cosine, 1e-3 km).
    private static let lrTerms: [LRTerm] = [
        lr(0, 0, 1, 0, 6288774, -20905355),
        lr(2, 0, -1, 0, 1274027, -3699111),
        lr(2, 0, 0, 0, 658314, -2955968),
        lr(0, 0, 2, 0, 213618, -569925),
        lr(0, 1, 0, 0, -185116, 48888),
        lr(0, 0, 0, 2, -114332, -3149),
        lr(2, 0, -2, 0, 58793, 246158),
        lr(2, -1, -1, 0, 57066, -152138),
        lr(2, 0, 1, 0, 53322, -170733),
        lr(2, -1, 0, 0, 45758, -204586),
        lr(0, 1, -1, 0, -40923, -129620),
        lr(1, 0, 0, 0, -34720, 108743),
        lr(0, 1, 1, 0, -30383, 104755),
        lr(2, 0, 0, -2, 15327, 10321),
        lr(0, 0, 1, 2, -12528, 0),
        lr(0, 0, 1, -2, 10980, 79661),
        lr(4, 0, -1, 0, 10675, -34782),
        lr(0, 0, 3, 0, 10034, -23210),
        lr(4, 0, -2, 0, 8548, -21636),
        lr(2, 1, -1, 0, -7888, 24208),
        lr(2, 1, 0, 0, -6766, 30824),
        lr(1, 0, -1, 0, -5163, -8379),
        lr(1, 1, 0, 0, 4987, -16675),
        lr(2, -1, 1, 0, 4036, -12831),
        lr(2, 0, 2, 0, 3994, -10445),
        lr(4, 0, 0, 0, 3861, -11650),
        lr(2, 0, -3, 0, 3665, 14403),
        lr(0, 1, -2, 0, -2689, -7003),
        lr(2, 0, -1, 2, -2602, 0),
        lr(2, -1, -2, 0, 2390, 10056),
        lr(1, 0, 1, 0, -2348, 6322),
        lr(2, -2, 0, 0, 2236, -9884),
        lr(0, 1, 2, 0, -2120, 5751),
        lr(0, 2, 0, 0, -2069, 0),
        lr(2, -2, -1, 0, 2048, -4950),
        lr(2, 0, 1, -2, -1773, 4130),
        lr(2, 0, 0, 2, -1595, 0),
        lr(4, -1, -1, 0, 1215, -3958),
        lr(0, 0, 2, 2, -1110, 0),
        lr(3, 0, -1, 0, -892, 3258),
        lr(2, 1, 1, 0, -810, 2616),
        lr(4, -1, -2, 0, 759, -1897),
        lr(0, 2, -1, 0, -713, -2117),
        lr(2, 2, -1, 0, -700, 2354),
        lr(2, 1, -2, 0, 691, 0),
        lr(2, -1, 0, -2, 596, 0),
        lr(4, 0, 1, 0, 549, -1423),
        lr(0, 0, 4, 0, 537, -1117),
        lr(4, -1, 0, 0, 520, -1571),
        lr(1, 0, -2, 0, -487, -1739),
        lr(2, 1, 0, -2, -399, 0),
        lr(0, 0, 2, -2, -381, -4421),
        lr(1, 1, 1, 0, 351, 0),
        lr(3, 0, -2, 0, -340, 0),
        lr(4, 0, -3, 0, 330, 0),
        lr(2, -1, 2, 0, 327, 0),
        lr(0, 2, 1, 0, -323, 1165),
        lr(1, 1, -1, 0, 299, 0),
        lr(2, 0, 3, 0, 294, 0),
        lr(2, 0, -1, -2, 0, 8752),
    ]

    /// Table 47.B: arguments D, M, M′, F; coefficient of Σb (sine, 1e-6°).
    private static let bTerms: [BTerm] = [
        b(0, 0, 0, 1, 5128122),
        b(0, 0, 1, 1, 280602),
        b(0, 0, 1, -1, 277693),
        b(2, 0, 0, -1, 173237),
        b(2, 0, -1, 1, 55413),
        b(2, 0, -1, -1, 46271),
        b(2, 0, 0, 1, 32573),
        b(0, 0, 2, 1, 17198),
        b(2, 0, 1, -1, 9266),
        b(0, 0, 2, -1, 8822),
        b(2, -1, 0, -1, 8216),
        b(2, 0, -2, -1, 4324),
        b(2, 0, 1, 1, 4200),
        b(2, 1, 0, -1, -3359),
        b(2, -1, -1, 1, 2463),
        b(2, -1, 0, 1, 2211),
        b(2, -1, -1, -1, 2065),
        b(0, 1, -1, -1, -1870),
        b(4, 0, -1, -1, 1828),
        b(0, 1, 0, 1, -1794),
        b(0, 0, 0, 3, -1749),
        b(0, 1, -1, 1, -1565),
        b(1, 0, 0, 1, -1491),
        b(0, 1, 1, 1, -1475),
        b(0, 1, 1, -1, -1410),
        b(0, 1, 0, -1, -1344),
        b(1, 0, 0, -1, -1335),
        b(0, 0, 3, 1, 1107),
        b(4, 0, 0, -1, 1021),
        b(4, 0, -1, 1, 833),
        b(0, 0, 1, -3, 777),
        b(4, 0, -2, 1, 671),
        b(2, 0, 0, -3, 607),
        b(2, 0, 2, -1, 596),
        b(2, -1, 1, -1, 491),
        b(2, 0, -2, 1, -451),
        b(0, 0, 3, -1, 439),
        b(2, 0, 2, 1, 422),
        b(2, 0, -3, -1, 421),
        b(2, 1, -1, 1, -366),
        b(2, 1, 0, 1, -351),
        b(4, 0, 0, 1, 331),
        b(2, -1, 1, 1, 315),
        b(2, -2, 0, -1, 302),
        b(0, 0, 1, 3, -283),
        b(2, 1, 1, -1, -229),
        b(1, 1, 0, -1, 223),
        b(1, 1, 0, 1, 223),
        b(0, 1, -2, -1, -220),
        b(2, 1, -1, -1, -220),
        b(1, 0, 1, 1, -185),
        b(2, -1, -2, -1, 181),
        b(0, 1, 2, 1, -177),
        b(4, 0, -2, -1, 176),
        b(4, -1, -1, -1, 166),
        b(1, 0, 1, -1, -164),
        b(4, 0, 1, -1, 132),
        b(1, 0, -1, -1, -119),
        b(4, -1, 0, -1, 115),
        b(2, -2, 0, 1, 107),
    ]
}
