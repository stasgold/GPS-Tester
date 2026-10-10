import Foundation

/// Satellite navigation systems, with the letter receivers put in front of satellite numbers.
enum Constellation: String, CaseIterable, Codable {
    case gps, glonass, galileo, beidou, qzss, navic, other

    var prefix: String {
        switch self {
        case .gps: "G"
        case .glonass: "R"
        case .galileo: "E"
        case .beidou: "C"
        case .qzss: "J"
        case .navic: "I"
        case .other: "S"
        }
    }

    var shortName: String {
        switch self {
        case .gps: "GPS"
        case .glonass: "GLO"
        case .galileo: "GAL"
        case .beidou: "BDS"
        case .qzss: "QZS"
        case .navic: "NAV"
        case .other: "SBAS"
        }
    }

    /// Classifies a CelesTrak object name, e.g. "GPS BIIR-2  (PRN 13)" or "COSMOS 2433 (723)".
    init(objectName name: String) {
        let upper = name.uppercased()
        if upper.hasPrefix("GPS") || upper.contains("NAVSTAR") { self = .gps }
        else if upper.hasPrefix("COSMOS") || upper.contains("GLONASS") { self = .glonass }
        else if upper.hasPrefix("GSAT0") || upper.contains("GALILEO") { self = .galileo }
        else if upper.contains("BEIDOU") || upper.hasPrefix("COMPASS") { self = .beidou }
        else if upper.hasPrefix("QZS") || upper.contains("MICHIBIKI") { self = .qzss }
        else if upper.hasPrefix("IRNSS") || upper.hasPrefix("NVS") { self = .navic }
        else { self = .other }
    }
}

/// Mean orbital elements of one satellite, as published by CelesTrak (OMM JSON, from NORAD TLEs).
struct OrbitalElements: Codable, Equatable, Identifiable {
    var name: String
    var noradID: Int
    var epoch: Date
    /// Revolutions per day (Kozai mean motion, as in a TLE).
    var meanMotion: Double
    var eccentricity: Double
    /// Degrees.
    var inclination: Double
    var rightAscension: Double
    var argumentOfPerigee: Double
    var meanAnomaly: Double

    var id: Int { noradID }

    enum CodingKeys: String, CodingKey {
        case name = "OBJECT_NAME", noradID = "NORAD_CAT_ID", epoch = "EPOCH", meanMotion = "MEAN_MOTION"
        case eccentricity = "ECCENTRICITY", inclination = "INCLINATION", rightAscension = "RA_OF_ASC_NODE"
        case argumentOfPerigee = "ARG_OF_PERICENTER", meanAnomaly = "MEAN_ANOMALY"
    }

    var constellation: Constellation { Constellation(objectName: name) }

    /// Receiver-style label: G13 for GPS PRN 13, C19 for BeiDou C19, otherwise the number in the name.
    var label: String {
        let constellation = constellation
        if let prn = Self.firstMatch(#"PRN\s*(\d+)"#, in: name) {
            return constellation.prefix + String(format: "%02d", Int(prn) ?? 0)
        }
        if constellation == .beidou, let number = Self.firstMatch(#"\(C(\d+)\)"#, in: name) {
            return "C" + String(format: "%02d", Int(number) ?? 0)
        }
        if constellation == .galileo, let number = Self.firstMatch(#"GSAT0*(\d+)"#, in: name) {
            return "E" + number
        }
        if let number = Self.firstMatch(#"\((\d+)\)"#, in: name) ?? Self.firstMatch(#"(\d+)"#, in: name) {
            return constellation.prefix + number
        }
        return constellation.prefix + String(noradID)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    /// Decodes CelesTrak's JSON, whose EPOCH has no time zone (it is UTC) and microsecond fractions.
    static func decode(_ data: Data) throws -> [OrbitalElements] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = Self.parseEpoch(text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad epoch \(text)"))
        }
        return try decoder.decode([OrbitalElements].self, from: data)
    }

