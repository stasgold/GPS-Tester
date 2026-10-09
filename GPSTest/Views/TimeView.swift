import SwiftUI

/// Clocks plus sun and moon times for the current position, like GPS Test's Time screen.
struct TimeView: View {
    @Environment(LocationService.self) private var location
    @AppStorage(SettingsKey.units) private var units = UnitSystem.metric

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                List {
                    clockSection(now: context.date)
                    if let fix = location.location {
                        let lat = fix.coordinate.latitude
                        let lon = fix.coordinate.longitude
                        sunSection(now: context.date, latitude: lat, longitude: lon)
                        moonSection(now: context.date, latitude: lat, longitude: lon)
                    } else {
                        Section {
                            Text("Sun and moon times appear once there is a fix.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Time")
            .settingsToolbar()
        }
    }

    private func clockSection(now: Date) -> some View {
        Section("Clock") {
            LabeledContent("Local", value: Format.time(now, seconds: true))
            LabeledContent("UTC", value: Format.time(now, in: .gmt, seconds: true))
            LabeledContent("Time zone", value: TimeZone.current.localizedName(for: .shortGeneric, locale: .current)
                ?? TimeZone.current.identifier)
            LabeledContent("Date", value: now.formatted(date: .complete, time: .omitted))
            if let fix = location.location {
                LabeledContent("Last fix", value: Format.time(fix.timestamp, seconds: true))
            }
        }
    }

    private func sunSection(now: Date, latitude: Double, longitude: Double) -> some View {
        let times = Astronomy.sunTimes(on: localNoon(now), latitude: latitude, longitude: longitude)
        let position = Astronomy.sunPosition(at: now, latitude: latitude, longitude: longitude)
        return Section {
            row("Sunrise", times.sunrise, symbol: "sunrise")
            row("Sunset", times.sunset, symbol: "sunset")
            row("Solar noon", times.solarNoon, symbol: "sun.max")
            LabeledContent("Day length", value: dayLength(times, latitude: latitude, longitude: longitude))
            row("Civil dawn", times.civilDawn)
            row("Civil dusk", times.civilDusk)
            row("Nautical dawn", times.nauticalDawn)
            row("Nautical dusk", times.nauticalDusk)
            row("Astronomical dawn", times.astronomicalDawn)
            row("Astronomical dusk", times.astronomicalDusk)
            row("Golden hour starts", times.goldenHour)
            LabeledContent("Elevation", value: String(format: "%.1f°", position.altitude))
            LabeledContent("Azimuth", value: Format.bearing(position.azimuth))
        } header: {
            Label("Sun", systemImage: "sun.max.fill")
        }
    }

    private func moonSection(now: Date, latitude: Double, longitude: Double) -> some View {
        let illumination = Astronomy.moonIllumination(at: now)
        let times = Astronomy.moonTimes(on: now, latitude: latitude, longitude: longitude)
        let position = Astronomy.moonPosition(at: now, latitude: latitude, longitude: longitude)
        return Section {
            LabeledContent("Phase") {
                Label(illumination.phaseName, systemImage: illumination.symbolName)
            }
            LabeledContent("Illumination", value: String(format: "%.0f%%", illumination.fraction * 100))
            LabeledContent("Age", value: String(format: "%.1f days", illumination.age))
            if times.alwaysUp {
                LabeledContent("Moonrise / moonset", value: "Up all day")
            } else if times.alwaysDown {
                LabeledContent("Moonrise / moonset", value: "Down all day")
            } else {
                row("Moonrise", times.rise, symbol: "moonrise")
                row("Moonset", times.set, symbol: "moonset")
            }
            LabeledContent("Elevation", value: String(format: "%.1f°", position.position.altitude))
            LabeledContent("Azimuth", value: Format.bearing(position.position.azimuth))
            LabeledContent("Distance", value: units.distance(position.distance * 1000))
        } header: {
            Label("Moon", systemImage: "moon.fill")
        }
    }

    private func row(_ title: String, _ date: Date?, symbol: String? = nil) -> some View {
        LabeledContent {
            Text(Format.time(date)).monospacedDigit()
        } label: {
            if let symbol {
                Label(title, systemImage: symbol)
            } else {
                Text(title)
            }
        }
    }

    private func dayLength(_ times: Astronomy.SunTimes, latitude: Double, longitude: Double) -> String {
        if let length = times.dayLength {
            return String(format: "%d h %02d min", Int(length) / 3600, Int(length) % 3600 / 60)
        }
        // No sunrise: midnight sun if the sun is up at noon, polar night otherwise.
        let noon = Astronomy.sunPosition(at: times.solarNoon, latitude: latitude, longitude: longitude)
        return noon.altitude > 0 ? "24 h (midnight sun)" : "0 h (polar night)"
    }

    private func localNoon(_ date: Date) -> Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }
}
