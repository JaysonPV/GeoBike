import Foundation
import CoreLocation

struct Contract: Identifiable, Decodable, Equatable {
    let name: String
    let commercialName: String?
    let countryCode: String?
    let status: String?
    let cities: [ContractCity]?

    var id: String { name }
    var isActive: Bool {
        guard let s = status else { return true }
        let lower = s.lowercased()
        return lower == "active" || lower == "open"
    }
    var displayName: String { name }
    var brandName: String? { commercialName }

    // CLLocation of the first city in the contract, used for nearest-city GPS detection.
    var mainLocation: CLLocation? {
        guard let coord = cities?.first?.coordinates else { return nil }
        return CLLocation(latitude: coord.latitude, longitude: coord.longitude)
    }

    // Explicit CodingKeys so the null-safe init works with .convertFromSnakeCase.
    private enum CodingKeys: String, CodingKey {
        case name, commercialName, countryCode, status, cities
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name           = try  c.decode(String.self, forKey: .name)
        commercialName = try? c.decode(String.self, forKey: .commercialName)
        countryCode    = try? c.decode(String.self, forKey: .countryCode)
        status         = try? c.decode(String.self, forKey: .status)
        cities         = try? c.decode([ContractCity].self, forKey: .cities)
    }

    // Memberwise init used for the offline fallback contract.
    init(name: String, commercialName: String?, countryCode: String?, status: String?, cities: [ContractCity]?) {
        self.name           = name
        self.commercialName = commercialName
        self.countryCode    = countryCode
        self.status         = status
        self.cities         = cities
    }
}

struct ContractCity: Decodable, Equatable {
    let name: String
    let coordinates: ContractCoordinates?

    private enum CodingKeys: String, CodingKey { case name, coordinates }

    init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        name        = (try? c.decode(String.self, forKey: .name)) ?? ""
        coordinates = try? c.decode(ContractCoordinates.self, forKey: .coordinates)
    }
}

struct ContractCoordinates: Decodable, Equatable {
    let latitude: Double
    let longitude: Double
}
