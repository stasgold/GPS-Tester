import SwiftUI

/// Round black dial with a white rim; `draw` paints the face inside a square of side `size`.
private struct Dial: View {
    var draw: (inout GraphicsContext, CGPoint, CGFloat) -> Void

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side / 2
            let face = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: side, height: side))
            context.fill(face, with: .color(.black))
            context.stroke(face, with: .color(Palette.rim), lineWidth: max(2, side * 0.012))
            draw(&context, center, radius * 0.985)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private func tick(_ context: inout GraphicsContext, _ center: CGPoint, outer: CGFloat, inner: CGFloat,
                  at degrees: Double, width: CGFloat, color: Color = .white) {
    var path = Path()
    path.move(to: dialPoint(center, outer, degrees))
    path.addLine(to: dialPoint(center, inner, degrees))
    context.stroke(path, with: .color(color), lineWidth: width)
}

/// Tapered pointer from the centre to `length`, `width` wide at the base.
private func needle(_ center: CGPoint, length: CGFloat, width: CGFloat, tail: CGFloat = 0, at degrees: Double) -> Path {
    var path = Path()
    path.move(to: dialPoint(center, length, degrees))
    path.addLine(to: dialPoint(center, width / 2, degrees + 90))
    path.addLine(to: dialPoint(center, tail, degrees + 180))
    path.addLine(to: dialPoint(center, width / 2, degrees - 90))
    path.closeSubpath()
    return path
}

private func hub(_ context: inout GraphicsContext, _ center: CGPoint, radius: CGFloat) {
    let outer = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    context.fill(outer, with: .color(Palette.accent))
    let r = radius * 0.45
    let inner = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    context.stroke(inner, with: .color(Color(red: 0, green: 0.55, blue: 0.6)), lineWidth: max(1, radius * 0.12))
}

/// Car-style speedometer: 0 at lower left, full scale at lower right.
struct Speedometer: View {
    var speed: Double?
    var maxValue: Double
    var step: Double
    var unit: String

    private static let start = -120.0
    private static let sweep = 240.0

    var body: some View {
        Dial { context, center, r in
            func angle(_ v: Double) -> Double { Self.start + Self.sweep * min(max(v, 0), maxValue) / maxValue }
            var v = 0.0
            while v <= maxValue + 0.001 {
                tick(&context, center, outer: r * 0.97, inner: r * 0.86, at: angle(v), width: r * 0.03)
                context.draw(Text("\(Int(v))").font(.system(size: r * 0.13, weight: .bold)).foregroundColor(.white),
                             at: dialPoint(center, r * 0.72, angle(v)))
                if v + step / 2 < maxValue {
                    tick(&context, center, outer: r * 0.97, inner: r * 0.91, at: angle(v + step / 2), width: r * 0.018)
                }
                v += step
            }
            context.draw(Text("Speed").font(.system(size: r * 0.11)).foregroundColor(.white),
                         at: CGPoint(x: center.x, y: center.y - r * 0.33))
            context.draw(Text(unit).font(.system(size: r * 0.1)).foregroundColor(.white),
                         at: CGPoint(x: center.x, y: center.y + r * 0.34))
            context.draw(Text(speed.map { String(format: "%.0f", $0) } ?? "--")
                            .font(.system(size: r * 0.16, weight: .semibold, design: .monospaced))
                            .foregroundColor(Palette.accent),
                         at: CGPoint(x: center.x, y: center.y + r * 0.55))
            let pointer = needle(center, length: r * 0.82, width: r * 0.09, tail: r * 0.05, at: angle(speed ?? 0))
            context.fill(pointer, with: .color(Palette.accent))
            hub(&context, center, radius: r * 0.12)
        }
        .accessibilityElement()
        .accessibilityLabel("Speed")
        .accessibilityValue(speed.map { String(format: "%.0f \(unit)", $0) } ?? "Unknown")
    }
}

/// Fixed compass rose with a needle pointing to north as the phone turns.
struct CompassGauge: View {
    /// Direction the top of the phone points, degrees clockwise from north.
    var heading: Double?
    var isTrueNorth: Bool

