import Foundation
import Testing
@testable import GPSTest

/// Expected values are SunCalc's own test fixtures (Kyiv, 5 March 2013).
struct AstronomyTests {
    let date = Date(timeIntervalSince1970: 1_362_441_600) // 2013-03-05T00:00:00Z
    let latitude = 50.5
    let longitude = 30.5

    private func iso(_ text: String) -> Date {
        try! Date(text, strategy: .iso8601)
    }

    private func close(_ a: Date?, _ b: String, within seconds: TimeInterval = 1) -> Bool {
        guard let a else { return false }
        return abs(a.timeIntervalSince(iso(b))) <= seconds
    }

    @Test func sunPosition() {
        let raw = Astronomy.sunPositionRadians(at: date, latitude: latitude, longitude: longitude)
        #expect(abs(raw.azimuth - -2.5003175907168385) < 1e-9)
        #expect(abs(raw.altitude - -0.7000406838781611) < 1e-9)
        let position = Astronomy.sunPosition(at: date, latitude: latitude, longitude: longitude)
        #expect(abs(position.azimuth - (-2.5003175907168385 * 180 / .pi + 180)) < 1e-6)
    }

    @Test func sunTimes() throws {
        let times = Astronomy.sunTimes(on: date, latitude: latitude, longitude: longitude)
        #expect(close(times.solarNoon, "2013-03-05T10:10:57Z"))
        #expect(close(times.sunrise, "2013-03-05T04:34:56Z"))
        #expect(close(times.sunset, "2013-03-05T15:46:57Z"))
        #expect(close(times.civilDawn, "2013-03-05T04:02:17Z"))
        #expect(close(times.civilDusk, "2013-03-05T16:19:36Z"))
        #expect(close(times.nauticalDawn, "2013-03-05T03:24:31Z"))
        #expect(close(times.astronomicalDusk, "2013-03-05T17:35:36Z"))
        let length = try #require(times.dayLength)
        #expect(abs(length - (11 * 3600 + 12 * 60 + 1)) < 2)
    }

    @Test func polarNightHasNoSunrise() {
        let midwinter = Date(timeIntervalSince1970: 1_734_782_400) // 2024-12-21T12:00:00Z
        let times = Astronomy.sunTimes(on: midwinter, latitude: 78.2, longitude: 15.6) // Longyearbyen
        #expect(times.sunrise == nil)
        #expect(times.sunset == nil)
        #expect(times.dayLength == nil)
    }

    @Test func moonPosition() {
        let raw = Astronomy.moonPositionRadians(at: date, latitude: latitude, longitude: longitude)
        #expect(abs(raw.azimuth - -0.9783999522438226) < 1e-9)
        #expect(abs(raw.altitude - 0.014551482243892251) < 1e-9)
        #expect(abs(raw.distance - 364_121.37256256194) < 1e-6)
    }

    @Test func moonIllumination() {
        let illumination = Astronomy.moonIllumination(at: date)
        #expect(abs(illumination.fraction - 0.4848068202456373) < 1e-9)
        #expect(abs(illumination.phase - 0.7548368838538762) < 1e-9)
        #expect(abs(illumination.angle - 1.6732942678578346) < 1e-9)
        #expect(illumination.phaseName == "Last Quarter")
    }

    @Test func moonTimes() {
        let day = Date(timeIntervalSince1970: 1_362_355_200) // 2013-03-04T00:00:00Z
        let times = Astronomy.moonTimes(on: day, latitude: latitude, longitude: longitude, timeZone: .gmt)
        #expect(close(times.rise, "2013-03-04T23:54:29Z"))
        #expect(close(times.set, "2013-03-04T07:47:58Z"))
        #expect(!times.alwaysUp)
        #expect(!times.alwaysDown)
    }

    @Test func phaseNames() {
        func name(_ phase: Double) -> String {
            Astronomy.MoonIllumination(fraction: 0, phase: phase, angle: 0).phaseName
        }
        #expect(name(0) == "New Moon")
        #expect(name(0.99) == "New Moon")
        #expect(name(0.1) == "Waxing Crescent")
        #expect(name(0.25) == "First Quarter")
        #expect(name(0.4) == "Waxing Gibbous")
        #expect(name(0.5) == "Full Moon")
        #expect(name(0.6) == "Waning Gibbous")
        #expect(name(0.75) == "Last Quarter")
        #expect(name(0.9) == "Waning Crescent")
    }
}
