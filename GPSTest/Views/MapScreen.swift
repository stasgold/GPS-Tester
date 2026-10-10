import CoreLocation
import MapKit
import SwiftUI

enum MapLayer: String, CaseIterable, Identifiable {
    case standard, hybrid, satellite

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var style: MapStyle {
        switch self {
        case .standard: .standard(elevation: .realistic)
        case .hybrid: .hybrid(elevation: .realistic)
        case .satellite: .imagery(elevation: .realistic)
        }
    }
}

/// Your position with its accuracy circle, saved waypoints and a line to the compass target.
struct MapScreen: View {
    @Environment(LocationService.self) private var location
    @Environment(WaypointStore.self) private var waypoints
    @AppStorage(SettingsKey.coordinateFormat) private var format = CoordinateFormat.decimal
    @AppStorage(SettingsKey.units) private var units = UnitSystem.metric
    @AppStorage("mapLayer") private var layer = MapLayer.standard
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var newWaypoint: NewWaypointRequest?
    @Environment(SatelliteCatalog.self) private var catalog
    @AppStorage("mapSatellites") private var showSatellites = false
    /// Moves the satellites along every 30 seconds while they are shown.
    @State private var satelliteTime = Date()

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                UserAnnotation()
                if let fix = location.location, fix.horizontalAccuracy > 0 {
                    MapCircle(center: fix.coordinate, radius: fix.horizontalAccuracy)
                        .foregroundStyle(.blue.opacity(0.12))
                        .stroke(.blue.opacity(0.5), lineWidth: 1)
                }
                ForEach(waypoints.waypoints) { waypoint in
                    Marker(waypoint.name, systemImage: waypoint.id == waypoints.targetID ? "scope" : "mappin",
                           coordinate: waypoint.coordinate)
                        .tint(waypoint.id == waypoints.targetID ? .red : .orange)
                }
                if let fix = location.location, let target = waypoints.target {
                    MapPolyline(coordinates: [fix.coordinate, target.coordinate])
                        .stroke(.red, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
                if showSatellites {
                    let positions = satellitePositions
                    ForEach(trackSegments(for: positions)) { segment in
                        MapPolyline(coordinates: segment.coordinates)
                            .stroke(segment.constellation.color.opacity(0.6), lineWidth: 1.5)
                    }
                    ForEach(positions) { satellite in
                        Annotation(satellite.label,
                                   coordinate: CLLocationCoordinate2D(latitude: satellite.latitude, longitude: satellite.longitude),
                                   anchor: .center) {
                            ConstellationMarker(constellation: satellite.constellation)
                                .fill(satellite.constellation.color)
                                .stroke(.white, lineWidth: satellite.elevation > 0 ? 1.5 : 0)
                                .frame(width: 14, height: 14)
                                .opacity(satellite.elevation > 0 ? 1 : 0.45)
                        }
                    }
                }
            }
            .mapStyle(layer.style)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
                MapScaleView()
            }
            .safeAreaInset(edge: .bottom) { infoPanel }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(showSatellites ? "Hide Satellites" : "Show Satellites",
                           systemImage: showSatellites ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right") {
                        showSatellites.toggle()
                        if showSatellites, let fix = location.location {
                            camera = .region(MKCoordinateRegion(center: fix.coordinate,
                                                                span: MKCoordinateSpan(latitudeDelta: 150, longitudeDelta: 360)))
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Map type", selection: $layer) {
                        ForEach(MapLayer.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
            .settingsToolbar()
            .newWaypointAlert(request: $newWaypoint)
            .task(id: showSatellites) {
                guard showSatellites else { return }
                await catalog.refresh()
                while !Task.isCancelled {
                    satelliteTime = Date()
                    try? await Task.sleep(for: .seconds(30))
                }
            }
        }
    }

    /// Every satellite's point on the Earth; those above your horizon are drawn solid.
    private var satellitePositions: [SatellitePosition] {
        let fix = location.location
        let positions = catalog.positions(at: satelliteTime, latitude: fix?.coordinate.latitude ?? 0,
                                          longitude: fix?.coordinate.longitude ?? 0)
        return fix == nil ? positions.map { var p = $0; p.elevation = -1; return p } : positions
    }

    private struct TrackSegment: Identifiable {
        var id: String
        var constellation: Constellation
        var coordinates: [CLLocationCoordinate2D]
    }

    /// The next hour's ground track of each satellite in view, split where it crosses the date line.
    private func trackSegments(for positions: [SatellitePosition]) -> [TrackSegment] {
        let visible = Set(positions.filter { $0.elevation > 0 }.map(\.id))
        var segments: [TrackSegment] = []
        for element in catalog.elements where visible.contains(element.noradID) {
            var current: [CLLocationCoordinate2D] = []
            var part = 0
            for point in Orbit.groundTrack(of: element, from: satelliteTime) {
                if let last = current.last, abs(point.longitude - last.longitude) > 180 {
                    segments.append(TrackSegment(id: "\(element.noradID)-\(part)", constellation: element.constellation,
                                                 coordinates: current))
                    current = []
                    part += 1
                }
                current.append(CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
            }
            if current.count > 1 {
                segments.append(TrackSegment(id: "\(element.noradID)-\(part)", constellation: element.constellation,
                                             coordinates: current))
            }
        }
        return segments
    }

    @ViewBuilder
    private var infoPanel: some View {
        if let fix = location.location {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(CoordinateFormatter.lines(latitude: fix.coordinate.latitude,
                                                      longitude: fix.coordinate.longitude, format: format), id: \.self) {
                        Text($0)
                    }
                    .font(.callout.monospacedDigit())
                    Text("±\(units.length(fix.horizontalAccuracy))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let target = waypoints.target {
                        let distance = Geodesy.distance(fromLatitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                                        toLatitude: target.latitude, longitude: target.longitude)
                        Label("\(target.name): \(units.distance(distance))", systemImage: "scope")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
                Button("Save", systemImage: "mappin.and.ellipse") {
                    newWaypoint = NewWaypointRequest(fix: fix, suggestedName: waypoints.suggestedName)
                }
                .buttonStyle(.borderedProminent)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Save current location as a waypoint")
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

extension Waypoint {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
