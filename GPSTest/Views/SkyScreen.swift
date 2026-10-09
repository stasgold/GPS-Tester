import SwiftUI

/// A sky plot like a receiver's satellite view, turned with the phone, showing what iOS can place on
/// it: the sun, the moon, the target waypoint and the direction of travel.
struct SkyScreen: View {
    @Environment(LocationService.self) private var location
    @Environment(WaypointStore.self) private var waypoints
    @AppStorage(SettingsKey.trueNorth) private var trueNorth = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let sky = bodies(at: context.date)
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    stat("Sun", sky.sun.map { String(format: "%.0f°", $0.altitude) } ?? "--", alignment: .leading)
                    Spacer()
                    stat("Moon", sky.moon.map { String(format: "%.0f°", $0.altitude) } ?? "--", alignment: .trailing)
                }
                SkyPlot(rotation: rotation, objects: sky.objects)
                    .frame(maxHeight: .infinity)
                HStack(alignment: .bottom) {
                    stat(declinationText, "Declination (° \(declinationSide))", alignment: .leading, valueFirst: true)
                    Spacer()
                    stat(firstFixText, "First Fix Time", alignment: .trailing, valueFirst: true)
                }
                QualityBar(accuracy: location.history.averageAccuracy())
            }
        }
    }

    // MARK: Data

    private struct Sky {
        var sun: Astronomy.Position?
        var moon: Astronomy.Position?
        var objects: [SkyPlot.Object] = []
    }

    private func bodies(at date: Date) -> Sky {
        guard let fix = location.location else { return Sky() }
        let lat = fix.coordinate.latitude
        let lon = fix.coordinate.longitude
        let sun = Astronomy.sunPosition(at: date, latitude: lat, longitude: lon)
        let moon = Astronomy.moonPosition(at: date, latitude: lat, longitude: lon).position
        var objects = [
            SkyPlot.Object(label: "Sun", symbol: "sun.max.fill", color: .yellow, azimuth: sun.azimuth, elevation: sun.altitude),
            SkyPlot.Object(label: "Moon", symbol: "moon.fill", color: Color(white: 0.85), azimuth: moon.azimuth,
                           elevation: moon.altitude),
        ]
        if let target = waypoints.target {
            let bearing = Geodesy.bearing(fromLatitude: lat, longitude: lon, toLatitude: target.latitude, longitude: target.longitude)
            objects.append(SkyPlot.Object(label: target.name, symbol: "scope", color: .red, azimuth: bearing, elevation: 0))
        }
        if fix.course >= 0, fix.speed > 0.5 {
            objects.append(SkyPlot.Object(label: "Course", symbol: "location.north.fill", color: Palette.accent,
                                          azimuth: fix.course, elevation: 0))
        }
        return Sky(sun: sun, moon: moon, objects: objects)
    }

    /// The plot turns so the direction the phone points is at the top (true north reference).
    private var rotation: Double {
        if let h = location.heading, h.headingAccuracy >= 0 {
            return h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        }
        if let fix = location.location, fix.course >= 0, fix.speed > 0.5 { return fix.course }
        return 0
    }

    private var declination: Double? {
        guard let h = location.heading, h.headingAccuracy >= 0, h.trueHeading >= 0 else { return nil }
        var value = h.trueHeading - h.magneticHeading
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }

    private var declinationText: String {
        declination.map { String(format: "%.2f", abs($0)) } ?? "--"
    }

    private var declinationSide: String { (declination ?? 0) < 0 ? "W" : "E" }

    private var firstFixText: String {
        guard let seconds = location.timeToFirstFix else { return "--:--" }
        let whole = Int(seconds.rounded())
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

    private func stat(_ first: String, _ second: String, alignment: HorizontalAlignment, valueFirst: Bool = false) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            if valueFirst {
                Text(first).font(.system(size: 40).monospacedDigit())
                Text(second).font(.headline.weight(.regular))
            } else {
                Text(first).font(.headline.weight(.regular))
                Text(second).font(.system(size: 40).monospacedDigit())
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

/// Polar plot: horizon at the rim, zenith in the middle, rings at 30° and 60° elevation.
struct SkyPlot: View {
    struct Object: Identifiable {
        var id: String { label }
        var label: String
        var symbol: String
        var color: Color
        var azimuth: Double
        var elevation: Double
    }

    /// Bearing shown at the top of the plot.
    var rotation: Double
    var objects: [Object]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let r = side / 2 * 0.98
            ZStack {
                Canvas { context, _ in
                    let disc = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                    context.fill(disc, with: .color(Palette.panel))
                    context.stroke(disc, with: .color(.white), lineWidth: 2)
                    let dashed = StrokeStyle(lineWidth: 1, dash: [3, 4])
                    for ring in [0.92, 0.62, 0.31, 0.1] {
                        let rr = r * ring
                        context.stroke(Path(ellipseIn: CGRect(x: center.x - rr, y: center.y - rr, width: rr * 2, height: rr * 2)),
                                       with: .color(.white.opacity(0.6)), style: dashed)
                    }
                    for bearing in stride(from: 0.0, to: 360, by: 30) {
                        var spoke = Path()
                        spoke.move(to: dialPoint(center, r * 0.1, bearing - rotation))
                        spoke.addLine(to: dialPoint(center, r * 0.92, bearing - rotation))
                        context.stroke(spoke, with: .color(.white.opacity(0.6)), style: dashed)
                    }
                    for bearing in stride(from: 0, to: 360, by: 15) {
                        let label = [0: "N", 90: "E", 180: "S", 270: "W"][bearing] ?? "\(bearing)"
                        let cardinal = bearing % 90 == 0
                        context.draw(Text(label)
                                        .font(.system(size: r * (cardinal ? 0.08 : 0.05), weight: cardinal ? .bold : .regular))
                                        .foregroundColor(cardinal && bearing == 0 ? .red : .white),
                                     at: dialPoint(center, r * 0.96, Double(bearing) - rotation))
                    }
                }
                ForEach(objects) { object in
                    let below = object.elevation < 0
                    let distance = r * 0.92 * CGFloat(1 - max(object.elevation, 0) / 90)
                    let point = dialPoint(center, distance, object.azimuth - rotation)
                    VStack(spacing: 2) {
                        Image(systemName: object.symbol)
                            .font(.system(size: r * 0.1))
                            .foregroundStyle(object.color)
                            .rotationEffect(.degrees(object.symbol == "location.north.fill" ? object.azimuth - rotation : 0))
                        Text(object.label)
                            .font(.system(size: r * 0.055, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white, lineWidth: 1))
                    }
                    .opacity(below ? 0.35 : 1)
                    .position(x: point.x, y: point.y + r * 0.04)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sky plot")
        .accessibilityValue(objects.map { "\($0.label) \(Format.bearing($0.azimuth)), \(Int($0.elevation))° up" }
            .joined(separator: "; "))
    }
}
