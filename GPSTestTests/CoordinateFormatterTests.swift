import Foundation
import Testing
@testable import GPSTest

/// Reference values from PROJ (pyproj) and the `mgrs` package.
struct CoordinateFormatterTests {
    struct Case: Sendable {
        var latitude: Double, longitude: Double
        var zone: Int, band: Character, easting: Double, northing: Double
        var mgrs: String
    }

    static let cases: [Case] = [
        Case(latitude: 37.7749, longitude: -122.4194, zone: 10, band: "S", easting: 551_130.768, northing: 4_180_998.881, mgrs: "10S EG 51130 80998"),
        Case(latitude: -33.8688, longitude: 151.2093, zone: 56, band: "H", easting: 334_368.634, northing: 6_250_948.345, mgrs: "56H LH 34368 50948"),
        Case(latitude: 51.5007, longitude: -0.1246, zone: 30, band: "U", easting: 699_567.540, northing: 5_709_427.563, mgrs: "30U XC 99567 09427"),
        Case(latitude: 60.0, longitude: 5.5, zone: 32, band: "V", easting: 304_838.827, northing: 6_656_575.859, mgrs: "32V LM 04838 56575"),
        Case(latitude: 0, longitude: 0, zone: 31, band: "N", easting: 166_021.443, northing: 0, mgrs: "31N AA 66021 00000"),
        Case(latitude: 78.2, longitude: 15.6, zone: 33, band: "X", easting: 513_696.945, northing: 8_680_760.053, mgrs: "33X WG 13696 80760"),
    ]

    @Test(arguments: cases)
    func utmMatchesProj(_ c: Case) throws {
        let utm = try #require(CoordinateFormatter.utm(latitude: c.latitude, longitude: c.longitude))
        #expect(utm.zone == c.zone)
        #expect(utm.band == c.band)
        #expect(abs(utm.easting - c.easting) < 0.01)
        #expect(abs(utm.northing - c.northing) < 0.01)
    }

    @Test(arguments: cases)
    func mgrsMatchesReference(_ c: Case) {
        #expect(CoordinateFormatter.mgrs(latitude: c.latitude, longitude: c.longitude) == c.mgrs)
    }

    @Test func utmLineIsRounded() {
        #expect(CoordinateFormatter.lines(latitude: 37.7749, longitude: -122.4194, format: .utm) == ["10S 551131E 4180999N"])
    }

    @Test func polarRegionsHaveNoUTM() {
        #expect(CoordinateFormatter.utm(latitude: 85, longitude: 10) == nil)
        #expect(CoordinateFormatter.mgrs(latitude: -81, longitude: 10) == nil)
    }

    @Test func decimalDegrees() {
        #expect(CoordinateFormatter.lines(latitude: 37.774930, longitude: -122.419416, format: .decimal)
            == ["37.774930° N", "122.419416° W"])
    }

    @Test func degreesMinutes() {
        #expect(CoordinateFormatter.angle(37.774930, isLatitude: true, format: .degreesMinutes) == "37° 46.496′ N")
        #expect(CoordinateFormatter.angle(-0.5, isLatitude: false, format: .degreesMinutes) == "0° 30.000′ W")
    }

    @Test func degreesMinutesSeconds() {
        #expect(CoordinateFormatter.angle(37.774930, isLatitude: true, format: .degreesMinutesSeconds) == "37° 46′ 29.75″ N")
        #expect(CoordinateFormatter.angle(-33.8688, isLatitude: true, format: .degreesMinutesSeconds) == "33° 52′ 07.68″ S")
    }

    @Test func roundingCarriesIntoTheNextDegree() {
        // 9.99999999° would naively print as 9° 60.000′.
        #expect(CoordinateFormatter.angle(9.99999999, isLatitude: true, format: .degreesMinutes) == "10° 00.000′ N")
        #expect(CoordinateFormatter.angle(9.99999999, isLatitude: true, format: .degreesMinutesSeconds) == "10° 00′ 00.00″ N")
    }

    @Test func norwayAndSvalbardZones() {
        #expect(CoordinateFormatter.utmZone(latitude: 60, longitude: 5.5) == 32)
        #expect(CoordinateFormatter.utmZone(latitude: 78.2, longitude: 15.6) == 33)
        #expect(CoordinateFormatter.utmZone(latitude: 78.2, longitude: 8) == 31)
        #expect(CoordinateFormatter.utmZone(latitude: 50, longitude: 5.5) == 31)
    }
}
