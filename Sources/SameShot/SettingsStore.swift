import Foundation

@MainActor
final class SettingsStore {
    static let preferencesSuiteName = "studio.jackai.SameShot"
    static let shared = SettingsStore(
        defaults: UserDefaults(suiteName: preferencesSuiteName) ?? .standard,
        legacyDefaults: ["SameShot"].compactMap(UserDefaults.init(suiteName:))
    )

    private let defaults: UserDefaults
    private let legacyDefaults: [UserDefaults]
    private let key = "SameShot.overlaySettings"

    init(defaults: UserDefaults, legacyDefaults: [UserDefaults] = []) {
        self.defaults = defaults
        self.legacyDefaults = legacyDefaults
    }

    func load() -> OverlaySettings {
        if let settings = decodedSettings(from: defaults) {
            return settings
        }

        for legacyStore in legacyDefaults {
            guard let data = legacyStore.data(forKey: key),
                  let settings = try? JSONDecoder().decode(OverlaySettings.self, from: data) else {
                continue
            }
            defaults.set(data, forKey: key)
            return settings
        }

        return .defaults
    }

    func save(_ settings: OverlaySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    private func decodedSettings(from defaults: UserDefaults) -> OverlaySettings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(OverlaySettings.self, from: data)
    }
}
