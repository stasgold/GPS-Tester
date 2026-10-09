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
                    Picker("Map type", selection: $layer) {
                        ForEach(MapLayer.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
            .settingsToolbar()
            .newWaypointAlert(request: $newWaypoint)
        }
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
