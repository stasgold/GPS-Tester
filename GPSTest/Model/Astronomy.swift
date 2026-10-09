import Foundation

/// Sun and moon positions, rise/set times and moon phase.
///
/// A Swift port of Vladimir Agafonkin's SunCalc (BSD-2-Clause), the same low-precision
/// formulas GPS Test's Time screen relies on. Accurate to about a minute for rise and set times.
enum Astronomy {
    struct Position: Equatable {
        /// Degrees clockwise from true north, 0..<360.
        var azimuth: Double
        /// Degrees above the horizon (negative below).
        var altitude: Double
    }

    struct SunTimes: Equatable {
        var solarNoon: Date
        var sunrise: Date?
        var sunset: Date?
        var civilDawn: Date?
        var civilDusk: Date?
        var nauticalDawn: Date?
        var nauticalDusk: Date?
        var astronomicalDawn: Date?
        var astronomicalDusk: Date?
        var goldenHourEnd: Date?
        var goldenHour: Date?

        /// Time between sunrise and sunset; nil during polar night or midnight sun.
        var dayLength: TimeInterval? {
            guard let sunrise, let sunset else { return nil }
            return sunset.timeIntervalSince(sunrise)
        }
    }

    struct MoonTimes: Equatable {
        var rise: Date?
        var set: Date?
        var alwaysUp = false
        var alwaysDown = false
    }

    struct MoonIllumination: Equatable {
        /// Lit fraction, 0 (new) to 1 (full).
        var fraction: Double
        /// 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter.
        var phase: Double
        /// Bright limb midpoint angle in radians.
        var angle: Double

        var phaseName: String {
            switch phase {
            case ..<0.0339, 0.9661...: "New Moon"
            case ..<0.2161: "Waxing Crescent"
            case ..<0.2839: "First Quarter"
            case ..<0.4661: "Waxing Gibbous"
            case ..<0.5339: "Full Moon"
            case ..<0.7161: "Waning Gibbous"
            case ..<0.7839: "Last Quarter"
            default: "Waning Crescent"
            }
        }

        var symbolName: String {
            switch phaseName {
            case "New Moon": "moonphase.new.moon"
            case "Waxing Crescent": "moonphase.waxing.crescent"
            case "First Quarter": "moonphase.first.quarter"
            case "Waxing Gibbous": "moonphase.waxing.gibbous"
            case "Full Moon": "moonphase.full.moon"
            case "Waning Gibbous": "moonphase.waning.gibbous"
            case "Last Quarter": "moonphase.last.quarter"
            default: "moonphase.waning.crescent"
            }
        }

        /// Days since the last new moon (synodic month 29.53 days).
        var age: Double { phase * 29.530_588 }
    }

    // MARK: Public API

    static func sunPosition(at date: Date, latitude: Double, longitude: Double) -> Position {
        let raw = sunPositionRadians(at: date, latitude: latitude, longitude: longitude)
        return Position(azimuth: compassDegrees(fromSouthAzimuth: raw.azimuth), altitude: raw.altitude / rad)
    }

    /// Times for the solar day nearest `date` at this longitude.
    static func sunTimes(on date: Date, latitude: Double, longitude: Double) -> SunTimes {
        let lw = rad * -longitude
        let phi = rad * latitude
        let d = toDays(date)
        let n = julianCycle(d, lw)
        let ds = approxTransit(0, lw, n)
        let m = solarMeanAnomaly(ds)
        let l = eclipticLongitude(m)
        let dec = declination(l, 0)
        let jNoon = solarTransitJ(ds, m, l)

        func pair(_ angle: Double) -> (Date?, Date?) {
            let h0 = angle * rad
            let w = hourAngle(h0, phi, dec)
            guard w.isFinite else { return (nil, nil) }
            let jSet = solarTransitJ(approxTransit(w, lw, n), m, l)
            let jRise = jNoon - (jSet - jNoon)
            return (fromJulian(jRise), fromJulian(jSet))
        }

        let sun = pair(-0.833)
        let civil = pair(-6)
        let nautical = pair(-12)
        let astronomical = pair(-18)
        let golden = pair(6)
        return SunTimes(solarNoon: fromJulian(jNoon),
                        sunrise: sun.0, sunset: sun.1,
                        civilDawn: civil.0, civilDusk: civil.1,
                        nauticalDawn: nautical.0, nauticalDusk: nautical.1,
                        astronomicalDawn: astronomical.0, astronomicalDusk: astronomical.1,
                        goldenHourEnd: golden.0, goldenHour: golden.1)
    }