    static func parseEpoch(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let trimmed = text.replacingOccurrences(of: "Z", with: "")
        let parts = trimmed.split(separator: ".", maxSplits: 1)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let first = parts.first, let whole = formatter.date(from: String(first)) else { return nil }
        let fraction = parts.count > 1 ? Double("0." + parts[1]) ?? 0 : 0
        return whole.addingTimeInterval(fraction)
    }
}

/// Where a satellite is, seen from the observer and over the Earth.
struct SatellitePosition: Identifiable, Equatable {
    var id: Int
    var label: String
    var constellation: Constellation
    /// Degrees clockwise from true north.
    var azimuth: Double
    /// Degrees above the horizon.
    var elevation: Double
    var rangeKm: Double
    /// Point on the Earth directly below the satellite.
    var latitude: Double
    var longitude: Double
}

/// Orbit propagation: two-body motion plus the secular effects of the Earth's oblateness (J2) on the
/// node, perigee and mean anomaly, starting from the TLE mean elements.
///
/// Compared with the full SGP4/SDP4 model this stays within about 0.1° on the sky over ten days for
/// GPS, GLONASS, Galileo and BeiDou orbits: far finer than a sky plot needs, at a tiny fraction of the code.
enum Orbit {
    private static let earthRadius = 6378.137 // km, WGS 84
    private static let j2 = 1.082_626_68e-3
    /// SGP4's WGS 72 constants, used to recover the Brouwer mean motion from the TLE's Kozai value.
    private static let sgp4Radius = 6378.135
    private static let ke = 60 / (6378.135 * 6378.135 * 6378.135 / 398_600.8).squareRoot()

    /// Earth-centred inertial position (TEME frame) in km at `date`.
    static func position(_ el: OrbitalElements, at date: Date) -> SIMD3<Double> {
        let minutes = date.timeIntervalSince(el.epoch) / 60
        let i = el.inclination * .pi / 180
        let e = el.eccentricity
        let cosI = cos(i)
        let beta = (1 - e * e).squareRoot()

        // Un-Kozai the mean motion as SGP4 does.
        let kozai = el.meanMotion * 2 * .pi / 1440 // rad/min
        let a1 = pow(ke / kozai, 2.0 / 3)
        let d1 = 0.75 * 1.082_616e-3 * (3 * cosI * cosI - 1) / (beta * beta * beta)
        let del1 = d1 / (a1 * a1)
        let a0 = a1 * (1 - del1 / 3 - del1 * del1 - 134.0 / 81 * del1 * del1 * del1)
        let n = kozai / (1 + d1 / (a0 * a0))
        let a = pow(ke / n, 2.0 / 3) * sgp4Radius

        let p = a * (1 - e * e)
        let f = 1.5 * j2 * (earthRadius / p) * (earthRadius / p) * n
        let raan = el.rightAscension * .pi / 180 - f * cosI * minutes
        let argp = el.argumentOfPerigee * .pi / 180 + 0.5 * f * (5 * cosI * cosI - 1) * minutes
        let meanAnomaly = el.meanAnomaly * .pi / 180 + (n + 0.5 * f * beta * (3 * cosI * cosI - 1)) * minutes

        var eccentricAnomaly = meanAnomaly
        for _ in 0..<10 {
            eccentricAnomaly -= (eccentricAnomaly - e * sin(eccentricAnomaly) - meanAnomaly) / (1 - e * cos(eccentricAnomaly))
        }
        let trueAnomaly = 2 * atan2((1 + e).squareRoot() * sin(eccentricAnomaly / 2), (1 - e).squareRoot() * cos(eccentricAnomaly / 2))
        let r = a * (1 - e * cos(eccentricAnomaly))
        let u = argp + trueAnomaly
        return SIMD3(r * (cos(raan) * cos(u) - sin(raan) * sin(u) * cosI),
                     r * (sin(raan) * cos(u) + cos(raan) * sin(u) * cosI),
                     r * sin(u) * sin(i))
    }

