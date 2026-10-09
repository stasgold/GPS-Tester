import Foundation
import Testing
@testable import GPSTest

struct UnitsTests {
    @Test func lengths() {
        #expect(UnitSystem.metric.length(4.26) == "4.3 m")
        #expect(UnitSystem.metric.length(152.4) == "152 m")
        #expect(UnitSystem.imperial.length(100) == "328 ft")
        #expect(UnitSystem.nautical.length(12) == "12 m")
    }

    @Test func distances() {
        #expect(UnitSystem.metric.distance(950) == "950 m")
        #expect(UnitSystem.metric.distance(1_500) == "1.50 km")
        #expect(UnitSystem.metric.distance(341_600) == "341.6 km")
        #expect(UnitSystem.imperial.distance(100) == "328 ft")
        #expect(UnitSystem.imperial.distance(1_609.344) == "1.00 mi")
        #expect(UnitSystem.nautical.distance(1_852) == "1.00 nmi")
        #expect(UnitSystem.nautical.distance(500) == "500 m")
    }

    @Test func speeds() {
        #expect(UnitSystem.metric.speed(10) == "36.0 km/h")
        #expect(UnitSystem.imperial.speed(10) == "22.4 mph")
        #expect(UnitSystem.nautical.speed(10) == "19.4 kn")
    }

    @Test func noThousandsSeparator() {
        #expect(UnitSystem.imperial.length(1_000) == "3281 ft")
    }
}
