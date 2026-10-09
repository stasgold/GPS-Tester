import SwiftUI

/// Speedometer on top, compass and altimeter below (side by side in landscape).
struct DashboardScreen: View {
    @Environment(LocationService.self) private var location
    @AppStorage(SettingsKey.units) private var units = UnitSystem.metric
    @AppStorage(SettingsKey.trueNorth) private var trueNorth = true

    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            let layout = landscape ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 12))
            let small = landscape ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                speedometer
                small {
                    CompassGauge(heading: heading, isTrueNorth: usesTrueNorth)
                    Altimeter(altitude: altitude, unit: units.altitudeUnit)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var speedometer: some View {
        let scale = units.speedometerScale
        return Speedometer(speed: speed, maxValue: scale.max, step: scale.step, unit: units.speedUnit)
    }

    private var speed: Double? {
        guard let fix = location.location, fix.speed >= 0 else { return nil }
        return units.speedValue(fix.speed)
    }

    private var altitude: Double? {
        guard let fix = location.location, fix.verticalAccuracy > 0 else { return nil }
        return units.altitudeValue(fix.altitude)
    }

    /// Magnetometer heading when calibrated, else the GPS course while moving.
    private var heading: Double? {
        if let h = location.heading, h.headingAccuracy >= 0 {
            return trueNorth && h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        }
        if let fix = location.location, fix.course >= 0, fix.speed > 0.5 { return fix.course }
        return nil
    }

    private var usesTrueNorth: Bool {
        guard let h = location.heading, h.headingAccuracy >= 0 else { return true }
        return trueNorth && h.trueHeading >= 0
    }
}
