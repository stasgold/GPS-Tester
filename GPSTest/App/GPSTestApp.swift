import SwiftUI

@main
struct GPSTestApp: App {
    @State private var location = LocationService()
    @State private var waypoints = WaypointStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(location)
                .environment(waypoints)
        }
    }
}

struct ContentView: View {
    @Environment(LocationService.self) private var location
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.keepScreenOn) private var keepScreenOn = true

    var body: some View {
        TabView {
            StatusView()
                .tabItem { Label("Status", systemImage: "location.viewfinder") }
            MapScreen()
                .tabItem { Label("Map", systemImage: "map") }
            CompassView()
                .tabItem { Label("Compass", systemImage: "safari") }
            TimeView()
                .tabItem { Label("Time", systemImage: "clock") }
            WaypointsView()
                .tabItem { Label("Waypoints", systemImage: "mappin.and.ellipse") }
        }
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
