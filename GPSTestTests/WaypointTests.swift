import Foundation
import Testing
@testable import GPSTest

struct WaypointTests {
    @Test func addRenameDelete() {
        let store = WaypointStore(url: nil)
        let first = store.add(name: "  ", latitude: 1, longitude: 2)
        #expect(first.name == "Waypoint 1")
        let car = store.add(name: "Car", latitude: 3, longitude: 4, altitude: 12)
        #expect(store.suggestedName == "Waypoint 3")

        store.rename(car.id, to: " Parked car ")
        #expect(store.waypoints[1].name == "Parked car")
        store.rename(car.id, to: "   ")
        #expect(store.waypoints[1].name == "Parked car")

        store.targetID = car.id
        #expect(store.target?.name == "Parked car")
        store.delete([car.id])
        #expect(store.targetID == nil)
        #expect(store.waypoints.map(\.name) == ["Waypoint 1"])
    }

    @Test func suggestedNameSkipsNamesInUse() {
        let store = WaypointStore(url: nil)
        store.add(name: "Waypoint 2", latitude: 0, longitude: 0)
        #expect(store.suggestedName == "Waypoint 3")
    }

    @Test func persistsToDisk() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waypoints-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = WaypointStore(url: url)
        let home = store.add(name: "Home", latitude: 51.5, longitude: -0.12, altitude: 20)
        store.targetID = home.id

        let reopened = WaypointStore(url: url)
        #expect(reopened.waypoints == store.waypoints)
        #expect(reopened.targetID == home.id)
    }

    @Test func parsesTypedCoordinates() {
        func parse(_ lat: String, _ lon: String) -> [Double]? {
            WaypointInput.parse(latitude: lat, longitude: lon).map { [$0.latitude, $0.longitude] }
        }
        #expect(parse("51.5007", "-0.1246") == [51.5007, -0.1246])
        #expect(parse("33,8688 S", "151.2093E") == [-33.8688, 151.2093])
        #expect(parse("N 10°", "W 20°") == [10, -20])
        #expect(parse("91", "0") == nil)
        #expect(parse("0", "181") == nil)
        #expect(parse("abc", "0") == nil)
        #expect(parse("-12 S", "0") == nil)
    }

    @Test func shareText() {
        let text = ShareText.position(latitude: 51.5007, longitude: -0.1246, altitude: 20, accuracy: 4.26,
                                      name: "Big Ben", format: .degreesMinutes, units: .metric)
        #expect(text == """
        Big Ben
        51° 30.042′ N, 0° 07.476′ W
        51.500700, -0.124600
        Altitude: 20 m
        Accuracy: ±4.3 m
        https://maps.apple.com/?ll=51.500700,-0.124600&q=Big%20Ben
        """)
    }
}
