import SwiftUI

/// UTC and local date and time, sunrise and sunset, the moon's phase and a 24-hour day/night dial.
struct ClockScreen: View {
    @Environment(LocationService.self) private var location

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let sun = sunTimes(now)
            VStack(spacing: 10) {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        clockTile("UTC Date", Self.text(now, "dd.MM.yy", .gmt))
                        clockTile("UTC Time", Self.text(now, "HH:mm:ss", .gmt))
                    }
                    GridRow {
                        clockTile("Local Date", Self.text(now, "dd.MM.yy", .current))
                        clockTile("Local Time", Self.text(now, "HH:mm:ss", .current))
                    }
                    GridRow {
                        clockTile("Sunrise", sun?.sunrise.map { Self.text($0, "HH:mm:ss", .current) } ?? "--:--:--")
                        clockTile("Sunset", sun?.sunset.map { Self.text($0, "HH:mm:ss", .current) } ?? "--:--:--")
                    }
                }
                HStack(spacing: 16) {
                    let illumination = Astronomy.moonIllumination(at: now)
                    VStack(spacing: 6) {
                        MoonPhaseView(phase: illumination.phase)
                        Text("\(illumination.phaseName) · \(Int((illumination.fraction * 100).rounded()))%")
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    DayDial(now: now, sun: sun, polarDay: polarDay(now))
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func clockTile(_ title: String, _ value: String) -> some View {
        ReadoutTile(title: title) {
            SegmentText(text: value)
                .padding(.vertical, 6)
        }
        .frame(minHeight: 84, maxHeight: 130)
    }

    private func sunTimes(_ now: Date) -> Astronomy.SunTimes? {
        guard let fix = location.location else { return nil }
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        return Astronomy.sunTimes(on: noon, latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
    }

    /// With no sunrise, whether the sun stays up (midnight sun) rather than down (polar night).
    private func polarDay(_ now: Date) -> Bool {
        guard let fix = location.location, let sun = sunTimes(now) else { return false }
        return Astronomy.sunPosition(at: sun.solarNoon, latitude: fix.coordinate.latitude,
                                     longitude: fix.coordinate.longitude).altitude > 0
    }

    static func text(_ date: Date, _ format: String, _ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

/// The moon as it looks tonight: lit part on the right while waxing, on the left while waning.
struct MoonPhaseView: View {
    /// 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter.
    var phase: Double

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let disc = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            context.fill(disc, with: .radialGradient(Gradient(colors: [Color(white: 0.28), Color(white: 0.16)]),
                                                     center: center, startRadius: 0, endRadius: r))
            context.fill(Self.litPath(phase: phase, center: center, radius: r),
                         with: .radialGradient(Gradient(colors: [Color(white: 0.92), Color(white: 0.7)]),
                                               center: center, startRadius: 0, endRadius: r))
            // A few maria so it reads as the moon rather than a ball.
            for (dx, dy, spotSize) in [(-0.3, -0.25, 0.22), (0.15, -0.35, 0.16), (-0.05, 0.1, 0.2), (0.3, 0.25, 0.12), (-0.35, 0.3, 0.1)] {
                let rr = r * spotSize
                let spot = Path(ellipseIn: CGRect(x: center.x + r * dx - rr, y: center.y + r * dy - rr, width: rr * 2, height: rr * 2))
                context.fill(spot, with: .color(.black.opacity(0.12)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// The lit part: the bright limb's half-circle closed by the terminator, a half-ellipse.
    static func litPath(phase: Double, center: CGPoint, radius r: CGFloat) -> Path {
        let waxing = phase < 0.5
        let side: CGFloat = waxing ? 1 : -1
        let k = CGFloat(cos(2 * .pi * phase)) // 1 new, 0 quarter, -1 full
        var path = Path()
        for step in 0...60 {
            let theta = -Double.pi / 2 + Double.pi * Double(step) / 60
            let point = CGPoint(x: center.x + side * r * CGFloat(cos(theta)), y: center.y + r * CGFloat(sin(theta)))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        for step in 0...60 {
            let theta = Double.pi / 2 - Double.pi * Double(step) / 60
            path.addLine(to: CGPoint(x: center.x + side * k * r * CGFloat(cos(theta)), y: center.y + r * CGFloat(sin(theta))))
        }
        path.closeSubpath()
        return path
    }
}

/// 24-hour dial: midnight at the bottom, noon at the top; day, twilight and night shaded; a hand for now.
struct DayDial: View {
    var now: Date
    var sun: Astronomy.SunTimes?
    var polarDay: Bool

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2 * 0.98
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let disc = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            context.fill(disc, with: .color(.black))
            if let sun, let sunrise = sun.sunrise, let sunset = sun.sunset {
                let dawn = sun.civilDawn ?? sunrise
                let dusk = sun.civilDusk ?? sunset
                context.fill(dialSector(center, r, from: Self.angle(dawn), to: Self.angle(dusk)), with: .color(Palette.twilight))
                context.fill(dialSector(center, r, from: Self.angle(sunrise), to: Self.angle(sunset)), with: .color(Palette.day))
            } else if sun != nil, polarDay {
                context.fill(disc, with: .color(Palette.day))
            }
            context.stroke(disc, with: .color(.white), lineWidth: 2)
            for hour in stride(from: 0, to: 24, by: 2) {
                context.draw(Text(String(format: "%02d", hour)).font(.system(size: r * 0.15, weight: .bold)).foregroundColor(.white),
                             at: dialPoint(center, r * 0.8, 180 + Double(hour) * 15))
            }
            var hand = Path()
            let a = Self.angle(now)
            hand.move(to: dialPoint(center, r * 0.62, a))
            hand.addLine(to: dialPoint(center, r * 0.05, a + 90))
            hand.addLine(to: dialPoint(center, r * 0.05, a - 90))
            hand.closeSubpath()
            context.fill(hand, with: .color(Palette.accent))
            let hub = r * 0.1
            context.fill(Path(ellipseIn: CGRect(x: center.x - hub, y: center.y - hub, width: hub * 2, height: hub * 2)),
                         with: .color(Palette.accent))
            let inner = hub * 0.5
            context.stroke(Path(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2)),
                           with: .color(Color(red: 0, green: 0.55, blue: 0.6)), lineWidth: 1.5)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Day and night dial")
    }

    /// Compass angle of a time of day on the dial (local time, midnight at the bottom).
    static func angle(_ date: Date, calendar: Calendar = .current) -> Double {
        let start = calendar.startOfDay(for: date)
        let hours = date.timeIntervalSince(start) / 3600
        return 180 + hours * 15
    }
}
