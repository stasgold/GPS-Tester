import SwiftUI
import Testing
@testable import GPSTest

/// Renders each page with sample fixes to JPEGs when SNAPSHOT_DIR is set (CI publishes them).
@MainActor
struct ScreenSnapshots {
    @Test func renderPages() throws {
        guard let folder = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !folder.isEmpty else { return }
        let directory = URL(fileURLWithPath: folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let location = LocationService()
        location.loadSampleFixes()
        let waypoints = WaypointStore(url: nil)
        waypoints.targetID = waypoints.add(name: "Car", latitude: 51.51, longitude: -0.13).id

        for page in Page.allCases where page != .map {
            let view = RootView(initialPage: page)
                .environment(location)
                .environment(waypoints)
                .environment(\.colorScheme, .dark)
                .frame(width: 393, height: 852)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            let data = try #require(image.jpegData(compressionQuality: 0.8))
            try data.write(to: directory.appending(path: "\(page.rawValue)-\(page.title).jpg"))
        }
    }
}
