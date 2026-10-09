import CoreLocation
import SwiftUI

/// The gear button every tab shows, opening the shared settings sheet.
struct SettingsToolbar: ViewModifier {
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

extension View {
    func settingsToolbar() -> some View { modifier(SettingsToolbar()) }
}

/// Explains what to do when location access is missing; empty when the app is authorised.
struct LocationAccessBanner: View {
    @Environment(LocationService.self) private var location
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch location.authorization {
        case .notDetermined:
            banner("Location access needed",
                   message: "GPS Test reads your position, speed and heading from the phone's GNSS receiver.",
                   button: "Allow Location Access") { location.start() }
        case .denied, .restricted:
            banner("Location access is off",
                   message: "Turn on Location Services for GPS Test in Settings to see fixes.",
                   button: "Open Settings") { openSettings() }
        default:
            if !location.isPrecise {
                banner("Precise Location is off",
                       message: "iOS is only sharing an approximate position (about 3 km). Turn on Precise Location in Settings.",
                       button: "Open Settings") { openSettings() }
            } else if let message = location.errorMessage {
                banner("Location error", message: message, button: "Restart") { location.restart() }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func banner(_ title: String, message: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "location.slash").font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            Button(button, action: action).buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Coloured capsule showing the fix state.
struct FixBadge: View {
    var status: FixStatus

    var body: some View {
        Text(status.title)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel("Fix status: \(status.title)")
    }

    private var color: Color {
        switch status {
        case .fix3D: .green
        case .fix2D: .yellow
        case .searching: .blue
        case .stale: .orange
        case .off: .gray
        }
    }
}

enum Format {
    /// "1.2 s", "48 s", "3 min 05 s".
    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 10 { return String(format: "%.1f s", seconds) }
        if seconds < 60 { return "\(Int(seconds)) s" }
        if seconds < 3600 { return String(format: "%d min %02d s", Int(seconds) / 60, Int(seconds) % 60) }
        return String(format: "%d h %02d min", Int(seconds) / 3600, Int(seconds) % 3600 / 60)
    }

    /// "247° WSW".
    static func bearing(_ degrees: Double) -> String {
        "\(Int(Geodesy.normalized(degrees).rounded()) % 360)° \(Geodesy.cardinal(degrees))"
    }

    static func time(_ date: Date?, in timeZone: TimeZone = .current, seconds: Bool = false) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(seconds ? "jjmmss" : "jjmm")
        return formatter.string(from: date)
    }
}
