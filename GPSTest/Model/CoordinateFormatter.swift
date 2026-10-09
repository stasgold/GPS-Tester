import Foundation

/// The ways a position can be written, matching the formats GPS Test offers on Android.
enum CoordinateFormat: String, CaseIterable, Identifiable {
    case decimal, degreesMinutes, degreesMinutesSeconds, utm, mgrs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .decimal: "Decimal degrees"
        case .degreesMinutes: "Degrees, minutes"
        case .degreesMinutesSeconds: "Degrees, minutes, seconds"
        case .utm: "UTM"
        case .mgrs: "MGRS"
        }
    }

    var example: String {
        switch self {
        case .decimal: "37.77493° N"
        case .degreesMinutes: "37° 46.496′ N"
        case .degreesMinutesSeconds: "37° 46′ 29.75″ N"
        case .utm: "10S 551131E 4180999N"
        case .mgrs: "10S EG 51130 80998"
        }
    }
}

/// A position on the Universal Transverse Mercator grid (WGS 84).
struct UTMCoordinate: Equatable {
    var zone: Int
    var band: Character
    var easting: Double
    var northing: Double

    var isNorthern: Bool { band >= "N" }

    var formatted: String {
        "\(zone)\(band) \(Int(easting.rounded()))E \(Int(northing.rounded()))N"
    }
}

enum CoordinateFormatter {
    /// Latitude and longitude on separate lines (decimal, DM, DMS) or one grid reference (UTM, MGRS).
    static func lines(latitude: Double, longitude: Double, format: CoordinateFormat) -> [String] {
        switch format {
        case .decimal, .degreesMinutes, .degreesMinutesSeconds:
            return [angle(latitude, isLatitude: true, format: format),
                    angle(longitude, isLatitude: false, format: format)]
        case .utm:
            return [utm(latitude: latitude, longitude: longitude)?.formatted ?? "Outside UTM (polar)"]
        case .mgrs:
            return [mgrs(latitude: latitude, longitude: longitude) ?? "Outside MGRS (polar)"]
        }
    }

    /// One line, e.g. for sharing or copying.
    static func singleLine(latitude: Double, longitude: Double, format: CoordinateFormat) -> String {
        lines(latitude: latitude, longitude: longitude, format: format).joined(separator: ", ")
    }

    // MARK: Angles

    static func angle(_ value: Double, isLatitude: Bool, format: CoordinateFormat) -> String {
        let hemisphere = isLatitude ? (value < 0 ? "S" : "N") : (value < 0 ? "W" : "E")
        let magnitude = abs(value)
        switch format {
        case .degreesMinutes:
            // Round once at the final precision so 59.9999′ never prints as 60.000′.
            let totalMinutes = (magnitude * 60 * 1000).rounded() / 1000
            let degrees = Int(totalMinutes / 60)
            let minutes = totalMinutes - Double(degrees) * 60
            return "\(degrees)° \(String(format: "%06.3f", minutes))′ \(hemisphere)"
        case .degreesMinutesSeconds:
            let totalSeconds = (magnitude * 3600 * 100).rounded() / 100
            let degrees = Int(totalSeconds / 3600)
            let minutes = Int((totalSeconds - Double(degrees) * 3600) / 60)
            let seconds = totalSeconds - Double(degrees) * 3600 - Double(minutes) * 60
            return "\(degrees)° \(String(format: "%02d", minutes))′ \(String(format: "%05.2f", seconds))″ \(hemisphere)"
        default:
            return "\(String(format: "%.6f", magnitude))° \(hemisphere)"
        }
    }

    // MARK: UTM

    private static let a = 6_378_137.0
    private static let f = 1 / 298.257_223_563
    private static let k0 = 0.9996

