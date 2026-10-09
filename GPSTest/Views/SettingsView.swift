import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.coordinateFormat) private var format = CoordinateFormat.decimal
    @AppStorage(SettingsKey.units) private var units = UnitSystem.metric
    @AppStorage(SettingsKey.trueNorth) private var trueNorth = true
    @AppStorage(SettingsKey.keepScreenOn) private var keepScreenOn = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Coordinates") {
                    Picker("Format", selection: $format) {
                        ForEach(CoordinateFormat.allCases) { format in
                            VStack(alignment: .leading) {
                                Text(format.title)
                                Text(format.example).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Units") {
                    Picker("Units", selection: $units) {
                        ForEach(UnitSystem.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Picker("North reference", selection: $trueNorth) {
                        Text("True north").tag(true)
                        Text("Magnetic north").tag(false)
                    }
                    Toggle("Keep screen on", isOn: $keepScreenOn)
                } header: {
                    Text("Compass & display")
                }
                Section {
                    Text("Apple does not give apps access to the list of satellites, their signal strength (SNR) or their sky positions, so no iOS app can show a satellite signal chart or sky view. Everything iOS does expose is here: position, accuracy, altitude, speed, course, heading, time to first fix and fix rate.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Why no satellites?")
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
