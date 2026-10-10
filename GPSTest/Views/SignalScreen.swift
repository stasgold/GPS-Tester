import SwiftUI

/// Fix status, accuracy, a bar per recent fix and the average quality bar.
///
/// iOS hides individual satellites, so where a receiver shows one bar per satellite's SNR this shows
/// one bar per fix, its height and colour graded from the accuracy of that fix.
struct SignalScreen: View {
    @Environment(LocationService.self) private var location
    @Environment(SatelliteCatalog.self) private var catalog
    @AppStorage(SettingsKey.units) private var units = UnitSystem.metric

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ReadoutTile(title: "GNSS Status") {
                        FixLabel(status: location.fixStatus(at: context.date), size: 34)
                    }
                    ReadoutTile(title: "Accuracy (± \(units.shortLengthUnit))") {
                        SegmentText(text: accuracyText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(height: 116)
                GeometryPanel(dop: predictedDOP(at: context.date), accuracy: location.history.averageAccuracy(),
                              units: units, hasOrbits: !catalog.elements.isEmpty)
                FixBars(samples: Array(location.history.suffix(12)), updates: location.updateCount,
                        rate: location.updateRate, units: units)
                QualityBar(accuracy: location.history.averageAccuracy())
            }
        }
    }

    /// Geometry of the satellites predicted overhead right now.
    private func predictedDOP(at date: Date) -> DilutionOfPrecision? {
        guard let fix = location.location else { return nil }
        let satellites = catalog.positions(at: date, latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                           altitude: fix.verticalAccuracy > 0 ? fix.altitude : 0)
        return DilutionOfPrecision.predict(from: satellites)
    }

    private var accuracyText: String {
        guard let fix = location.location, fix.horizontalAccuracy > 0 else { return "--" }
        return String(Int(units.altitudeValue(fix.horizontalAccuracy).rounded()))
    }
}

/// Coloured dot and fix state, as on a receiver.
struct FixLabel: View {
    var status: FixStatus
    var size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.35) {
            Circle()
                .fill(status.color)
                .frame(width: size * 0.9, height: size * 0.9)
                .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
            Text(status.title)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One bar per fix: newest on the right, labelled with its accuracy and age in seconds.
struct FixBars: View {
    var samples: [AccuracySample]
    var updates: Int
    var rate: Double?
    var units: UnitSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                stat("Updates", "\(updates)", alignment: .leading)
                Spacer()
                stat("Rate (Hz)", rate.map { String(format: "%.1f", $0) } ?? "--", alignment: .trailing)
            }
            GeometryReader { proxy in
                let slots = 12
                let slot = proxy.size.width / CGFloat(slots)
                let chartHeight = proxy.size.height - 64
                ZStack(alignment: .topLeading) {
                    ForEach(1..<4) { line in
                        Path { path in
                            let y = chartHeight * CGFloat(line) / 4 + 20
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                        }
                        .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: chartHeight + 20))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: chartHeight + 20))
                    }
                    .stroke(.white, lineWidth: 2)
                    ForEach(Array(samples.enumerated()), id: \.element.id) { index, sample in
                        let x = (CGFloat(slots - samples.count + index) + 0.5) * slot
                        let baseline = chartHeight + 20
                        let position = max(SignalQuality.position(accuracy: sample.horizontal), 0.03)
                        let height = chartHeight * CGFloat(position)
                        let age = samples.last.map { Int($0.date.timeIntervalSince(sample.date).rounded()) } ?? 0
                        RoundedRectangle(cornerRadius: 4)
                            .fill(SignalQuality(accuracy: sample.horizontal).color)
                            .frame(width: slot - 8, height: height)
                            .position(x: x, y: baseline - height / 2)
                        Text("\(Int(units.altitudeValue(sample.horizontal).rounded()))")
                            .font(.system(size: min(slot * 0.42, 22)))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: slot)
                            .position(x: x, y: max(baseline - height - 12, 8))
                        Circle()
                            .fill(.white)
                            .frame(width: slot * 0.3, height: slot * 0.3)
                            .position(x: x, y: baseline + 14)
                        Text(age == 0 ? "now" : "-\(age)")
                            .font(.system(size: min(slot * 0.34, 18), weight: .medium).monospacedDigit())
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: slot - 6)
                            .padding(.vertical, 2)
                            .background(.white, in: RoundedRectangle(cornerRadius: 5))
                            .position(x: x, y: baseline + 38)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            Text("iOS doesn't let apps see satellites. Each bar is one fix, graded by its accuracy.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(14)
        .frame(maxHeight: .infinity)
        .panel()
    }

    private func stat(_ title: String, _ value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(title).font(.headline.weight(.regular))
            Text(value).font(.system(size: 40, weight: .regular).monospacedDigit())
        }
        .foregroundStyle(.white)
    }
}

