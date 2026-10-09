import Foundation

/// Parses typed coordinates for manual waypoints.
enum WaypointInput {
    /// Decimal degrees, accepting a comma as the decimal separator and an N/S/E/W suffix or prefix.
    static func parse(latitude: String, longitude: String) -> (latitude: Double, longitude: Double)? {
        guard let lat = degrees(latitude, positive: "N", negative: "S"), abs(lat) <= 90,
              let lon = degrees(longitude, positive: "E", negative: "W"), abs(lon) <= 180 else { return nil }
        return (lat, lon)
    }

    static func degrees(_ text: String, positive: Character, negative: Character) -> Double? {
        var s = text.trimmingCharacters(in: .whitespaces).uppercased()
            .replacingOccurrences(of: "°", with: "")
            .replacingOccurrences(of: ",", with: ".")
        var sign = 1.0
        if let last = s.last, last == positive || last == negative {
            sign = last == negative ? -1 : 1
            s.removeLast()
        } else if let first = s.first, first == positive || first == negative {
            sign = first == negative ? -1 : 1
            s.removeFirst()
        }
        guard let value = Double(s.trimmingCharacters(in: .whitespaces)), value.isFinite else { return nil }
        if sign < 0, value < 0 { return nil } // "-12 S" is ambiguous
        return sign * value
    }
}
