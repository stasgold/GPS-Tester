import SwiftUI

/// The pages picked from the tile row at the bottom.
enum Page: Int, CaseIterable, Identifiable {
    case dashboard, signal, sky, time, map

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .signal: "Signal"
        case .sky: "Sky"
        case .time: "Time"
        case .map: "Map"
        }
    }
}

/// Screens opened from the top button row.
private enum Sheet: String, Identifiable {
    case waypoints, compass, details, sunMoon, settings
    var id: String { rawValue }
}

/// Receiver-style shell: a row of buttons on top, the current page, and page tiles at the bottom.
struct RootView: View {
    @Environment(LocationService.self) private var location
    @AppStorage(SettingsKey.coordinateFormat) private var format = CoordinateFormat.decimal
    @AppStorage(SettingsKey.units) private var units = UnitSystem.metric
    @AppStorage("nightMode") private var nightMode = false
    @AppStorage("page") private var storedPage = Page.dashboard.rawValue
    @State private var sheet: Sheet?

    /// Overrides the remembered page (screenshots).
    var initialPage: Page?

    init(initialPage: Page? = nil) {
        self.initialPage = initialPage
    }

    private var page: Page { initialPage ?? Page(rawValue: storedPage) ?? .dashboard }

    var body: some View {
        VStack(spacing: 10) {
            topBar
            if !location.isAuthorized || !location.isPrecise || location.errorMessage != nil {
                LocationAccessBanner()
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Palette.background.ignoresSafeArea())
        .colorMultiply(nightMode ? Color(red: 1, green: 0.25, blue: 0.2) : .white)
        .preferredColorScheme(.dark)
        .sheet(item: $sheet) { sheet in
            Group {
                switch sheet {
                case .waypoints: WaypointsView()
                case .compass: CompassView()
                case .details: StatusView()
                case .sunMoon: TimeView()
                case .settings: SettingsView()
                }
            }
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .dashboard: DashboardScreen()
        case .signal: SignalScreen()
        case .sky: SkyScreen()
        case .time: ClockScreen()
        case .map: MapScreen().clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Top row

    private var topBar: some View {
        HStack(spacing: 10) {
            topButton("Night mode", nightMode ? "sun.max.fill" : "moon.fill") { nightMode.toggle() }
            topButton("Waypoints", "figure.walk.motion") { sheet = .waypoints }
            topButton("Navigate", "location.north.fill") { sheet = .compass }
            if let fix = location.location {
                ShareLink(item: ShareText.position(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                                   altitude: fix.verticalAccuracy > 0 ? fix.altitude : nil,
                                                   accuracy: fix.horizontalAccuracy, format: format, units: units)) {
                    topIcon("square.and.arrow.up")
                }
                .accessibilityLabel("Share location")
            } else {
                topIcon("square.and.arrow.up").opacity(0.4).accessibilityLabel("Share location, no fix yet")
            }
            Menu {
                Button("Details", systemImage: "list.bullet.rectangle") { sheet = .details }
                Button("Sun & Moon", systemImage: "sun.and.horizon") { sheet = .sunMoon }
                Button("Restart GPS", systemImage: "arrow.clockwise") { location.restart() }
                Button("Settings", systemImage: "gearshape") { sheet = .settings }
            } label: {
                topIcon("ellipsis")
            }
            .accessibilityLabel("More")
        }
        .frame(height: 54)
    }

    private func topButton(_ label: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { topIcon(symbol) }
            .accessibilityLabel(label)
    }

    private func topIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .tile()
    }

    // MARK: Bottom row

    private var bottomBar: some View {
        HStack(spacing: 10) {
            ForEach(Page.allCases) { item in
                Button {
                    storedPage = item.rawValue
                } label: {
                    PageTile(page: item)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tile(selected: item == page)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(item == page ? .isSelected : [])
            }
        }
        .frame(height: 84)
    }
}

/// Live miniature of each page for the bottom tile row.
private struct PageTile: View {
    @Environment(LocationService.self) private var location
    var page: Page

    var body: some View {
        Group {
            switch page {
            case .dashboard:
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let status = location.fixStatus(at: context.date)
                    VStack(spacing: 6) {
                        Circle().fill(status.color).frame(width: 22, height: 22)
                        Text(status.title)
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            case .signal:
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(location.history.suffix(6).enumerated()), id: \.offset) { _, sample in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(SignalQuality(accuracy: sample.horizontal).color)
                            .frame(width: 6, height: max(4, 44 * CGFloat(SignalQuality.position(accuracy: sample.horizontal))))
                    }
                }
                .frame(height: 46, alignment: .bottom)
            case .sky:
                ZStack {
                    Circle().stroke(.white, lineWidth: 1.5)
                    Circle().stroke(.white.opacity(0.5), lineWidth: 1).padding(12)
                    Path { path in
                        path.move(to: CGPoint(x: 26, y: 0))
                        path.addLine(to: CGPoint(x: 26, y: 52))
                        path.move(to: CGPoint(x: 0, y: 26))
                        path.addLine(to: CGPoint(x: 52, y: 26))
                    }
                    .stroke(.white.opacity(0.5), lineWidth: 1)
                    Circle().fill(.yellow).frame(width: 9, height: 9).offset(x: 10, y: -12)
                    Circle().fill(Color(white: 0.85)).frame(width: 7, height: 7).offset(x: -14, y: 8)
                }
                .frame(width: 52, height: 52)
            case .time:
                TimelineView(.everyMinute) { context in
                    SegmentText(text: ClockScreen.text(context.date, "HH:mm", .current))
                        .frame(height: 30)
                        .padding(.horizontal, 6)
                }
            case .map:
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
            }
        }
        .padding(6)
    }
}

/// Starts GNSS while the app is on screen, stops it in the background, and keeps the screen awake.
struct LifecycleModifier: ViewModifier {
    @Environment(LocationService.self) private var location
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.keepScreenOn) private var keepScreenOn = true

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, initial: true) { _, phase in
                // GNSS is the biggest battery drain on the phone: only run it while the app is on screen.
                switch phase {
                case .active: location.start()
                case .background: location.stop()
                default: break
                }
                updateIdleTimer()
            }
            .onChange(of: keepScreenOn) { updateIdleTimer() }
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenOn && scenePhase == .active
    }
}
