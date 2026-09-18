import Foundation
import CoreLocation

struct Station: Identifiable, Decodable, Equatable {
    let number: Int
    let name: String
    let address: String
    let status: String
    let position: Position
    let mainStands: MainStands

    var id: Int { number }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: position.latitude, longitude: position.longitude)
    }

    var cleanName: String {
        if let index = name.firstIndex(of: "-") {
            return name[name.index(after: index)...].trimmingCharacters(in: .whitespaces).capitalized
        }
        return name.capitalized
    }

    var isOpen: Bool { status == "OPEN" }

    var availabilityRatio: Double {
        guard mainStands.capacity > 0 else { return 0 }
        return Double(mainStands.availabilities.bikes) / Double(mainStands.capacity)
    }

    var availabilityLevel: AvailabilityLevel {
        let bikes = mainStands.availabilities.bikes
        if !isOpen { return .closed }
        if bikes == 0 { return .empty }
        if bikes <= 2 { return .low }
        if bikes <= 5 { return .medium }
        return .good
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        let stationLocation = CLLocation(latitude: position.latitude, longitude: position.longitude)
        return location.distance(from: stationLocation)
    }

    func formattedDistance(from location: CLLocation?) -> String? {
        guard let location else { return nil }
        let meters = distance(from: location)
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }

    struct Position: Equatable, Decodable {
        let latitude: Double
        let longitude: Double
    }

    struct MainStands: Equatable, Decodable {
        let capacity: Int
        let availabilities: Availabilities

        private enum CodingKeys: String, CodingKey { case capacity, availabilities }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            capacity      = (try? c.decode(Int.self, forKey: .capacity)) ?? 0
            availabilities = try c.decode(Availabilities.self, forKey: .availabilities)
        }
    }

    struct Availabilities: Equatable, Decodable {
        let bikes: Int
        let stands: Int
        let mechanicalBikes: Int
        let electricalBikes: Int

        private enum CodingKeys: String, CodingKey {
            case bikes, stands, mechanicalBikes, electricalBikes
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            bikes          = (try? c.decode(Int.self, forKey: .bikes)) ?? 0
            stands         = (try? c.decode(Int.self, forKey: .stands)) ?? 0
            mechanicalBikes  = (try? c.decode(Int.self, forKey: .mechanicalBikes)) ?? 0
            electricalBikes  = (try? c.decode(Int.self, forKey: .electricalBikes)) ?? 0
        }
    }

    // MARK: - Decodable (null-safe custom init)

    private enum CodingKeys: String, CodingKey {
        case number, name, address, status, position, mainStands
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        number       = try c.decode(Int.self, forKey: .number)
        name         = try c.decode(String.self, forKey: .name)
        address      = (try? c.decode(String.self, forKey: .address)) ?? ""
        status       = (try? c.decode(String.self, forKey: .status)) ?? "CLOSED"
        position     = try c.decode(Position.self, forKey: .position)
        mainStands   = try c.decode(MainStands.self, forKey: .mainStands)
    }

    enum AvailabilityLevel {
        case closed, empty, low, medium, good

        var color: String {
            switch self {
            case .closed: return "gray"
            case .empty: return "red"
            case .low: return "orange"
            case .medium: return "yellow"
            case .good: return "green"
            }
        }

        var label: String {
            switch self {
            case .closed: return "Fermée"
            case .empty: return "Aucun vélo"
            case .low: return "Quasi vide"
            case .medium: return "Quelques vélos"
            case .good: return "Disponible"
            }
        }
    }
}
