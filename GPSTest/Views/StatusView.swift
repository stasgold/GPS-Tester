import Charts
import CoreLocation
import SwiftUI

/// GPS Test's main data screen: fix state, position, altitude, accuracy, motion and timing.
struct StatusView: View {
    @Environment(LocationService.self) private var location
    @AppStorage(SettingsKey.coordinateFormat) private var format = CoordinateFormat.decimal
    @AppStorage(SettingsKey.units) private var units = UnitSystem.metric
    @AppStorage(SettingsKey.trueNorth) private var trueNorth = true

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                List {
                    if !location.isAuthorized || !location.isPrecise || location.errorMessage != nil {
                        Section { LocationAccessBanner() }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    fixSection(now: context.date)
                    positionSection
                    accuracySection
                    altitudeSection
                    motionSection
                    sourceSection
                }
            }
            .navigationTitle("GPS Test")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Restart", systemImage: "arrow.clockwise") { location.restart() }
                        .disabled(!location.isAuthorized)
                }
                if let fix = location.location {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: shareText(fix)) { Label("Share", systemImage: "square.and.arrow.up") }
                    }
                }
            }
            .settingsToolbar()
        }
    }

    // MARK: Sections

    private func fixSection(now: Date) -> some View {
        Section("Fix") {
            LabeledContent("Status") { FixBadge(status: location.fixStatus(at: now)) }
            LabeledContent("Time to first fix",
                           value: location.timeToFirstFix.map(Format.duration) ?? (location.isRunning ? "Waiting…" : "—"))
            LabeledContent("Fix age", value: location.location.map { Format.duration(max(0, now.timeIntervalSince($0.timestamp))) } ?? "—")
            LabeledContent("Fix time (UTC)", value: Format.time(location.location?.timestamp, in: .gmt, seconds: true))
            LabeledContent("Updates") {
                if let rate = location.updateRate {
                    Text("\(location.updateCount) · \(String(format: "%.1f", rate)) Hz")
                } else {
                    Text("\(location.updateCount)")
                }
            }
        }
    }

    @ViewBuilder
    private var positionSection: some View {
        Section("Position") {
            if let fix = location.location {
                let lat = fix.coordinate.latitude
                let lon = fix.coordinate.longitude
                let lines = CoordinateFormatter.lines(latitude: lat, longitude: lon, format: format)
                let labels = lines.count == 2 ? ["Latitude", "Longitude"] : [format.title]
                ForEach(lines.indices, id: \.self) { index in
                    LabeledContent(labels[index]) {
                        Text(lines[index]).monospacedDigit().textSelection(.enabled)
                    }
                }
                .contextMenu {
                    Button("Copy Coordinates", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = CoordinateFormatter.singleLine(latitude: lat, longitude: lon, format: format)
                    }
                    Button("Copy as Decimal", systemImage: "number") {
                        UIPasteboard.general.string = String(format: "%.6f, %.6f", lat, lon)
                    }
                }
                if format != .mgrs, let mgrs = CoordinateFormatter.mgrs(latitude: lat, longitude: lon) {
                    LabeledContent("MGRS") { Text(mgrs).monospacedDigit() }
                }
            } else {
                Text(location.isRunning ? "Waiting for a fix…" : "Location updates are off")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accuracySection: some View {
        Section {
            LabeledContent("Horizontal", value: accuracy(location.location?.horizontalAccuracy))
            LabeledContent("Vertical", value: accuracy(location.location?.verticalAccuracy))
            if location.history.count > 1 {
                AccuracyChart(samples: location.history, units: units)
                    .frame(height: 160)
                    .padding(.vertical, 4)
            }
        } header: {
            Text("Accuracy")
        } footer: {
            Text("iOS does not let apps see individual satellites or their signal strength, so GPS Test shows the receiver's own accuracy estimate (68% confidence radius) instead of the satellite signal bars.")
        }
    }

    private var altitudeSection: some View {
        Section("Altitude") {
            let fix = location.location
            let hasAltitude = (fix?.verticalAccuracy ?? -1) > 0
            LabeledContent("Above sea level", value: hasAltitude ? units.length(fix!.altitude) : "—")
            LabeledContent("Above ellipsoid (WGS 84)", value: hasAltitude ? units.length(fix!.ellipsoidalAltitude) : "—")
            if hasAltitude, let fix {
                LabeledContent("Geoid separation", value: units.length(fix.ellipsoidalAltitude - fix.altitude))
            }
            if let floor = fix?.floor {
                LabeledContent("Floor", value: "\(floor.level)")
            }
        }
    }

    private var motionSection: some View {
        Section("Motion") {
            let fix = location.location
            LabeledContent("Speed", value: (fix?.speed ?? -1) >= 0 ? units.speed(fix!.speed) : "—")
            LabeledContent("Speed accuracy", value: (fix?.speedAccuracy ?? -1) >= 0 ? "±" + units.speed(fix!.speedAccuracy) : "—")
            LabeledContent("Course", value: (fix?.course ?? -1) >= 0 ? Format.bearing(fix!.course) : "—")
            LabeledContent("Course accuracy", value: (fix?.courseAccuracy ?? -1) >= 0 ? String(format: "±%.0f°", fix!.courseAccuracy) : "—")
            LabeledContent("Heading (\(headingReference))", value: headingText)
        }
    }

    private var sourceSection: some View {
        Section("Source") {
            LabeledContent("Precise location", value: location.isPrecise ? "On" : "Off")
            if let info = location.location?.sourceInformation {
                LabeledContent("External accessory", value: info.isProducedByAccessory ? "Yes" : "No")
                LabeledContent("Simulated", value: info.isSimulatedBySoftware ? "Yes" : "No")
            }
            LabeledContent("Compass", value: location.headingAvailable ? "Available" : "Not available")
        }
    }

    // MARK: Helpers

    private var headingReference: String {
        trueNorth && (location.heading?.trueHeading ?? -1) >= 0 ? "true" : "magnetic"
    }

    private var headingText: String {
        guard let heading = location.heading, heading.headingAccuracy >= 0 else { return "—" }
        let value = trueNorth && heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        return Format.bearing(value) + String(format: " ±%.0f°", heading.headingAccuracy)
    }

    private func accuracy(_ metres: Double?) -> String {
        guard let metres, metres > 0 else { return "—" }
        return "±" + units.length(metres)
    }

    private func shareText(_ fix: CLLocation) -> String {
        ShareText.position(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                           altitude: fix.verticalAccuracy > 0 ? fix.altitude : nil,
                           accuracy: fix.horizontalAccuracy, format: format, units: units)
    }
}

/// Horizontal and vertical accuracy over the last two minutes.
struct AccuracyChart: View {
    var samples: [AccuracySample]
    var units: UnitSystem

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(x: .value("Time", sample.date), y: .value("Accuracy", scaled(sample.horizontal)),
                         series: .value("Kind", "Horizontal"))
                    .foregroundStyle(by: .value("Kind", "Horizontal"))
                if let vertical = sample.vertical {
                    LineMark(x: .value("Time", sample.date), y: .value("Accuracy", scaled(vertical)),
                             series: .value("Kind", "Vertical"))
                        .foregroundStyle(by: .value("Kind", "Vertical"))
                }
            }
        }
        .chartForegroundStyleScale(["Horizontal": Color.green, "Vertical": Color.blue])
        .chartYAxisLabel(units == .imperial ? "ft" : "m")
        .accessibilityLabel("Accuracy over the last two minutes")
    }

    private func scaled(_ metres: Double) -> Double {
        units == .imperial ? metres * 3.280_84 : metres
    }
}