    var body: some View {
        Dial { context, center, r in
            for degrees in stride(from: 0, to: 360, by: 3) {
                let major = degrees % 15 == 0
                tick(&context, center, outer: r * 0.97, inner: r * (major ? 0.88 : 0.92), at: Double(degrees),
                     width: major ? r * 0.015 : r * 0.008)
            }
            let names = [0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"]
            for degrees in stride(from: 0, to: 360, by: 15) {
                if let name = names[degrees] {
                    let cardinal = degrees % 90 == 0
                    context.draw(Text(name).font(.system(size: r * (cardinal ? 0.17 : 0.1), weight: .bold))
                                    .foregroundColor(.white),
                                 at: dialPoint(center, r * (cardinal ? 0.75 : 0.77), Double(degrees)))
                } else {
                    context.draw(Text("\(degrees)").font(.system(size: r * 0.065)).foregroundColor(.white),
                                 at: dialPoint(center, r * 0.79, Double(degrees)))
                }
            }
            for degrees in stride(from: 0.0, to: 360, by: 45) {
                let long = degrees.truncatingRemainder(dividingBy: 90) == 0
                tick(&context, center, outer: r * (long ? 0.6 : 0.55), inner: r * 0.2, at: degrees,
                     width: long ? r * 0.012 : r * 0.006, color: .white.opacity(long ? 0.9 : 0.5))
            }
            let north = -(heading ?? 0)
            let northHalf = needle(center, length: r * 0.72, width: r * 0.16, at: north)
            let southHalf = needle(center, length: r * 0.72, width: r * 0.16, at: north + 180)
            context.fill(southHalf, with: .color(Palette.accent.opacity(heading == nil ? 0.3 : 1)))
            context.fill(northHalf, with: .color(.black))
            context.stroke(northHalf, with: .color(Palette.accent.opacity(heading == nil ? 0.3 : 1)), lineWidth: r * 0.025)
            hub(&context, center, radius: r * 0.16)
            let inner = r * 0.09
            context.fill(Path(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2)),
                         with: .color(.black))
            context.draw(Text(isTrueNorth ? "T" : "M").font(.system(size: r * 0.1, weight: .bold)).foregroundColor(.white),
                         at: center)
        }
        .accessibilityElement()
        .accessibilityLabel("Compass")
        .accessibilityValue(heading.map { Format.bearing($0) } ?? "Unknown")
    }
}

/// Aircraft-style altimeter: long hand hundreds, short hand thousands, plus a digital counter.
struct Altimeter: View {
    var altitude: Double?
    var unit: String

    var body: some View {
        Dial { context, center, r in
            for index in 0..<50 {
                let degrees = Double(index) * 7.2
                let major = index % 5 == 0
                tick(&context, center, outer: r * 0.97, inner: r * (major ? 0.85 : 0.91), at: degrees,
                     width: major ? r * 0.035 : r * 0.015)
            }
            for digit in 0..<10 {
                context.draw(Text("\(digit)").font(.system(size: r * 0.24, weight: .bold)).foregroundColor(.white),
                             at: dialPoint(center, r * 0.66, Double(digit) * 36))
            }
            context.draw(Text("Altitude").font(.system(size: r * 0.11)).foregroundColor(.white),
                         at: CGPoint(x: center.x, y: center.y - r * 0.33))
            let value = altitude ?? 0
            let counter = altitude.map { String(format: "%05d", Int(abs($0).rounded()) % 100_000) } ?? "-----"
            let box = CGRect(x: center.x - r * 0.42, y: center.y + r * 0.12, width: r * 0.84, height: r * 0.26)
            context.stroke(Path(box), with: .color(.white), lineWidth: max(1, r * 0.012))
            context.draw(Text((value < 0 ? "-" : "") + counter)
                            .font(.system(size: r * 0.2, weight: .semibold, design: .monospaced))
                            .foregroundColor(Palette.accent),
                         at: CGPoint(x: box.midX, y: box.midY))
            context.draw(Text(unit).font(.system(size: r * 0.1)).foregroundColor(.white),
                         at: CGPoint(x: center.x, y: center.y + r * 0.5))
            let magnitude = abs(value)
            let hundreds = magnitude.truncatingRemainder(dividingBy: 1000) / 1000 * 360
            let thousands = magnitude.truncatingRemainder(dividingBy: 10_000) / 10_000 * 360
            context.fill(needle(center, length: r * 0.62, width: r * 0.13, at: thousands), with: .color(Palette.accent))
            context.fill(needle(center, length: r * 0.9, width: r * 0.06, at: hundreds), with: .color(Palette.accent))
            hub(&context, center, radius: r * 0.08)
        }
        .accessibilityElement()
        .accessibilityLabel("Altitude")
        .accessibilityValue(altitude.map { String(format: "%.0f \(unit)", $0) } ?? "Unknown")
    }
}