    static func utmZone(latitude: Double, longitude: Double) -> Int {
        var lon = longitude
        if lon >= 180 { lon -= 360 }
        var zone = Int(floor((lon + 180) / 6)) + 1
        zone = min(max(zone, 1), 60)
        // Norway and Svalbard exceptions.
        if latitude >= 56, latitude < 64, lon >= 3, lon < 12 { zone = 32 }
        if latitude >= 72, latitude < 84 {
            if lon >= 0, lon < 9 { zone = 31 }
            else if lon >= 9, lon < 21 { zone = 33 }
            else if lon >= 21, lon < 33 { zone = 35 }
            else if lon >= 33, lon < 42 { zone = 37 }
        }
        return zone
    }

    static func latitudeBand(_ latitude: Double) -> Character? {
        guard latitude >= -80, latitude <= 84 else { return nil }
        let bands = Array("CDEFGHJKLMNPQRSTUVWX")
        let index = min(Int(floor((latitude + 80) / 8)), bands.count - 1)
        return bands[index]
    }

    /// Transverse Mercator projection using the Krüger series (sub-millimetre accuracy within a zone).
    static func utm(latitude: Double, longitude: Double, zone forcedZone: Int? = nil) -> UTMCoordinate? {
        guard let band = latitudeBand(latitude) else { return nil }
        let zone = forcedZone ?? utmZone(latitude: latitude, longitude: longitude)
        let lambda0 = Double((zone - 1) * 6 - 180 + 3) * .pi / 180
        let phi = latitude * .pi / 180
        var dLambda = longitude * .pi / 180 - lambda0
        if dLambda > .pi { dLambda -= 2 * .pi }
        if dLambda < -.pi { dLambda += 2 * .pi }

        let n = f / (2 - f)
        let n2 = n * n, n3 = n2 * n, n4 = n3 * n
        let bigA = a / (1 + n) * (1 + n2 / 4 + n4 / 64)
        let alpha = [
            n / 2 - 2 * n2 / 3 + 5 * n3 / 16 + 41 * n4 / 180,
            13 * n2 / 48 - 3 * n3 / 5 + 557 * n4 / 1440,
            61 * n3 / 240 - 103 * n4 / 140,
            49561 * n4 / 161_280,
        ]
        let e = sqrt(f * (2 - f))
        let t = sinh(atanh(sin(phi)) - e * atanh(e * sin(phi)))
        let xiPrime = atan2(t, cos(dLambda))
        let etaPrime = atanh(sin(dLambda) / sqrt(1 + t * t))
        var xi = xiPrime
        var eta = etaPrime
        for j in 1...4 {
            let k = 2 * Double(j)
            xi += alpha[j - 1] * sin(k * xiPrime) * cosh(k * etaPrime)
            eta += alpha[j - 1] * cos(k * xiPrime) * sinh(k * etaPrime)
        }
        let easting = 500_000 + k0 * bigA * eta
        var northing = k0 * bigA * xi
        if latitude < 0 { northing += 10_000_000 }
        return UTMCoordinate(zone: zone, band: band, easting: easting, northing: northing)
    }

    // MARK: MGRS

    /// Military Grid Reference System at 1 m precision, e.g. "10S EG 51130 80998".
    static func mgrs(latitude: Double, longitude: Double) -> String? {
        guard let utm = utm(latitude: latitude, longitude: longitude) else { return nil }
        let columnSets = [Array("ABCDEFGH"), Array("JKLMNPQR"), Array("STUVWXYZ")]
        let rowLetters = Array("ABCDEFGHJKLMNPQRSTUV")
        let set = (utm.zone - 1) % 3
        let column = Int(floor(utm.easting / 100_000))
        guard column >= 1, column <= 8 else { return nil }
        let rowOffset = utm.zone % 2 == 0 ? 5 : 0
        let row = (Int(floor(utm.northing / 100_000)) + rowOffset) % 20
        // MGRS truncates rather than rounds: the reference names the square the point is in.
        let e = Int(floor(utm.easting)) % 100_000
        let n = Int(floor(utm.northing)) % 100_000
        return "\(utm.zone)\(utm.band) \(columnSets[set][column - 1])\(rowLetters[row]) "
            + String(format: "%05d %05d", e, n)
    }
}
