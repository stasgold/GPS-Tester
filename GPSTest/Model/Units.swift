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

    private static func number(_ value: Double, digits: Int) -> String {
        // Same decimal point as the coordinates, whatever the region.
        value.formatted(.number.precision(.fractionLength(digits)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }
}
