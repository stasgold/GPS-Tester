import Foundation
import Testing
@testable import GPSTest

struct SignalQualityTests {
    @Test func levelsFollowAccuracy() {
        #expect(SignalQuality(accuracy: 2) == .excellent)
        #expect(SignalQuality(accuracy: 3) == .excellent)
        #expect(SignalQuality(accuracy: 4) == .good)
        #expect(SignalQuality(accuracy: 8) == .moderate)
        #expect(SignalQuality(accuracy: 15) == .fair)
        #expect(SignalQuality(accuracy: 65) == .poor)
    }

    @Test func positionIsLogarithmicAndClamped() {
        #expect(SignalQuality.position(accuracy: 1) == 1)
        #expect(SignalQuality.position(accuracy: 0.5) == 1)
        #expect(SignalQuality.position(accuracy: 50) == 0)
        #expect(SignalQuality.position(accuracy: 500) == 0)
        #expect(SignalQuality.position(accuracy: 0) == 0)
        #expect(abs(SignalQuality.position(accuracy: sqrt(50)) - 0.5) < 1e-9)
        #expect(SignalQuality.position(accuracy: 5) > SignalQuality.position(accuracy: 10))
    }

    @Test func averageUsesTheLastThirtySeconds() {
        let now = Date()
        let samples = [
            AccuracySample(date: now.addingTimeInterval(-60), horizontal: 100, vertical: nil),
            AccuracySample(date: now.addingTimeInterval(-20), horizontal: 6, vertical: nil),
            AccuracySample(date: now, horizontal: 4, vertical: nil),
        ]
        #expect(samples.averageAccuracy() == 5)
        #expect([AccuracySample]().averageAccuracy() == nil)
    }

    @Test func gaugeUnits() {
        #expect(abs(UnitSystem.metric.speedValue(10) - 36) < 1e-9)
        #expect(UnitSystem.imperial.speedUnit == "mph")
        #expect(UnitSystem.nautical.speedometerScale.max == 100)
        #expect(abs(UnitSystem.imperial.altitudeValue(100) - 328.084) < 1e-9)
        #expect(UnitSystem.metric.altitudeUnit == "meters")
    }

    @Test func dayDialPutsMidnightAtTheBottom() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let midnight = Date(timeIntervalSince1970: 1_700_006_400) // 2023-11-15T00:00:00Z
        #expect(DayDial.angle(midnight, calendar: calendar) == 180)
        #expect(DayDial.angle(midnight.addingTimeInterval(12 * 3600), calendar: calendar) == 360)
        #expect(DayDial.angle(midnight.addingTimeInterval(6 * 3600), calendar: calendar) == 270)
    }

    @Test func segmentWidths() {
        #expect(SegmentText.aspectRatio(of: "12:34:56") > SegmentText.aspectRatio(of: "12:34"))
        #expect(SegmentText.aspectRatio(of: "") > 0)
    }
}
