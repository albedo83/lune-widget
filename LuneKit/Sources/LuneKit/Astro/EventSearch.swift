import Foundation

/// A crossing of an altitude threshold.
public struct Crossing: Sendable, Equatable {
    public var date: Date
    /// True when the function goes from below to above the threshold.
    public var isRising: Bool

    public init(date: Date, isRising: Bool) {
        self.date = date
        self.isRising = isRising
    }
}

/// Standard altitude thresholds in degrees.
public enum Altitudes {
    /// Rise/set: refraction (34′) plus mean semidiameter, applied to the body's centre.
    public static let riseSet = -0.833
    public static let astronomical = -18.0
}

public enum EventSearch {
    /// Finds all crossings of `threshold` by `f` inside `interval`: samples every `step` seconds, then bisects
    /// each sign change down to 1 s. Makes no assumption that events exist. Sorted by date.
    public static func crossings(
        in interval: DateInterval,
        threshold: Double,
        step: TimeInterval = 600,
        _ f: (Date) -> Double
    ) -> [Crossing] {
        precondition(step > 0)
        var result: [Crossing] = []
        var t0 = interval.start
        var v0 = f(t0) - threshold
        while t0 < interval.end {
            let t1 = min(t0.addingTimeInterval(step), interval.end)
            let v1 = f(t1) - threshold
            if (v0 < 0) != (v1 < 0) {
                result.append(Crossing(date: bisect(from: t0, to: t1, rising: v1 >= 0, threshold: threshold, f), isRising: v1 >= 0))
            }
            t0 = t1
            v0 = v1
        }
        return result
    }

    private static func bisect(from a: Date, to b: Date, rising: Bool, threshold: Double, _ f: (Date) -> Double) -> Date {
        var lo = a, hi = b
        while hi.timeIntervalSince(lo) > 1 {
            let mid = lo.addingTimeInterval(hi.timeIntervalSince(lo) / 2)
            if (f(mid) - threshold >= 0) == rising { hi = mid } else { lo = mid }
        }
        return lo.addingTimeInterval(hi.timeIntervalSince(lo) / 2)
    }
}
