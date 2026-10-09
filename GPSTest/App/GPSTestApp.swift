import SwiftUI

@main
struct GPSTestApp: App {
    @State private var location = LocationService()
    @State private var waypoints = WaypointStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modifier(LifecycleModifier())
                .environment(location)
                .environment(waypoints)
        }
    }
}