/// Red → green bar with a marker at the average accuracy of the last 30 seconds.
struct QualityBar: View {
    var accuracy: Double?

    private static let marks: [Double] = [50, 20, 10, 5, 3, 1]

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("AVG\nACC").font(.headline.weight(.regular)).foregroundStyle(.white)
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(SignalQuality.allCases, id: \.self) { level in
                            Rectangle().fill(level.color).frame(width: width * span(of: level))
                        }
                    }
                    .frame(height: 30)
                    .offset(y: 30)
                    ForEach(Self.marks, id: \.self) { mark in
                        Text(mark == 50 ? "50+" : "\(Int(mark))")
                            .font(.headline.weight(.regular).monospacedDigit())
                            .foregroundStyle(.white)
                            .position(x: width * CGFloat(SignalQuality.position(accuracy: mark)), y: 76)
                    }
                    if let accuracy {
                        let x = width * CGFloat(SignalQuality.position(accuracy: accuracy))
                        Text(String(format: "%.1f m", accuracy))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.yellow, in: Capsule())
                            .overlay(Capsule().stroke(.black, lineWidth: 1))
                            .position(x: min(max(x, 40), width - 40), y: 12)
                        MarkerTriangle()
                            .fill(.yellow)
                            .frame(width: 12, height: 8)
                            .position(x: x, y: 26)
                    }
                }
            }
            .frame(height: 90)
            .padding(.horizontal, 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .panel()
        .accessibilityElement()
        .accessibilityLabel("Average accuracy")
        .accessibilityValue(accuracy.map { String(format: "%.1f metres", $0) } ?? "Unknown")
    }

    /// Share of the bar each quality level occupies.
    private func span(of level: SignalQuality) -> CGFloat {
        let edges = [SignalQuality.worst] + SignalQuality.limits + [SignalQuality.best]
        let low = SignalQuality.position(accuracy: edges[level.rawValue])
        let high = SignalQuality.position(accuracy: edges[level.rawValue + 1])
        return CGFloat(high - low)
    }
}

/// Small downward-pointing triangle.
struct MarkerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Predicted geometry (HDOP), the accuracy it should allow, and how open the sky looks by comparison.
struct GeometryPanel: View {
    var dop: DilutionOfPrecision?
    /// Average reported horizontal accuracy, metres.
    var accuracy: Double?
    var units: UnitSystem
    var hasOrbits: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column("Predicted HDOP", dop.map { String(format: "%.2f", $0.horizontal) } ?? "--",
                   detail: dop.map { "PDOP \(String(format: "%.1f", $0.position)) · \($0.satelliteCount) sats" }
                       ?? (hasOrbits ? "Waiting for a fix" : "No orbits yet"))
            column("Best expected", dop.map { "±" + units.length($0.expectedAccuracy) } ?? "--",
                   detail: accuracy.map { "Now ±" + units.length($0) } ?? " ")
            VStack(alignment: .leading, spacing: 2) {
                Text("Sky").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                if let sky {
                    Text(sky.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color(sky))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Text("--").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                }
                Text("from accuracy vs geometry")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .panel()
        .accessibilityElement(children: .combine)
        .accessibilityHint(sky?.explanation ?? "")
    }

    private var sky: SkyView? {
        guard let dop, let accuracy else { return nil }
        return SkyView(reported: accuracy, expected: dop.expectedAccuracy)
    }

    private func color(_ sky: SkyView) -> Color {
        switch sky {
        case .open: .green
        case .partial: .yellow
        case .obstructed: .orange
        }
    }

    private func column(_ title: String, _ value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline).foregroundStyle(.white.opacity(0.8)).lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.system(size: 22, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.accent)
            Text(detail).font(.caption2).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
