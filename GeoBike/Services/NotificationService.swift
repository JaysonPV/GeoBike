import Foundation
import UserNotifications

final class NotificationService: Sendable {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleAvailabilityAlert(for station: Station) {
        let content = UNMutableNotificationContent()
        content.title = "Vélos disponibles !"
        content.body = "\(station.cleanName) a \(station.mainStands.availabilities.bikes) vélo(s) disponible(s)."
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "station-\(station.id)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleLowStockAlert(for station: Station, threshold: Int = 2) {
        guard station.mainStands.availabilities.bikes <= threshold && station.mainStands.availabilities.bikes > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Derniers vélos !"
        content.body = "Il ne reste que \(station.mainStands.availabilities.bikes) vélo(s) à \(station.cleanName)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "low-\(station.id)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelAlert(for stationID: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["station-\(stationID)", "low-\(stationID)"]
        )
    }
}
