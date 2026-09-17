import Foundation

struct AppUser: Codable, Equatable {
    var uid: String
    var displayName: String?
    var email: String?
    var favoriteIDs: Set<Int>
    var alertedStationIDs: Set<Int>
    var totalRides: Int
    var joinDate: Date

    init(uid: String) {
        self.uid = uid
        self.favoriteIDs = []
        self.alertedStationIDs = []
        self.totalRides = 0
        self.joinDate = Date()
    }
}
