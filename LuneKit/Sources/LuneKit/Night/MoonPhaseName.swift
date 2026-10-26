import Foundation

/// Eight-fold phase name. Raw values are identifiers; localization happens in the app.
public enum MoonPhaseName: String, CaseIterable, Sendable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous, fullMoon, waningGibbous, lastQuarter, waningCrescent

    /// A principal phase occurring in the period wins; otherwise the name comes from the elongation quadrant.
    public init(principalInPeriod: PrincipalPhase?, elongationAtReference: Double) {
        if let p = principalInPeriod {
            switch p {
            case .new: self = .newMoon
            case .firstQuarter: self = .firstQuarter
            case .full: self = .fullMoon
            case .lastQuarter: self = .lastQuarter
            }
            return
        }
        switch AngleMath.normalize(elongationAtReference) {
        case ..<90: self = .waxingCrescent
        case ..<180: self = .waxingGibbous
        case ..<270: self = .waningGibbous
        default: self = .waningCrescent
        }
    }
}
