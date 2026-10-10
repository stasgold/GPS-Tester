import Foundation
import Observation

/// Orbits of the navigation satellites, downloaded from CelesTrak and cached on the device.
///
/// One request (about 100 KB) at most once every 12 hours. The request carries no location;
/// positions are worked out on the phone.
@Observable
final class SatelliteCatalog {
    static let source = URL(string: "https://celestrak.org/NORAD/elements/gp.php?GROUP=gnss&FORMAT=json")!
    static let refreshInterval: TimeInterval = 12 * 3600
    /// Orbits older than this drift too far to plot.
    static let maximumAge: TimeInterval = 21 * 86400

    private(set) var elements: [OrbitalElements] = []
    private(set) var downloadedAt: Date?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let cacheURL: URL?
    @ObservationIgnored private let session: URLSession

    /// `cacheURL` nil keeps everything in memory (tests and previews).
    init(cacheURL: URL? = SatelliteCatalog.defaultCacheURL, session: URLSession = .shared) {
        self.cacheURL = cacheURL
        self.session = session
        loadCache()
    }

    /// For screenshots and tests.
    init(elements: [OrbitalElements], downloadedAt: Date = Date()) {
        cacheURL = nil
        session = .shared
        self.elements = elements
        self.downloadedAt = downloadedAt
    }

    static var defaultCacheURL: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "gnss-orbits.json")
    }

    /// True when the orbits are missing or too old to use.
    var isStale: Bool {
        guard let newest = elements.map(\.epoch).max() else { return true }
        return Date().timeIntervalSince(newest) > Self.maximumAge
    }

    /// Downloads fresh orbits if the cached ones are older than the refresh interval (or `force`).
    @MainActor
    func refresh(force: Bool = false) async {
        if isLoading { return }
        if !force, let downloadedAt, Date().timeIntervalSince(downloadedAt) < Self.refreshInterval, !elements.isEmpty { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let (data, response) = try await session.data(from: Self.source)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
            let decoded = try OrbitalElements.decode(data)
            guard !decoded.isEmpty else { throw URLError(.zeroByteResource) }
            elements = decoded
            downloadedAt = Date()
            errorMessage = nil
            if let cacheURL { try? data.write(to: cacheURL, options: .atomic) }
        } catch {
            errorMessage = elements.isEmpty ? "Couldn't download satellite orbits: \(error.localizedDescription)" : nil
        }
    }

    /// Every satellite's position from the observer, highest first.
    func positions(at date: Date, latitude: Double, longitude: Double, altitude: Double = 0) -> [SatellitePosition] {
        elements
            .filter { abs(date.timeIntervalSince($0.epoch)) < Self.maximumAge }
            .map { Orbit.position(of: $0, at: date, latitude: latitude, longitude: longitude, altitude: altitude) }
            .sorted { $0.elevation > $1.elevation }
    }

    private func loadCache() {
        guard let cacheURL, let data = try? Data(contentsOf: cacheURL),
              let decoded = try? OrbitalElements.decode(data) else { return }
        elements = decoded
        downloadedAt = (try? cacheURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
