import SwiftUI

@main
struct GPSTestApp: App {
    @State private var location = LocationService()
    @State private var waypoints = WaypointStore()
    @State private var satellites = SatelliteCatalog()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modifier(LifecycleModifier())
                .environment(location)
                .environment(waypoints)
                .environment(satellites)
                .task { await satellites.refresh() }
        }
    }
}
