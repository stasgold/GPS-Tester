import SwiftUI

/// Colours of the receiver-style screens: black tiles with white rims on grey, cyan readouts.
enum Palette {
    static let background = Color(white: 0.45)
    static let tile = Color.black
    static let rim = Color.white
    static let accent = Color(red: 0, green: 1, blue: 1)
    static let panel = Color(red: 0, green: 0, blue: 0.24)
    static let day = Color(red: 0.34, green: 0.5, blue: 0.72)
    static let twilight = Color(red: 0.2, green: 0.3, blue: 0.47)
}

extension SignalQuality {
    var color: Color {
        switch self {
        case .poor: .red
        case .fair: .orange
        case .moderate: .yellow
        case .good: Color(red: 0.67, green: 1, blue: 0)
        case .excellent: .green
        }
    }
}

extension FixStatus {
    var color: Color {
        switch self {
        case .fix3D: .green
        case .fix2D: .yellow
        case .searching: .red
        case .stale: .orange
        case .off: .gray
        }
    }
}

private struct TileStyle: ViewModifier {
    var fill: Color
    var selected: Bool

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selected ? Palette.accent : Palette.rim, lineWidth: selected ? 3 : 2))
    }
}

extension View {
    /// Black rounded tile with a white rim (cyan when selected).
    func tile(selected: Bool = false) -> some View { modifier(TileStyle(fill: Palette.tile, selected: selected)) }

    /// Navy rounded panel with a white rim, used behind charts.
    func panel() -> some View { modifier(TileStyle(fill: Palette.panel, selected: false)) }
}

/// A titled black tile with its content filling the space below the title.
struct ReadoutTile<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.regular))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .tile()
    }
}

/// Seven-segment LCD characters. Draws digits, space, '-', ':' and '.'; anything else is a space.
struct SegmentText: View {
    var text: String
    var color: Color = Palette.accent

    var body: some View {
        Canvas { context, size in
            let h = size.height
            var x: CGFloat = 0
            for character in text {
                let width = Self.width(of: character) * h
                draw(character, in: CGRect(x: x, y: 0, width: width, height: h), context: &context)
                x += width + Self.gap * h
            }
        }
        .aspectRatio(Self.aspectRatio(of: text), contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(text)
    }

    private static let gap: CGFloat = 0.12

    private static func width(of character: Character) -> CGFloat {
        character == ":" || character == "." ? 0.18 : 0.56
    }

    static func aspectRatio(of text: String) -> CGFloat {
        let widths = text.map(width(of:))
        return max(widths.reduce(0, +) + gap * CGFloat(max(widths.count - 1, 0)), 0.1)
    }

    /// Segments a–g for each character: top, upper right, lower right, bottom, lower left, upper left, middle.
    private static let segments: [Character: String] = [
        "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
        "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g",
    ]

    private func draw(_ character: Character, in rect: CGRect, context: inout GraphicsContext) {
        let h = rect.height, w = rect.width, t = h * 0.12, g = t * 0.18
        let shading = GraphicsContext.Shading.color(color)
        func bar(_ r: CGRect) {
            context.fill(Path(roundedRect: r.offsetBy(dx: rect.minX, dy: rect.minY), cornerRadius: t * 0.35), with: shading)
        }
        switch character {
        case ":":
            bar(CGRect(x: (w - t) / 2, y: h * 0.28, width: t, height: t))
            bar(CGRect(x: (w - t) / 2, y: h * 0.66, width: t, height: t))
            return
        case ".":
            bar(CGRect(x: (w - t) / 2, y: h - t, width: t, height: t))
            return
        default:
            break
        }
        let lit = Self.segments[character] ?? ""
        let horizontalWidth = w - t - 2 * g
        let verticalHeight = h / 2 - t / 2 - 2 * g
        let rects: [Character: CGRect] = [
            "a": CGRect(x: t / 2 + g, y: 0, width: horizontalWidth, height: t),
            "g": CGRect(x: t / 2 + g, y: (h - t) / 2, width: horizontalWidth, height: t),
            "d": CGRect(x: t / 2 + g, y: h - t, width: horizontalWidth, height: t),
            "f": CGRect(x: 0, y: t / 2 + g, width: t, height: verticalHeight),
            "b": CGRect(x: w - t, y: t / 2 + g, width: t, height: verticalHeight),
            "e": CGRect(x: 0, y: h / 2 + g, width: t, height: verticalHeight),
            "c": CGRect(x: w - t, y: h / 2 + g, width: t, height: verticalHeight),
        ]
        for segment in lit {
            if let r = rects[segment] { bar(r) }
        }
    }
}

/// Point at `radius` from `center` on a compass bearing (0° up, clockwise).
func dialPoint(_ center: CGPoint, _ radius: CGFloat, _ degrees: Double) -> CGPoint {
    let theta = degrees * .pi / 180
    return CGPoint(x: center.x + radius * CGFloat(sin(theta)), y: center.y - radius * CGFloat(cos(theta)))
}

/// Closed wedge between two compass bearings (clockwise from `from` to `to`).
func dialSector(_ center: CGPoint, _ radius: CGFloat, from: Double, to: Double) -> Path {
    var end = to
    while end < from { end += 360 }
    var path = Path()
    path.move(to: center)
    var angle = from
    while angle < end {
        path.addLine(to: dialPoint(center, radius, angle))
        angle += 1
    }
    path.addLine(to: dialPoint(center, radius, end))
    path.closeSubpath()
    return path
}
