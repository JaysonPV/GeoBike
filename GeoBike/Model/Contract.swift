import Foundation

struct Contract: Identifiable, Decodable, Equatable {
    let name: String
    let commercialName: String?
    let countryCode: String?
    let status: String?

    var id: String { name }
    // If no status field, assume active. Match case-insensitively for API version differences.
    var isActive: Bool {
        guard let s = status else { return true }
        let lower = s.lowercased()
        return lower == "active" || lower == "open"
    }
    var displayName: String { name }
    var brandName: String? { commercialName }
}
