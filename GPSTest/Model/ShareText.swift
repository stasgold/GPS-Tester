import Foundation

/// Plain-text position for the share sheet and the clipboard.
enum ShareText {
    static func position(latitude: Double, longitude: Double, altitude: Double?, accuracy: Double?,
                         name: String? = nil, format: CoordinateFormat, units: UnitSystem) -> String {
        var lines: [String] = []
        if let name { lines.append(name) }
        lines.append(CoordinateFormatter.singleLine(latitude: latitude, longitude: longitude, format: format))
        if format != .decimal {
            lines.append(String(format: "%.6f, %.6f", latitude, longitude))
        }
        if let altitude { lines.append("Altitude: \(units.length(altitude))") }
        if let accuracy { lines.append("Accuracy: ±\(units.length(accuracy))") }
        lines.append(mapsLink(latitude: latitude, longitude: longitude, name: name).absoluteString)
        return lines.joined(separator: "\n")
    }

    static func mapsLink(latitude: Double, longitude: Double, name: String? = nil) -> URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        let ll = String(format: "%.6f,%.6f", latitude, longitude)
        components.queryItems = [URLQueryItem(name: "ll", value: ll), URLQueryItem(name: "q", value: name ?? ll)]
        return components.url!
    }
}
