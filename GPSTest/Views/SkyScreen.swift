import SwiftUI

/// A receiver-style sky plot, turned with the phone. iOS hides the satellites the phone actually tracks,
/// so the satellites shown are the ones predicted above the horizon from published orbits; the sun,
/// the moon, the target waypoint and the direction of travel are plotted too.
struct SkyScreen: View {
    @Environment(LocationService.self) private var location
    @Environment(WaypointStore.self) private var waypoints
    @Environment(SatelliteCatalog.self) private var catalog

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let sky = bodies(at: context.date)
            let visible = sky.satellites.filter { $0.elevation > 0 }
            VStack(spacing: 8) {
                HStack(alignment: .top) {
                    stat("In View", visible.isEmpty && catalog.elements.isEmpty ? "--" : "\(visible.count)", alignment: .leading)
                    Spacer()
                    stat("Above 15°", visible.isEmpty && catalog.elements.isEmpty ? "--" : "\(visible.filter { $0.elevation >= 15 }.count)",
                         alignment: .trailing)
                }
                SkyPlot(rotation: rotation, objects: sky.objects, satellites: visible)
                    .frame(maxHeight: .infinity)
                ConstellationLegend(satellites: visible)
                status
                HStack(alignment: .bottom) {
                    stat(declinationText, "Declination (° \(declinationSide))", alignment: .leading, valueFirst: true)
                    Spacer()
                    stat(firstFixText, "First Fix Time", alignment: .trailing, valueFirst: true)
                }
            }
        }
        .task { await catalog.refresh() }
    }

    @ViewBuilder
    private var status: some View {
        Group {
            if catalog.isLoading && catalog.elements.isEmpty {
                Text("Downloading satellite orbits…")
            } else if let error = catalog.errorMessage {
                HStack {
                    Text(error).lineLimit(2)
                    Button("Retry") { Task { await catalog.refresh(force: true) } }
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
            } else if location.location == nil {
                Text("Waiting for a fix to place the satellites.")
            } else if catalog.isStale {
                Text("Satellite orbits are out of date. Connect to the internet to update them.")
            } else {
                Text("Predicted from published orbits\(updatedText). iOS doesn't say which ones the phone is using.")
            }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.75))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var updatedText: String {
        guard let downloadedAt = catalog.downloadedAt else { return "" }
        let hours = Int(Date().timeIntervalSince(downloadedAt) / 3600)
        return hours < 1 ? ", updated just now" : ", updated \(hours) h ago"
    }

    // MARK: Data

    private struct Sky {
        var objects: [SkyPlot.Object] = []
        var satellites: [SatellitePosition] = []
    }

    private func bodies(at date: Date) -> Sky {
        guard let fix = location.location else { return Sky() }
        let lat = fix.coordinate.latitude
        let lon = fix.coordinate.longitude
        let sun = Astronomy.sunPosition(at: date, latitude: lat, longitude: lon)
        let moon = Astronomy.moonPosition(at: date, latitude: lat, longitude: lon).position
        // When the sun and moon are close, put the moon's label above it so the two don't overlap.
        let separation = Geodesy.distance(fromLatitude: sun.altitude, longitude: sun.azimuth,
                                          toLatitude: moon.altitude, longitude: moon.azimuth) / Geodesy.earthRadius * 180 / .pi
        let close = separation < 20
        var objects = [
            SkyPlot.Object(label: "Sun", symbol: "sun.max.fill", color: .yellow, azimuth: sun.azimuth, elevation: sun.altitude),
            SkyPlot.Object(label: "Moon", symbol: "moon.fill", color: Color(white: 0.85), azimuth: moon.azimuth,
                           elevation: moon.altitude, labelAbove: close),
        ]
        if let target = waypoints.target {
            let bearing = Geodesy.bearing(fromLatitude: lat, longitude: lon, toLatitude: target.latitude, longitude: target.longitude)
            objects.append(SkyPlot.Object(label: target.name, symbol: "scope", color: .red, azimuth: bearing, elevation: 0))
        }
        if fix.course >= 0, fix.speed > 0.5 {
            objects.append(SkyPlot.Object(label: "Course", symbol: "location.north.fill", color: Palette.accent,
                                          azimuth: fix.course, elevation: 0))
        }
        let altitude = fix.verticalAccuracy > 0 ? fix.altitude : 0
        let satellites = catalog.positions(at: date, latitude: lat, longitude: lon, altitude: altitude)
        return Sky(objects: objects, satellites: satellites)
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
        guard let seconds = location.timeToFirstFix else { return location.isRunning ? "…" : "--" }
        if seconds < 100 { return String(format: "%.1f s", seconds) }
        let whole = Int(seconds.rounded())
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

    private func stat(_ first: String, _ second: String, alignment: HorizontalAlignment, valueFirst: Bool = false) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            if valueFirst {
                Text(first).font(.system(size: 34).monospacedDigit())
                Text(second).font(.subheadline)
            } else {
                Text(first).font(.headline.weight(.regular))
                Text(second).font(.system(size: 34).monospacedDigit())
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

extension Constellation {
    var color: Color {
        switch self {
        case .gps: Color(red: 0.3, green: 0.85, blue: 0.35)
        case .glonass: Color(red: 1, green: 0.3, blue: 0.3)
        case .galileo: Color(red: 0.35, green: 0.6, blue: 1)
        case .beidou: .orange
        case .qzss: Color(red: 0.75, green: 0.45, blue: 1)
        case .navic: .pink
        case .other: .gray
        }
    }

    /// Marker outline in a unit square, one shape per system as on Android receivers.
    func markerPath(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        func polygon(_ count: Int, inner: CGFloat? = nil, rotation: Double = 0) -> Path {
            var path = Path()
            let points = inner == nil ? count : count * 2
            for k in 0..<points {
                let radius = inner != nil && k % 2 == 1 ? r * inner! : r
                let angle = rotation + Double(k) * 360 / Double(points)
                let p = dialPoint(c, radius, angle)
                if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            return path
        }
        switch self {
        case .gps: return Path(ellipseIn: rect.insetBy(dx: rect.width / 2 - r, dy: rect.height / 2 - r))
        case .glonass: return polygon(4, inner: 0.4)
        case .galileo: return polygon(3)
        case .beidou: return polygon(5)
        case .qzss: return polygon(4, rotation: 45)
        case .navic: return polygon(4)
        case .other: return polygon(6)
        }
    }
}

/// Coloured marker for a constellation.
struct ConstellationMarker: Shape {
    var constellation: Constellation
    func path(in rect: CGRect) -> Path { constellation.markerPath(in: rect) }
}

/// Counts of predicted satellites in view per system.
struct ConstellationLegend: View {
    var satellites: [SatellitePosition]

    var body: some View {
        let counts = Dictionary(grouping: satellites, by: \.constellation).mapValues(\.count)
        HStack(spacing: 12) {
            ForEach(Constellation.allCases.filter { counts[$0] != nil }, id: \.self) { constellation in
                HStack(spacing: 4) {
                    ConstellationMarker(constellation: constellation)
                        .fill(constellation.color)
                        .frame(width: 13, height: 13)
                    Text("\(constellation.shortName) \(counts[constellation] ?? 0)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
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
        var labelAbove = false
    }

    /// Bearing shown at the top of the plot.
    var rotation: Double
    var objects: [Object]
    var satellites: [SatellitePosition] = []

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
                    let marker = r * 0.07
                    for satellite in satellites {
                        let p = dialPoint(center, r * 0.92 * CGFloat(1 - max(satellite.elevation, 0) / 90),
                                          satellite.azimuth - rotation)
                        let box = CGRect(x: p.x - marker / 2, y: p.y - marker / 2, width: marker, height: marker)
                        let low = satellite.elevation < 10
                        context.fill(satellite.constellation.markerPath(in: box),
                                     with: .color(satellite.constellation.color.opacity(low ? 0.55 : 1)))
                        let text = context.resolve(Text(satellite.label)
                            .font(.system(size: r * 0.048, weight: .medium).monospacedDigit())
                            .foregroundColor(.white))
                        let size = text.measure(in: CGSize(width: 200, height: 50))
                        let tag = CGRect(x: p.x - size.width / 2 - 4, y: p.y + marker / 2 + 2,
                                         width: size.width + 8, height: size.height + 2)
                        let rounded = Path(roundedRect: tag, cornerRadius: 4)
                        context.fill(rounded, with: .color(Palette.panel))
                        context.stroke(rounded, with: .color(.white.opacity(low ? 0.5 : 1)), lineWidth: 1)
                        context.draw(text, at: CGPoint(x: tag.midX, y: tag.midY))
                    }
                }
                ForEach(objects) { object in
                    let below = object.elevation < 0
                    let distance = r * 0.92 * CGFloat(1 - max(object.elevation, 0) / 90)
                    let point = dialPoint(center, distance, object.azimuth - rotation)
                    VStack(spacing: 2) {
                        if object.labelAbove { label(object.label, size: r) }
                        Image(systemName: object.symbol)
                            .font(.system(size: r * 0.1))
                            .foregroundStyle(object.color)
                            .rotationEffect(.degrees(object.symbol == "location.north.fill" ? object.azimuth - rotation : 0))
                        if !object.labelAbove { label(object.label, size: r) }
                    }
                    .opacity(below ? 0.35 : 1)
                    .position(x: point.x, y: point.y + (object.labelAbove ? -r * 0.04 : r * 0.04))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sky plot")
        .accessibilityValue((objects.map { "\($0.label) \(Format.bearing($0.azimuth)), \(Int($0.elevation))° up" }
            + satellites.map { "\($0.label) \(Format.bearing($0.azimuth)), \(Int($0.elevation))° up" })
            .joined(separator: "; "))
    }

    private func label(_ text: String, size r: CGFloat) -> some View {
        Text(text)
            .font(.system(size: r * 0.055, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white, lineWidth: 1))
    }
}
