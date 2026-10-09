import CoreLocation
import SwiftUI

/// A rotating compass card with the course to the target waypoint and the sun and moon bearings.
struct CompassView: View {
    @Environment(LocationService.self) private var location
    @Environment(WaypointStore.self) private var waypoints
    @AppStorage(SettingsKey.trueNorth) private var trueNorth = true
    @AppStorage(SettingsKey.units) private var units = UnitSystem.metric

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    readout
                    CompassDial(heading: heading ?? 0,
                                target: targetBearing,
                                course: course,
                                sun: celestial.sun,
                                moon: celestial.moon)
                        .frame(maxWidth: 420)
                        .aspectRatio(1, contentMode: .fit)
                        .padding(.horizontal)
                    if let target = waypoints.target {
                        targetCard(target)
                    }
                    details
                }
                .padding(.vertical)
            }
            .navigationTitle("Compass")
            .navigationBarTitleDisplayMode(.inline)
            .settingsToolbar()
        }
    }

    // MARK: Values

    /// Device heading, or GPS course when there is no magnetometer (or it is uncalibrated).
    private var heading: Double? {
        if let h = location.heading, h.headingAccuracy >= 0 {
            return trueNorth && h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        }
        if let course = course { return course }
        return nil
    }

    private var usesTrueNorth: Bool {
        guard let h = location.heading, h.headingAccuracy >= 0 else { return true } // GPS course is true
        return trueNorth && h.trueHeading >= 0
    }

    private var course: Double? {
        guard let fix = location.location, fix.course >= 0, fix.speed > 0.5 else { return nil }
        return fix.course
    }

    /// Bearing to the target, converted to the dial's north reference.
    private var targetBearing: Double? {
        guard let fix = location.location, let target = waypoints.target else { return nil }
        let bearing = Geodesy.bearing(fromLatitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                      toLatitude: target.latitude, longitude: target.longitude)
        return toDialReference(bearing)
    }

    private var celestial: (sun: Astronomy.Position?, moon: Astronomy.Position?) {
        guard let fix = location.location else { return (nil, nil) }
        let now = Date()
        var sun = Astronomy.sunPosition(at: now, latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
        var moon = Astronomy.moonPosition(at: now, latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude).position
        sun.azimuth = toDialReference(sun.azimuth)
        moon.azimuth = toDialReference(moon.azimuth)
        return (sun, moon)
    }

    /// True bearings are shifted by the local declination when the dial shows magnetic north.
    private func toDialReference(_ trueBearing: Double) -> Double {
        guard !usesTrueNorth, let h = location.heading, h.trueHeading >= 0 else { return trueBearing }
        let declination = h.trueHeading - h.magneticHeading
        return Geodesy.normalized(trueBearing - declination)
    }

    // MARK: Pieces

    private var readout: some View {
        VStack(spacing: 4) {
            if let heading {
                Text(Format.bearing(heading))
                    .font(.system(size: 48, weight: .semibold, design: .rounded).monospacedDigit())
                Text(source)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("—").font(.system(size: 48, weight: .semibold, design: .rounded))
                Text(location.headingAvailable ? "Calibrating compass…" : "No compass: move to see your GPS course")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var source: String {
        if let h = location.heading, h.headingAccuracy >= 0 {
            return (usesTrueNorth ? "True north" : "Magnetic north") + String(format: " · ±%.0f°", h.headingAccuracy)
        }
        return "GPS course (true north)"
    }

    private func targetCard(_ target: Waypoint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(target.name, systemImage: "scope").font(.headline).foregroundStyle(.red)
            if let fix = location.location {
                let distance = Geodesy.distance(fromLatitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                                toLatitude: target.latitude, longitude: target.longitude)
                let bearing = Geodesy.bearing(fromLatitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                              toLatitude: target.latitude, longitude: target.longitude)
                LabeledContent("Distance", value: units.distance(distance))
                LabeledContent("Bearing (true)", value: Format.bearing(bearing))
                if fix.speed > 0.5 {
                    LabeledContent("Time at current speed", value: Format.duration(distance / fix.speed))
                }
            } else {
                Text("Waiting for a fix…").foregroundStyle(.secondary)
            }
            Button("Stop Navigating", role: .destructive) { waypoints.targetID = nil }
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var details: some View {
        VStack(spacing: 8) {
            if let h = location.heading, h.headingAccuracy >= 0 {
                LabeledContent("Magnetic heading", value: Format.bearing(h.magneticHeading))
                if h.trueHeading >= 0 {
                    LabeledContent("True heading", value: Format.bearing(h.trueHeading))
                    LabeledContent("Declination", value: String(format: "%.1f°", h.trueHeading - h.magneticHeading))
                }
                LabeledContent("Field strength", value: String(format: "%.0f µT", fieldStrength(h)))
                if h.headingAccuracy > 20 {
                    Label("Low accuracy: move the phone in a figure-eight to calibrate.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            if let course {
                LabeledContent("GPS course", value: Format.bearing(course))
            }
            HStack(spacing: 16) {
                legend("Target", color: .red)
                legend("Course", color: .blue)
                legend("Sun", color: .yellow)
                legend("Moon", color: .gray)
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }

    private func fieldStrength(_ h: CLHeading) -> Double {
        sqrt(h.x * h.x + h.y * h.y + h.z * h.z)
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).foregroundStyle(.secondary)
        }
    }
}

/// The compass card. Everything is placed relative to `heading`, so the card turns as the phone does.
struct CompassDial: View {
    var heading: Double
    var target: Double?
    var course: Double?
    var sun: Astronomy.Position?
    var moon: Astronomy.Position?

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack {
                Circle().fill(.background.secondary)
                Canvas { context, _ in
                    for tick in stride(from: 0, to: 360, by: 5) {
                        let major = tick % 30 == 0
                        let length: CGFloat = major ? 16 : (tick % 10 == 0 ? 10 : 6)
                        var path = Path()
                        path.move(to: point(center, radius - 4, Double(tick)))
                        path.addLine(to: point(center, radius - 4 - length, Double(tick)))
                        let color: Color = tick == 0 ? .red : .primary.opacity(major ? 0.9 : 0.5)
                        context.stroke(path, with: .color(color), lineWidth: major ? 2.5 : 1)
                    }
                }
                ForEach(Array(stride(from: 0, to: 360, by: 30)), id: \.self) { degrees in
                    Text(label(degrees))
                        .font(degrees % 90 == 0 ? .title2.weight(.bold) : .caption.monospacedDigit())
                        .foregroundStyle(degrees == 0 ? .red : .primary)
                        .position(point(center, radius - 40, Double(degrees)))
                }
                if let course {
                    marker(Image(systemName: "location.north.fill"), color: .blue, center: center, r: radius - 66, bearing: course)
                }
                if let sun {
                    marker(Image(systemName: sun.altitude > 0 ? "sun.max.fill" : "sun.horizon"), color: .yellow,
                           center: center, r: radius - 66, bearing: sun.azimuth, dimmed: sun.altitude <= 0)
                }
                if let moon {
                    marker(Image(systemName: "moon.fill"), color: .gray, center: center, r: radius - 66,
                           bearing: moon.azimuth, dimmed: moon.altitude <= 0)
                }
                if let target {
                    Image(systemName: "arrow.up")
                        .font(.system(size: size * 0.28, weight: .bold))
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(target - heading))
                        .position(center)
                        .accessibilityLabel("Target bearing")
                }
                // Lubber line: the direction the top of the phone points.
                Triangle()
                    .fill(.tint)
                    .frame(width: 18, height: 14)
                    .position(x: center.x, y: center.y - radius - 10)
                Circle().fill(.tint).frame(width: 8, height: 8).position(center)
            }
        }
        .padding(.top, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Compass")
        .accessibilityValue(Format.bearing(heading))
    }

    private func label(_ degrees: Int) -> String {
        switch degrees {
        case 0: "N"
        case 90: "E"
        case 180: "S"
        case 270: "W"
        default: "\(degrees)"
        }
    }

    /// Screen point at `r` from the centre for a bearing, with the card turned by the heading.
    private func point(_ center: CGPoint, _ r: CGFloat, _ bearing: Double) -> CGPoint {
        let theta = (bearing - heading) * .pi / 180
        return CGPoint(x: center.x + r * CGFloat(sin(theta)), y: center.y - r * CGFloat(cos(theta)))
    }

    private func marker(_ image: Image, color: Color, center: CGPoint, r: CGFloat, bearing: Double, dimmed: Bool = false) -> some View {
        image
            .font(.title3)
            .foregroundStyle(color)
            .opacity(dimmed ? 0.35 : 1)
            .position(point(center, r, bearing))
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
