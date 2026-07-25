import Foundation

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()
    private let defaults = UserDefaults.standard
    private let key = "SameShot.overlaySettings"

    func load() -> OverlaySettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(OverlaySettings.self, from: data) else {
            return .defaults
        }
        return settings
    }

    func save(_ settings: OverlaySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
