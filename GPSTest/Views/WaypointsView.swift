import CoreLocation
import SwiftUI

/// Saved positions. Tap one to navigate to it with the compass and map.
struct WaypointsView: View {
    @Environment(LocationService.self) private var location
    @Environment(WaypointStore.self) private var waypoints
    @AppStorage(SettingsKey.coordinateFormat) private var format = CoordinateFormat.decimal
    @AppStorage(SettingsKey.units) private var units = UnitSystem.metric
    @State private var newWaypoint: NewWaypointRequest?
    @State private var showManualEntry = false
    @State private var renaming: Waypoint?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if waypoints.waypoints.isEmpty {
                    ContentUnavailableView {
                        Label("No Waypoints", systemImage: "mappin.slash")
                    } description: {
                        Text("Save your current position, or enter coordinates, then tap a waypoint to navigate back to it.")
                    } actions: {
                        Button("Save Current Location") { saveCurrent() }
                            .buttonStyle(.borderedProminent)
                            .disabled(location.location == nil)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Waypoints")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Add", systemImage: "plus") {
                        Button("Save Current Location", systemImage: "location.fill") { saveCurrent() }
                            .disabled(location.location == nil)
                        Button("Enter Coordinates", systemImage: "keyboard") { showManualEntry = true }
                    }
                }
            }
            .settingsToolbar()
            .newWaypointAlert(request: $newWaypoint)
            .sheet(isPresented: $showManualEntry) { ManualWaypointSheet() }
            .alert("Rename Waypoint", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    if let renaming { waypoints.rename(renaming.id, to: renameText) }
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(waypoints.waypoints) { waypoint in
                Button {
                    waypoints.targetID = waypoints.targetID == waypoint.id ? nil : waypoint.id
                } label: {
                    row(waypoint)
                }
                .tint(.primary)
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) { waypoints.delete([waypoint.id]) }
                    Button("Rename", systemImage: "pencil") { startRename(waypoint) }
                }
                .contextMenu {
                    Button(waypoint.id == waypoints.targetID ? "Stop Navigating" : "Navigate", systemImage: "scope") {
                        waypoints.targetID = waypoints.targetID == waypoint.id ? nil : waypoint.id
                    }
                    Button("Rename", systemImage: "pencil") { startRename(waypoint) }
                    Button("Copy Coordinates", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = CoordinateFormatter.singleLine(latitude: waypoint.latitude,
                                                                                     longitude: waypoint.longitude, format: format)
                    }
                    ShareLink(item: shareText(waypoint)) { Label("Share", systemImage: "square.and.arrow.up") }
                    Link(destination: ShareText.mapsLink(latitude: waypoint.latitude, longitude: waypoint.longitude, name: waypoint.name)) {
                        Label("Open in Maps", systemImage: "map")
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) { waypoints.delete([waypoint.id]) }
                }
            }
            .onDelete { offsets in
                waypoints.delete(Set(offsets.map { waypoints.waypoints[$0].id }))
            }
        }
    }

    private func row(_ waypoint: Waypoint) -> some View {
        HStack(spacing: 12) {
            Image(systemName: waypoint.id == waypoints.targetID ? "scope" : "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(waypoint.id == waypoints.targetID ? .red : .orange)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(waypoint.name).font(.headline)
                Text(CoordinateFormatter.singleLine(latitude: waypoint.latitude, longitude: waypoint.longitude, format: format))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let fix = location.location {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(units.distance(Geodesy.distance(fromLatitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                                         toLatitude: waypoint.latitude, longitude: waypoint.longitude)))
                        .font(.subheadline.monospacedDigit())
                    Text(Format.bearing(Geodesy.bearing(fromLatitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                                        toLatitude: waypoint.latitude, longitude: waypoint.longitude)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityHint(waypoint.id == waypoints.targetID ? "Stops navigating" : "Navigates to this waypoint")
    }

    private func saveCurrent() {
        guard let fix = location.location else { return }
        newWaypoint = NewWaypointRequest(fix: fix, suggestedName: waypoints.suggestedName)
    }

    private func startRename(_ waypoint: Waypoint) {
        renameText = waypoint.name
        renaming = waypoint
    }

    private func shareText(_ waypoint: Waypoint) -> String {
        ShareText.position(latitude: waypoint.latitude, longitude: waypoint.longitude, altitude: waypoint.altitude,
                           accuracy: nil, name: waypoint.name, format: format, units: units)
    }
}

/// A pending "save this fix as a waypoint" prompt.
struct NewWaypointRequest: Identifiable {
    let id = UUID()
    var fix: CLLocation
    var suggestedName: String
}

private struct NewWaypointAlert: ViewModifier {
    @Environment(WaypointStore.self) private var waypoints
    @Binding var request: NewWaypointRequest?
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert("Save Waypoint", isPresented: Binding(get: { request != nil }, set: { if !$0 { request = nil } }),
                   presenting: request) { request in
                TextField(request.suggestedName, text: $name)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    let fix = request.fix
                    waypoints.add(name: name, latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                  altitude: fix.verticalAccuracy > 0 ? fix.altitude : nil)
                }
            } message: { request in
                Text(String(format: "%.6f, %.6f (±%.0f m)", request.fix.coordinate.latitude,
                            request.fix.coordinate.longitude, request.fix.horizontalAccuracy))
            }
            .onChange(of: request?.id) { name = "" }
    }
}

extension View {
    func newWaypointAlert(request: Binding<NewWaypointRequest?>) -> some View {
        modifier(NewWaypointAlert(request: request))
    }
}

/// Add a waypoint by typing decimal coordinates.
private struct ManualWaypointSheet: View {
    @Environment(WaypointStore.self) private var waypoints
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(waypoints.suggestedName, text: $name)
                } header: {
                    Text("Name")
                }
                Section {
                    TextField("Latitude, e.g. 51.500729", text: $latitude)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude, e.g. -0.124625", text: $longitude)
                        .keyboardType(.numbersAndPunctuation)
                } header: {
                    Text("Decimal degrees")
                } footer: {
                    Text("Negative latitudes are south of the equator; negative longitudes are west of Greenwich.")
                }
            }
            .navigationTitle("Enter Coordinates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let coordinate = WaypointInput.parse(latitude: latitude, longitude: longitude) {
                            waypoints.add(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
                            dismiss()
                        }
                    }
                    .disabled(WaypointInput.parse(latitude: latitude, longitude: longitude) == nil)
                }
            }
        }
    }
}
