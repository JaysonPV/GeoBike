import Foundation
import CoreLocation
import UIKit
import Combine

@MainActor
final class StationViewModel: ObservableObject {

    // MARK: - Published State
    @Published var allStations: [Station] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var showOnlyFavorites = false
    @Published var selectedFilter: AvailabilityFilter = .all
    @Published var appUser: AppUser = AppUser(uid: "local")
    @Published var lastRefresh: Date?
    @Published var alertedStationIDs: Set<Int> = []

    // MARK: - Dependencies
    let location: LocationService
    private let userService: FirebaseUserService()
    private let notifications = NotificationService.shared
    private var refreshTask: Task<Void, Never>?

    // MARK: - Init
    init() {
        self.location = LocationService()
        self.userService = LocalUserService()
        Task { await loadUser() }
    }

    // MARK: - Filtered Stations
    var filteredStations: [Station] {
        var stations = allStations

        if showOnlyFavorites {
            stations = stations.filter { appUser.favoriteIDs.contains($0.number) }
        }

        switch selectedFilter {
        case .all: break
        case .available: stations = stations.filter { $0.mainStands.availabilities.bikes > 0 && $0.isOpen }
        case .electric: stations = stations.filter { $0.mainStands.availabilities.electricalBikes > 0 }
        case .hasStands: stations = stations.filter { $0.mainStands.availabilities.stands > 0 }
        }

        if !searchText.isEmpty {
            stations = stations.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        return stations
    }

    var nearbyStations: [Station] {
        guard let loc = location.userLocation else { return [] }
        return allStations
            .filter { $0.isOpen }
            .sorted { $0.distance(from: loc) < $1.distance(from: loc) }
            .prefix(10)
            .map { $0 }
    }

    var favoriteStations: [Station] {
        allStations.filter { appUser.favoriteIDs.contains($0.number) }
    }

    var stats: AppStats {
        AppStats(
            totalStations: allStations.count,
            openStations: allStations.filter(\.isOpen).count,
            totalBikes: allStations.reduce(0) { $0 + $1.mainStands.availabilities.bikes },
            totalElectric: allStations.reduce(0) { $0 + $1.mainStands.availabilities.electricalBikes }
        )
    }

    // MARK: - API
    func fetchStations() async {
        isLoading = true
        errorMessage = nil
        do {
            let stations = try await JCDecauxAPI.shared.fetchStations(contract: "Amiens")
            allStations = stations.sorted { $0.name < $1.name }
            lastRefresh = Date()
            userService.logEvent("stations_refreshed", params: ["count": stations.count])
            checkAlertsAfterRefresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startAutoRefresh(interval: TimeInterval = 60) {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if !Task.isCancelled { await fetchStations() }
            }
        }
    }

    func stopAutoRefresh() { refreshTask?.cancel() }

    // MARK: - Favorites
    func toggleFavorite(for station: Station) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        if appUser.favoriteIDs.contains(station.number) {
            appUser.favoriteIDs.remove(station.number)
        } else {
            appUser.favoriteIDs.insert(station.number)
            userService.logEvent("station_favorited", params: ["station_id": station.number, "name": station.cleanName])
        }
        Task { await userService.saveUser(appUser) }
    }

    func isFavorite(_ station: Station) -> Bool {
        appUser.favoriteIDs.contains(station.number)
    }

    // MARK: - Availability Alerts
    func toggleAlert(for station: Station) {
        let notification = UINotificationFeedbackGenerator()
        if alertedStationIDs.contains(station.number) {
            alertedStationIDs.remove(station.number)
            notifications.cancelAlert(for: station.number)
            notification.notificationOccurred(.warning)
        } else {
            Task { await notifications.requestPermission() }
            alertedStationIDs.insert(station.number)
            if station.mainStands.availabilities.bikes > 0 {
                notifications.scheduleAvailabilityAlert(for: station)
            }
            notification.notificationOccurred(.success)
        }
        appUser.alertedStationIDs = alertedStationIDs
        Task { await userService.saveUser(appUser) }
    }

    func hasAlert(_ station: Station) -> Bool {
        alertedStationIDs.contains(station.number)
    }

    private func checkAlertsAfterRefresh() {
        for station in allStations where alertedStationIDs.contains(station.number) {
            if station.mainStands.availabilities.bikes > 0 {
                notifications.scheduleAvailabilityAlert(for: station)
            }
        }
    }

    // MARK: - User
    private func loadUser() async {
        appUser = await userService.loadUser()
        alertedStationIDs = appUser.alertedStationIDs
    }
}

// MARK: - Supporting Types
enum AvailabilityFilter: String, CaseIterable {
    case all = "Tous"
    case available = "Disponibles"
    case electric = "Électriques"
    case hasStands = "Places libres"

    var icon: String {
        switch self {
        case .all: return "bicycle"
        case .available: return "checkmark.circle"
        case .electric: return "bolt.fill"
        case .hasStands: return "p.square.fill"
        }
    }
}

struct AppStats {
    let totalStations: Int
    let openStations: Int
    let totalBikes: Int
    let totalElectric: Int
}
