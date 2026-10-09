import Foundation

/// Great-circle helpers for the waypoint distance and bearing readouts.
enum Geodesy {
    /// Mean Earth radius in metres (IUGG).
    static let earthRadius = 6_371_008.8

    /// Haversine distance in metres.
    static func distance(fromLatitude lat1: Double, longitude lon1: Double,
                         toLatitude lat2: Double, longitude lon2: Double) -> Double {
        let phi1 = lat1 * .pi / 180, phi2 = lat2 * .pi / 180
        let dPhi = (lat2 - lat1) * .pi / 180
        let dLambda = (lon2 - lon1) * .pi / 180
        let h = sin(dPhi / 2) * sin(dPhi / 2) + cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Initial great-circle bearing in degrees clockwise from true north, 0..<360.
    static func bearing(fromLatitude lat1: Double, longitude lon1: Double,
                        toLatitude lat2: Double, longitude lon2: Double) -> Double {
        let phi1 = lat1 * .pi / 180, phi2 = lat2 * .pi / 180
        let dLambda = (lon2 - lon1) * .pi / 180
        let y = sin(dLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLambda)
        return normalized(atan2(y, x) * 180 / .pi)
    }

    /// Wraps any angle into 0..<360.
    static func normalized(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// 16-point compass name for a bearing, e.g. 247° → "WSW".
    static func cardinal(_ degrees: Double) -> String {
        let names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                     "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        return names[Int((normalized(degrees) / 22.5).rounded()) % 16]
    }
}