    /// Greenwich mean sidereal time in radians (IAU 1982).
    static func gmst(_ date: Date) -> Double {
        let jd = date.timeIntervalSince1970 / 86400 + 2_440_587.5
        let t = (jd - 2_451_545.0) / 36525
        var seconds = -6.2e-6 * t * t * t + 0.093104 * t * t + (876_600 * 3600 + 8_640_184.812866) * t + 67310.54841
        seconds = seconds.truncatingRemainder(dividingBy: 86400)
        if seconds < 0 { seconds += 86400 }
        return seconds / 240 * .pi / 180
    }

    /// Earth-fixed position in km.
    static func earthFixed(_ inertial: SIMD3<Double>, at date: Date) -> SIMD3<Double> {
        let g = gmst(date)
        return SIMD3(inertial.x * cos(g) + inertial.y * sin(g), -inertial.x * sin(g) + inertial.y * cos(g), inertial.z)
    }

    /// Azimuth and elevation in degrees and range in km of an Earth-fixed point, from a WGS 84 observer.
    static func lookAngles(_ ecef: SIMD3<Double>, latitude: Double, longitude: Double, altitude: Double = 0)
        -> (azimuth: Double, elevation: Double, range: Double) {
        let f = 1 / 298.257_223_563
        let e2 = f * (2 - f)
        let lat = latitude * .pi / 180, lon = longitude * .pi / 180
        let h = altitude / 1000
        let n = earthRadius / (1 - e2 * sin(lat) * sin(lat)).squareRoot()
        let observer = SIMD3((n + h) * cos(lat) * cos(lon), (n + h) * cos(lat) * sin(lon), (n * (1 - e2) + h) * sin(lat))
        let d = ecef - observer
        let east = -sin(lon) * d.x + cos(lon) * d.y
        let north = -sin(lat) * cos(lon) * d.x - sin(lat) * sin(lon) * d.y + cos(lat) * d.z
        let up = cos(lat) * cos(lon) * d.x + cos(lat) * sin(lon) * d.y + sin(lat) * d.z
        let azimuth = Geodesy.normalized(atan2(east, north) * 180 / .pi)
        let elevation = atan2(up, (east * east + north * north).squareRoot()) * 180 / .pi
        return (azimuth, elevation, (d * d).sum().squareRoot())
    }

    /// Geodetic latitude and longitude in degrees of the point below an Earth-fixed position.
    static func subpoint(_ ecef: SIMD3<Double>) -> (latitude: Double, longitude: Double) {
        let f = 1 / 298.257_223_563
        let e2 = f * (2 - f)
        let p = (ecef.x * ecef.x + ecef.y * ecef.y).squareRoot()
        var lat = atan2(ecef.z, p * (1 - e2))
        for _ in 0..<5 {
            let n = earthRadius / (1 - e2 * sin(lat) * sin(lat)).squareRoot()
            let h = p / cos(lat) - n
            lat = atan2(ecef.z, p * (1 - e2 * n / (n + h)))
        }
        return (lat * 180 / .pi, atan2(ecef.y, ecef.x) * 180 / .pi)
    }

    static func position(of el: OrbitalElements, at date: Date, latitude: Double, longitude: Double,
                         altitude: Double = 0) -> SatellitePosition {
        let ecef = earthFixed(position(el, at: date), at: date)
        let look = lookAngles(ecef, latitude: latitude, longitude: longitude, altitude: altitude)
        let ground = subpoint(ecef)
        return SatellitePosition(id: el.noradID, label: el.label, constellation: el.constellation,
                                 azimuth: look.azimuth, elevation: look.elevation, rangeKm: look.range,
                                 latitude: ground.latitude, longitude: ground.longitude)
    }

    /// Points below the satellite every `step` seconds for `duration` seconds from `date`.
    static func groundTrack(of el: OrbitalElements, from date: Date, duration: TimeInterval = 3600,
                            step: TimeInterval = 300) -> [(latitude: Double, longitude: Double)] {
        stride(from: 0, through: duration, by: step).map { offset in
            let when = date.addingTimeInterval(offset)
            return subpoint(earthFixed(position(el, at: when), at: when))
        }
    }
}
