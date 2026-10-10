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

        // Real orbits when CI downloaded them, otherwise the sample constellations.
        var orbits = SampleOrbits.elements()
        if let path = ProcessInfo.processInfo.environment["GNSS_JSON"],
           let data = FileManager.default.contents(atPath: path),
           let real = try? OrbitalElements.decode(data), !real.isEmpty {
            orbits = real
            let lines = real.map { "\($0.label)\t\($0.constellation.shortName)\t\($0.name)\t\($0.epoch)" }
            try lines.joined(separator: "\n").write(to: directory.appending(path: "orbits.txt"), atomically: true, encoding: .utf8)
        }
        let catalog = SatelliteCatalog(elements: orbits)

        for page in Page.allCases where page != .map {
            let view = RootView(initialPage: page)
                .environment(location)
                .environment(waypoints)
                .environment(catalog)
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
