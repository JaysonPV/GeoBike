import Foundation

struct AppUser: Codable, Equatable {
    var uid: String
    var displayName: String?
    var email: String?
    var favoriteIDs: Set<Int>
    var alertedStationIDs: Set<Int>
    var totalRides: Int
    var totalDistanceMeters: Double
    var joinDate: Date
    var avatarSymbol: String?
    var avatarColorName: String?

    init(uid: String) {
        self.uid = uid
        self.favoriteIDs = []
        self.alertedStationIDs = []
        self.totalRides = 0
        self.totalDistanceMeters = 0
        self.joinDate = Date()
    }

    // Custom decoder so existing stored documents that predate totalDistanceMeters
    // decode cleanly instead of throwing a missing-key error.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid                 = try c.decode(String.self, forKey: .uid)
        displayName         = try? c.decode(String.self, forKey: .displayName)
        email               = try? c.decode(String.self, forKey: .email)
        favoriteIDs         = (try? c.decode(Set<Int>.self, forKey: .favoriteIDs)) ?? []
        alertedStationIDs   = (try? c.decode(Set<Int>.self, forKey: .alertedStationIDs)) ?? []
        totalRides          = (try? c.decode(Int.self, forKey: .totalRides)) ?? 0
        totalDistanceMeters = (try? c.decode(Double.self, forKey: .totalDistanceMeters)) ?? 0
        joinDate            = (try? c.decode(Date.self, forKey: .joinDate)) ?? Date()
        avatarSymbol        = try? c.decode(String.self, forKey: .avatarSymbol)
        avatarColorName     = try? c.decode(String.self, forKey: .avatarColorName)
    }
}
