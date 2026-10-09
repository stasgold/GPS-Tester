import Foundation

/// Unit system for distances, altitudes and speeds.
enum UnitSystem: String, CaseIterable, Identifiable {
    case metric, imperial, nautical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric: "Metric (m, km/h)"
        case .imperial: "Imperial (ft, mph)"
        case .nautical: "Nautical (m, knots)"
        }
    }

    /// Short lengths: altitude and accuracy.
    func length(_ metres: Double) -> String {
        switch self {
        case .imperial: "\(Self.number(metres * 3.280_84, digits: 0)) ft"
        case .metric, .nautical: "\(Self.number(metres, digits: metres < 10 ? 1 : 0)) m"
        }
    }

    /// Distances, switching to km, mi or nmi once they get long.
    func distance(_ metres: Double) -> String {
        switch self {
        case .metric:
            return metres < 1000 ? "\(Self.number(metres, digits: 0)) m" : "\(Self.number(metres / 1000, digits: metres < 10_000 ? 2 : 1)) km"
        case .imperial:
            let feet = metres * 3.280_84
            return feet < 1000 ? "\(Self.number(feet, digits: 0)) ft" : "\(Self.number(metres / 1609.344, digits: 2)) mi"
        case .nautical:
            return metres < 1852 / 2 ? "\(Self.number(metres, digits: 0)) m" : "\(Self.number(metres / 1852, digits: 2)) nmi"
        }
    }

    /// Speeds from metres per second.
    func speed(_ metresPerSecond: Double) -> String {
        switch self {
        case .metric: "\(Self.number(metresPerSecond * 3.6, digits: 1)) km/h"
        case .imperial: "\(Self.number(metresPerSecond * 2.236_936, digits: 1)) mph"
        case .nautical: "\(Self.number(metresPerSecond * 1.943_844, digits: 1)) kn"
        }
    }

    /// Speed as a number in this system's unit, for gauges.
    func speedValue(_ metresPerSecond: Double) -> Double {
        switch self {
        case .metric: metresPerSecond * 3.6
        case .imperial: metresPerSecond * 2.236_936
        case .nautical: metresPerSecond * 1.943_844
        }
    }

    var speedUnit: String {
        switch self {
        case .metric: "km/h"
        case .imperial: "mph"
        case .nautical: "knots"
        }
    }

    /// Full scale of the speedometer and the step between its numbers.
    var speedometerScale: (max: Double, step: Double) {
        switch self {
        case .metric: (200, 20)
        case .imperial: (120, 10)
        case .nautical: (100, 10)
        }
    }

    /// Altitude as a number in this system's unit, for gauges.
    func altitudeValue(_ metres: Double) -> Double {
        self == .imperial ? metres * 3.280_84 : metres
    }

    var altitudeUnit: String { self == .imperial ? "feet" : "meters" }

    var shortLengthUnit: String { self == .imperial ? "ft" : "m" }

    private static func number(_ value: Double, digits: Int) -> String {
        // Same decimal point as the coordinates, whatever the region.
        value.formatted(.number.precision(.fractionLength(digits)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }
}
