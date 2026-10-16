import Foundation

// Simplified station model shared between the main app and the widget extension.
// Both targets must include this file.
struct WidgetStation: Codable, Identifiable {
    let id: Int
    let cleanName: String
    let bikes: Int
    let electricBikes: Int
    let stands: Int
    let isOpen: Bool
    let distanceMeters: Double?
    let latitude: Double
    let longitude: Double
}

struct WidgetData: Codable {
    let stations: [WidgetStation]
    let contractLabel: String   // e.g. "Vélam" or "Cergy-Pontoise"
    let updatedAt: Date
}

// Bridges the main app and the widget via a shared App Group.
// App Group must be enabled on BOTH targets with the id below.
final class WidgetDataManager {
    static let shared = WidgetDataManager()
    private init() {}

    static let appGroupID = "group.map.GeoBike"
    private let dataKey   = "geobike_widget_data_v1"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    func save(stations: [WidgetStation], contractLabel: String) {
        let payload = WidgetData(stations: stations, contractLabel: contractLabel, updatedAt: .now)
        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        defaults?.set(encoded, forKey: dataKey)
    }

    func load() -> WidgetData? {
        guard let raw    = defaults?.data(forKey: dataKey),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: raw)
        else { return nil }
        return decoded
    }
}
