import CoreLocation
import Observation
import UIKit

/// One point on the accuracy chart.
struct AccuracySample: Identifiable, Equatable {
    var id: Date { date }
    var date: Date
    var horizontal: Double
    var vertical: Double?
}

/// What the receiver is doing: no fix, 2D or 3D fix, or a fix that has gone stale.
enum FixStatus: Equatable {
    case off, searching, fix2D, fix3D, stale

    var title: String {
        switch self {
        case .off: "Off"
        case .searching: "Searching…"
        case .fix2D: "2D fix"
        case .fix3D: "3D fix"
        case .stale: "Fix lost"
        }
    }
}

/// Wraps CLLocationManager: GNSS position, compass heading, time to first fix and fix history.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var isPrecise = true
    private(set) var isRunning = false
    private(set) var location: CLLocation?
    private(set) var heading: CLHeading?
    private(set) var errorMessage: String?

    /// When the current session of updates started (app launch, return to foreground or Restart).
    private(set) var startedAt: Date?
    /// Seconds from `startedAt` to the first fresh fix of this session.
    private(set) var timeToFirstFix: TimeInterval?
    private(set) var updateCount = 0
    /// Updates per second over the last 10 seconds.
    private(set) var updateRate: Double?
    /// The last two minutes of accuracy readings.
    private(set) var history: [AccuracySample] = []

    let headingAvailable = CLLocationManager.headingAvailable()

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var recentUpdates: [Date] = []
    @ObservationIgnored private var orientationObserver: NSObjectProtocol?

    static let historyWindow: TimeInterval = 120
    /// A fix older than this is reported as lost.
    static let staleAfter: TimeInterval = 10

    override init() {
        super.init()
        authorization = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.headingFilter = 1
        isPrecise = manager.accuracyAuthorization == .fullAccuracy
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    // MARK: Control

    func start() {
        guard !isRunning else { return }
        switch authorization {
        case .notDetermined:
            manager.requestWhenInUseAuthorization() // starts from the delegate once granted
        case .authorizedWhenInUse, .authorizedAlways:
            isRunning = true
            startedAt = Date()
            timeToFirstFix = nil
            updateCount = 0
            updateRate = nil
            recentUpdates = []
            manager.startUpdatingLocation()
            if headingAvailable {
                observeOrientation()
                manager.startUpdatingHeading()
            }
        default:
            break
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        if let orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
            self.orientationObserver = nil
        }
    }

    /// Starts a fresh session so time to first fix and the chart begin again.
    func restart() {
        stop()
        location = nil
        history = []
        start()
    }

    func fixStatus(at now: Date = Date()) -> FixStatus {
        guard isRunning else { return .off }
        guard let location, location.horizontalAccuracy >= 0 else { return .searching }
        if now.timeIntervalSince(location.timestamp) > Self.staleAfter { return .stale }
        return location.verticalAccuracy > 0 ? .fix3D : .fix2D
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        isPrecise = manager.accuracyAuthorization == .fullAccuracy
        if isAuthorized {
            start()
        } else {
            stop()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for fix in locations where fix.horizontalAccuracy >= 0 {
            record(fix)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown { return } // transient: keep trying
        errorMessage = error.localizedDescription
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    // MARK: Bookkeeping

    private func record(_ fix: CLLocation) {
        errorMessage = nil
        location = fix
        updateCount += 1

        if timeToFirstFix == nil, let startedAt, fix.timestamp >= startedAt {
            timeToFirstFix = fix.timestamp.timeIntervalSince(startedAt)
        }

        let now = fix.timestamp
        recentUpdates.append(now)
        recentUpdates.removeAll { now.timeIntervalSince($0) > 10 }
        if recentUpdates.count >= 2, let first = recentUpdates.first {
            let span = now.timeIntervalSince(first)
            updateRate = span > 0 ? Double(recentUpdates.count - 1) / span : nil
        }

        history.append(AccuracySample(date: now, horizontal: fix.horizontalAccuracy,
                                      vertical: fix.verticalAccuracy > 0 ? fix.verticalAccuracy : nil))
        history.removeAll { now.timeIntervalSince($0.date) > Self.historyWindow }
    }

    /// Headings are relative to the top of the device as the user holds it.
    private func observeOrientation() {
        guard orientationObserver == nil else { return }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        updateHeadingOrientation()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateHeadingOrientation()
        }
    }

    private func updateHeadingOrientation() {
        switch UIDevice.current.orientation {
        case .portrait: manager.headingOrientation = .portrait
        case .portraitUpsideDown: manager.headingOrientation = .portraitUpsideDown
        case .landscapeLeft: manager.headingOrientation = .landscapeLeft
        case .landscapeRight: manager.headingOrientation = .landscapeRight
        default: break // face up/down or unknown: keep the last orientation
        }
    }
}
