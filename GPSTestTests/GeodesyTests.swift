import Foundation
import Testing
@testable import GPSTest

struct GeodesyTests {
    @Test func londonToParis() {
        // Big Ben to the Eiffel Tower: about 340.5 km on a bearing of about 148.7°.
        let distance = Geodesy.distance(fromLatitude: 51.5007, longitude: -0.1246, toLatitude: 48.8584, longitude: 2.2945)
        #expect(abs(distance - 340_539) < 10)
        let bearing = Geodesy.bearing(fromLatitude: 51.5007, longitude: -0.1246, toLatitude: 48.8584, longitude: 2.2945)
        #expect(abs(bearing - 148.68) < 0.01)
    }

    @Test func cardinalDirectionsAlongTheAxes() {
        #expect(abs(Geodesy.bearing(fromLatitude: 0, longitude: 0, toLatitude: 1, longitude: 0) - 0) < 1e-9)
        #expect(abs(Geodesy.bearing(fromLatitude: 0, longitude: 0, toLatitude: 0, longitude: 1) - 90) < 1e-9)
        #expect(abs(Geodesy.bearing(fromLatitude: 0, longitude: 0, toLatitude: -1, longitude: 0) - 180) < 1e-9)
        #expect(abs(Geodesy.bearing(fromLatitude: 0, longitude: 0, toLatitude: 0, longitude: -1) - 270) < 1e-9)
    }

    @Test func zeroDistanceToItself() {
        #expect(Geodesy.distance(fromLatitude: 10, longitude: 20, toLatitude: 10, longitude: 20) == 0)
    }

    @Test func cardinalNames() {
        #expect(Geodesy.cardinal(0) == "N")
        #expect(Geodesy.cardinal(359) == "N")
        #expect(Geodesy.cardinal(247) == "WSW")
        #expect(Geodesy.cardinal(-90) == "W")
        #expect(Geodesy.cardinal(135) == "SE")
    }

    @Test func normalisesAngles() {
        #expect(Geodesy.normalized(-10) == 350)
        #expect(Geodesy.normalized(720) == 0)
        #expect(Geodesy.normalized(365) == 5)
    }
}
