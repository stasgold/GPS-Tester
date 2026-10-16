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
        case .fix3D: Color(red: 0, green: 1, blue: 0)
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

/// LCD readout in a block font: each character is drawn on a 5 × 9 grid of square cells with hairline gaps,
/// like a receiver's segmented display. Digits, the letters of the month names, space, '-', ':' and '.'.
struct SegmentText: View {
    var text: String
    var color: Color = Palette.accent

    var body: some View {
        Canvas { context, size in
            let cell = size.height / CGFloat(Self.rows)
            let inset = cell * 0.04
            var x: CGFloat = 0
            for character in text.uppercased() {
                let glyph = Self.glyph(character)
                for (row, line) in glyph.enumerated() {
                    for (column, mark) in line.enumerated() where mark == "#" {
                        let rect = CGRect(x: x + CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                            .insetBy(dx: inset, dy: inset)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
                x += CGFloat(Self.width(of: character) + Self.spacing) * cell
            }
        }
        .aspectRatio(Self.aspectRatio(of: text), contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(text)
    }

    static let rows = 9
    private static let spacing = 1

    private static func width(of character: Character) -> Int {
        glyph(character).first?.count ?? 5
    }

    /// Width over height of the whole string.
    static func aspectRatio(of text: String) -> CGFloat {
        let cells = text.uppercased().map { width(of: $0) }
        let total = cells.reduce(0, +) + spacing * max(cells.count - 1, 0)
        return max(CGFloat(total) / CGFloat(rows), 0.1)
    }

    private static func glyph(_ character: Character) -> [String] {
        if let rows = glyphs[character] { return rows }
        return Array(repeating: "...", count: rows) // unknown characters are blank
    }

    private static let glyphs: [Character: [String]] = {
        func g(_ rows: String...) -> [String] { rows }
        let box = g("#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", "#####")
        let five = g("#####", "#....", "#....", "#....", "#####", "....#", "....#", "....#", "#####")
        return [
            "0": box,
            "1": g("....#", "....#", "....#", "....#", "....#", "....#", "....#", "....#", "....#"),
            "2": g("#####", "....#", "....#", "....#", "#####", "#....", "#....", "#....", "#####"),
            "3": g("#####", "....#", "....#", "....#", "#####", "....#", "....#", "....#", "#####"),
            "4": g("#...#", "#...#", "#...#", "#...#", "#####", "....#", "....#", "....#", "....#"),
            "5": five,
            "6": g("#####", "#....", "#....", "#....", "#####", "#...#", "#...#", "#...#", "#####"),
            "7": g("#####", "....#", "....#", "....#", "....#", "....#", "....#", "....#", "....#"),
            "8": g("#####", "#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#", "#####"),
            "9": g("#####", "#...#", "#...#", "#...#", "#####", "....#", "....#", "....#", "#####"),
            "A": g("#####", "#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#", "#...#"),
            "B": g("####.", "#...#", "#...#", "#...#", "####.", "#...#", "#...#", "#...#", "####."),
            "C": g("#####", "#....", "#....", "#....", "#....", "#....", "#....", "#....", "#####"),
            "D": g("####.", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", "####."),
            "E": g("#####", "#....", "#....", "#....", "####.", "#....", "#....", "#....", "#####"),
            "F": g("#####", "#....", "#....", "#....", "####.", "#....", "#....", "#....", "#...."),
            "G": g("#####", "#....", "#....", "#....", "#..##", "#...#", "#...#", "#...#", "#####"),
            "J": g("....#", "....#", "....#", "....#", "....#", "....#", "#...#", "#...#", "#####"),
            "L": g("#....", "#....", "#....", "#....", "#....", "#....", "#....", "#....", "#####"),
            "M": g("#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#", "#...#", "#...#"),
            "N": g("#...#", "##..#", "##..#", "#.#.#", "#.#.#", "#..##", "#..##", "#...#", "#...#"),
            "O": box,
            "P": g("#####", "#...#", "#...#", "#...#", "#####", "#....", "#....", "#....", "#...."),
            "R": g("#####", "#...#", "#...#", "#...#", "#####", "#.#..", "#..#.", "#...#", "#...#"),
            "S": five,
            "T": g("#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."),
            "U": g("#...#", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", "#####"),
            "V": g("#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#.."),
            "Y": g("#...#", "#...#", "#...#", "#...#", "#####", "..#..", "..#..", "..#..", "..#.."),
            "-": g(".....", ".....", ".....", ".....", "#####", ".....", ".....", ".....", "....."),
            ":": g(".", ".", "#", ".", ".", ".", "#", ".", "."),
            ".": g(".", ".", ".", ".", ".", ".", ".", ".", "#"),
            " ": g("...", "...", "...", "...", "...", "...", "...", "...", "..."),
        ]
    }()
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
