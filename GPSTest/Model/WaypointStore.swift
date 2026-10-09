import Foundation
import Observation

/// A saved position the compass can point back to.
struct Waypoint: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var created = Date()
}

/// Saved waypoints and the one the compass is navigating to, kept as JSON in Application Support.
@Observable
final class WaypointStore {
    private(set) var waypoints: [Waypoint] = []
    var targetID: UUID? = nil {
        didSet { save() }
    }

    @ObservationIgnored private let url: URL?

    var target: Waypoint? { waypoints.first { $0.id == targetID } }

    /// `url` nil keeps everything in memory (tests and previews).
    init(url: URL? = WaypointStore.defaultURL) {
        self.url = url
        load()
    }

    static var defaultURL: URL? {
        guard let dir = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true) else { return nil }
        return dir.appending(path: "waypoints.json")
    }

    /// Next default name: "Waypoint 1", "Waypoint 2", … skipping names already used.
    var suggestedName: String {
        let used = Set(waypoints.map(\.name))
        var n = waypoints.count + 1
        while used.contains("Waypoint \(n)") { n += 1 }
        return "Waypoint \(n)"
    }

    @discardableResult
    func add(name: String, latitude: Double, longitude: Double, altitude: Double? = nil) -> Waypoint {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let waypoint = Waypoint(name: trimmed.isEmpty ? suggestedName : trimmed,
                                latitude: latitude, longitude: longitude, altitude: altitude)
        waypoints.append(waypoint)
        save()
        return waypoint
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = waypoints.firstIndex(where: { $0.id == id }) else { return }
        waypoints[index].name = trimmed
        save()
    }

    func delete(_ ids: Set<UUID>) {
        waypoints.removeAll { ids.contains($0.id) }
        if let targetID, ids.contains(targetID) {
            self.targetID = nil // saves
        } else {
            save()
        }
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var waypoints: [Waypoint]
        var targetID: UUID?
    }

    private func load() {
        guard let url, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        waypoints = snapshot.waypoints
        targetID = snapshot.targetID
    }

    private func save() {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Snapshot(waypoints: waypoints, targetID: targetID)) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
