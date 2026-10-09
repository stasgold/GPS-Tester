import Foundation

/// UserDefaults keys for @AppStorage, in one place so every screen reads the same setting.
enum SettingsKey {
    static let coordinateFormat = "coordinateFormat"
    static let units = "units"
    static let trueNorth = "trueNorth"
    static let keepScreenOn = "keepScreenOn"
}
