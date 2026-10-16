import ActivityKit
import Foundation

struct BikeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var mechanicalBikes: Int
        var electricBikes: Int
        var stands: Int
        var isOpen: Bool
    }

    let stationName: String
    let stationID: Int
}
