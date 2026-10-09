import Foundation

/// How good a fix is, from the receiver's horizontal accuracy estimate.
///
/// iOS gives apps no per-satellite signal strength, so the signal screens grade the fix itself:
/// the same red → green ladder GPS receivers use for SNR, driven by accuracy instead.
enum SignalQuality: Int, CaseIterable, Comparable {
    case poor, fair, moderate, good, excellent

    /// Upper accuracy bound in metres for fair, moderate, good and excellent.
    static let limits: [Double] = [20, 10, 5, 3]
    /// Accuracy at the far left of the quality bar.
    static let worst = 50.0
    /// Accuracy at the far right of the quality bar.
    static let best = 1.0

    init(accuracy: Double) {
        let passed = Self.limits.filter { accuracy <= $0 }.count
        self = SignalQuality(rawValue: passed) ?? .poor
    }

    /// 0 (50 m or worse) to 1 (1 m or better) on a log scale, for bar lengths and markers.
    static func position(accuracy: Double) -> Double {
        guard accuracy > 0 else { return 0 }
        let value = 1 - log(accuracy / best) / log(worst / best)
        return min(max(value, 0), 1)
    }

    static func < (lhs: SignalQuality, rhs: SignalQuality) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension Array where Element == AccuracySample {
    /// Mean horizontal accuracy of the samples within `window` seconds of the newest one.
    func averageAccuracy(window: TimeInterval = 30) -> Double? {
        guard let newest = last?.date else { return nil }
        let recent = filter { newest.timeIntervalSince($0.date) <= window }.map(\.horizontal)
        return recent.isEmpty ? nil : recent.reduce(0, +) / Double(recent.count)
    }
}
