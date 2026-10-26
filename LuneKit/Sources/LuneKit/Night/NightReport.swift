import Foundation

/// Astronomical night (Sun below −18°) within a displayed period.
public enum AstroNight: Sendable, Equatable {
    /// The Sun never goes below −18° during the period.
    case none
    /// The Sun stays below −18° for the whole period.
    case wholePeriod
    /// From the Sun's descent below −18° to its following ascent, clamped to the period.
    case interval(DateInterval)
}

/// Everything the widget shows for one night (local noon day J → local noon day J+1).
public struct NightReport: Sendable, Equatable {
    public var period: DateInterval
    /// First moonrise in the period, if any.
    public var moonrise: Date?
    /// First moonset in the period, if any.
    public var moonset: Date?
    public var astroNight: AstroNight
    /// Parts of the astronomical night (or of the whole period for `.wholePeriod`) with the Moon below the horizon.
    public var darkWindows: [DateInterval]
    /// Instant used for illumination, waxing and phase name: middle of the astro night, else of the period.
    public var referenceDate: Date
    public var illumination: Double
    public var isWaxing: Bool
    public var phaseName: MoonPhaseName
    /// `.full` if the elongation at `period.end` is below 180°, else `.new` (independent of `isWaxing`, which is
    /// taken at `referenceDate`).
    public var nextPhase: PrincipalPhase
    /// First occurrence of `nextPhase` after the end of the period.
    public var nextPhaseDate: Date

    public init(
        period: DateInterval, moonrise: Date?, moonset: Date?, astroNight: AstroNight, darkWindows: [DateInterval],
        referenceDate: Date, illumination: Double, isWaxing: Bool, phaseName: MoonPhaseName,
        nextPhase: PrincipalPhase, nextPhaseDate: Date
    ) {
        self.period = period
        self.moonrise = moonrise
        self.moonset = moonset
        self.astroNight = astroNight
        self.darkWindows = darkWindows
        self.referenceDate = referenceDate
        self.illumination = illumination
        self.isWaxing = isWaxing
        self.phaseName = phaseName
        self.nextPhase = nextPhase
        self.nextPhaseDate = nextPhaseDate
    }
}