    static func moonPosition(at date: Date, latitude: Double, longitude: Double) -> (position: Position, distance: Double) {
        let raw = moonPositionRadians(at: date, latitude: latitude, longitude: longitude)
        return (Position(azimuth: compassDegrees(fromSouthAzimuth: raw.azimuth), altitude: raw.altitude / rad), raw.distance)
    }

    static func moonIllumination(at date: Date) -> MoonIllumination {
        let d = toDays(date)
        let s = sunCoords(d)
        let m = moonCoords(d)
        let sunDistance = 149_598_000.0
        let phi = acos(sin(s.dec) * sin(m.dec) + cos(s.dec) * cos(m.dec) * cos(s.ra - m.ra))
        let inc = atan2(sunDistance * sin(phi), m.dist - sunDistance * cos(phi))
        let angle = atan2(cos(s.dec) * sin(s.ra - m.ra),
                          sin(s.dec) * cos(m.dec) - cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra))
        return MoonIllumination(fraction: (1 + cos(inc)) / 2,
                                phase: 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / .pi,
                                angle: angle)
    }

    /// Moonrise and moonset during the calendar day containing `date` in `timeZone`.
    static func moonTimes(on date: Date, latitude: Double, longitude: Double, timeZone: TimeZone = .current) -> MoonTimes {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let hc = 0.133 * rad
        func moonAltitude(_ hours: Double) -> Double {
            moonPositionRadians(at: start.addingTimeInterval(hours * 3600), latitude: latitude, longitude: longitude).altitude - hc
        }

        var h0 = moonAltitude(0)
        var rise: Double?
        var set: Double?
        var ye = 0.0
        var i = 1.0
        while i <= 24 {
            let h1 = moonAltitude(i)
            let h2 = moonAltitude(i + 1)
            let a = (h0 + h2) / 2 - h1
            let b = (h2 - h0) / 2
            let xe = -b / (2 * a)
            ye = (a * xe + b) * xe + h1
            let disc = b * b - 4 * a * h1
            var roots = 0
            var x1 = 0.0, x2 = 0.0
            if disc >= 0 {
                let dx = sqrt(disc) / (abs(a) * 2)
                x1 = xe - dx
                x2 = xe + dx
                if abs(x1) <= 1 { roots += 1 }
                if abs(x2) <= 1 { roots += 1 }
                if x1 < -1 { x1 = x2 }
            }
            if roots == 1 {
                if h0 < 0 { rise = i + x1 } else { set = i + x1 }
            } else if roots == 2 {
                rise = i + (ye < 0 ? x2 : x1)
                set = i + (ye < 0 ? x1 : x2)
            }
            if rise != nil, set != nil { break }
            h0 = h2
            i += 2
        }

        var result = MoonTimes()
        result.rise = rise.map { start.addingTimeInterval($0 * 3600) }
        result.set = set.map { start.addingTimeInterval($0 * 3600) }
        if rise == nil, set == nil {
            if ye > 0 { result.alwaysUp = true } else { result.alwaysDown = true }
        }
        return result
    }

    // MARK: SunCalc internals (radians)

    private static let rad = Double.pi / 180
    private static let daySeconds = 86_400.0
    private static let j1970 = 2_440_588.0
    private static let j2000 = 2_451_545.0
    private static let obliquity = rad * 23.4397
    private static let j0 = 0.0009

    private static func toJulian(_ date: Date) -> Double { date.timeIntervalSince1970 / daySeconds - 0.5 + j1970 }
    private static func fromJulian(_ j: Double) -> Date { Date(timeIntervalSince1970: (j + 0.5 - j1970) * daySeconds) }
    private static func toDays(_ date: Date) -> Double { toJulian(date) - j2000 }

    private static func rightAscension(_ l: Double, _ b: Double) -> Double {
        atan2(sin(l) * cos(obliquity) - tan(b) * sin(obliquity), cos(l))
    }

    private static func declination(_ l: Double, _ b: Double) -> Double {
        asin(sin(b) * cos(obliquity) + cos(b) * sin(obliquity) * sin(l))
    }

    private static func azimuth(_ h: Double, _ phi: Double, _ dec: Double) -> Double {
        atan2(sin(h), cos(h) * sin(phi) - tan(dec) * cos(phi))
    }

    private static func altitude(_ h: Double, _ phi: Double, _ dec: Double) -> Double {
        asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(h))
    }

    private static func siderealTime(_ d: Double, _ lw: Double) -> Double { rad * (280.16 + 360.985_623_5 * d) - lw }

    private static func astroRefraction(_ h: Double) -> Double {
        let h = max(h, 0)
        return 0.000_296_7 / tan(h + 0.003_125_36 / (h + 0.089_011_79))
    }

    private static func solarMeanAnomaly(_ d: Double) -> Double { rad * (357.5291 + 0.985_600_28 * d) }

    private static func eclipticLongitude(_ m: Double) -> Double {
        let c = rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m))
        return m + c + rad * 102.9372 + .pi
    }

    private static func sunCoords(_ d: Double) -> (dec: Double, ra: Double) {
        let l = eclipticLongitude(solarMeanAnomaly(d))
        return (declination(l, 0), rightAscension(l, 0))
    }

    private static func julianCycle(_ d: Double, _ lw: Double) -> Double { (d - j0 - lw / (2 * .pi)).rounded() }
    private static func approxTransit(_ ht: Double, _ lw: Double, _ n: Double) -> Double { j0 + (ht + lw) / (2 * .pi) + n }
    private static func solarTransitJ(_ ds: Double, _ m: Double, _ l: Double) -> Double {
        j2000 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l)
    }
    private static func hourAngle(_ h: Double, _ phi: Double, _ d: Double) -> Double {
        acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d)))
    }

    /// SunCalc measures azimuth from south, westward; compasses measure from north, eastward.
    private static func compassDegrees(fromSouthAzimuth azimuth: Double) -> Double {
        Geodesy.normalized(azimuth / rad + 180)
    }

    static func sunPositionRadians(at date: Date, latitude: Double, longitude: Double) -> (azimuth: Double, altitude: Double) {
        let lw = rad * -longitude
        let phi = rad * latitude
        let d = toDays(date)
        let c = sunCoords(d)
        let h = siderealTime(d, lw) - c.ra
        return (azimuth(h, phi, c.dec), altitude(h, phi, c.dec))
    }

    private static func moonCoords(_ d: Double) -> (ra: Double, dec: Double, dist: Double) {
        let l = rad * (218.316 + 13.176_396 * d)
        let m = rad * (134.963 + 13.064_993 * d)
        let f = rad * (93.272 + 13.229_350 * d)
        let lng = l + rad * 6.289 * sin(m)
        let lat = rad * 5.128 * sin(f)
        let dist = 385_001 - 20905 * cos(m)
        return (rightAscension(lng, lat), declination(lng, lat), dist)
    }

    static func moonPositionRadians(at date: Date, latitude: Double, longitude: Double)
        -> (azimuth: Double, altitude: Double, distance: Double) {
        let lw = rad * -longitude
        let phi = rad * latitude
        let d = toDays(date)
        let c = moonCoords(d)
        let h = siderealTime(d, lw) - c.ra
        var alt = altitude(h, phi, c.dec)
        alt += astroRefraction(alt)
        return (azimuth(h, phi, c.dec), alt, c.dist)
    }
}
