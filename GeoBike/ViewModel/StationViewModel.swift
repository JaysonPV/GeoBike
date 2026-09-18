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
    @Published var selectedFilter: AvailabilityFilter = .all
    @Published var appUser: AppUser = AppUser(uid: "local")
    @Published var lastRefresh: Date?
    @Published var alertedStationIDs: Set<Int> = []

    // Contract / city
    @Published var availableContracts: [Contract] = []
    @Published var selectedContract: Contract?
    @Published var isLoadingContracts = false

    // MARK: - Dependencies
    let location: LocationService
    private let userService: UserServiceProtocol
    private let notifications = NotificationService.shared
    private var refreshTask: Task<Void, Never>?

    // MARK: - Init
    init() {
        self.location = LocationService()
        self.userService = FirebaseUserService()
        Task { await loadUser() }
    }

    // MARK: - Setup (called once at launch)
    func setup() async {
        // Load contracts and stations concurrently
        async let contractLoad: () = loadContractsAndAutoDetect()
        async let userLoad: () = { @MainActor in }() // user already loading in init
        _ = await (contractLoad, userLoad)
        await fetchStations()
    }

    // MARK: - Contracts
    func loadContractsAndAutoDetect() async {
        do {
            let contracts = try await JCDecauxAPI.shared.fetchContracts()
            availableContracts = contracts.sorted { $0.displayName < $1.displayName }
        } catch {
            #if DEBUG
            print("[ViewModel] loadContractsAndAutoDetect error: \(error)")
            #endif
            availableContracts = [Contract(name: "Amiens", commercialName: "Vélam", countryCode: "FR", status: "Active")]
        }

        // Restore saved city
        if let savedName = UserDefaults.standard.string(forKey: "selected_contract"),
           let saved = availableContracts.first(where: { $0.name == savedName }) {
            selectedContract = saved
            return
        }

        // Try GPS auto-detect
        await autoDetectContract()

        // Fallback to Amiens
        if selectedContract == nil {
            selectedContract = availableContracts.first(where: { $0.name == "Amiens" })
        }
    }

    // Refreshes the contracts list without resetting the selected city.
    func refreshContracts() async {
        isLoadingContracts = true
        defer { isLoadingContracts = false }
        do {
            let contracts = try await JCDecauxAPI.shared.fetchContracts()
            if !contracts.isEmpty {
                availableContracts = contracts.sorted { $0.displayName < $1.displayName }
            } else if availableContracts.isEmpty {
                availableContracts = [Contract(name: "Amiens", commercialName: "Vélam", countryCode: "FR", status: "Active")]
            }
        } catch {
            #if DEBUG
            print("[ViewModel] refreshContracts error: \(error)")
            #endif
            if availableContracts.isEmpty {
                availableContracts = [Contract(name: "Amiens", commercialName: "Vélam", countryCode: "FR", status: "Active")]
            }
        }
    }

    func selectContract(_ contract: Contract) async {
        let previousContract = selectedContract
        let previousStations = allStations

        selectedContract = contract
        UserDefaults.standard.set(contract.name, forKey: "selected_contract")
        await fetchStations()

        if allStations.isEmpty && !previousStations.isEmpty {
            // No stations returned — revert to the previous city
            selectedContract = previousContract
            if let prev = previousContract {
                UserDefaults.standard.set(prev.name, forKey: "selected_contract")
            }
            allStations = previousStations
            errorMessage = "\(contract.displayName) ne dispose pas de stations actives pour le moment."
        }
    }

    private func autoDetectContract() async {
        guard let location = location.userLocation else { return }
        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
              let city = placemarks.first?.locality else { return }

        let match = availableContracts.first {
            $0.name.localizedCaseInsensitiveContains(city) ||
            city.localizedCaseInsensitiveContains($0.name)
        }
        if let match { selectedContract = match }
    }

    // MARK: - Filtered Stations
    var filteredStations: [Station] {
        var stations = allStations

        if !appUser.favoriteIDs.isEmpty && selectedFilter == .all {
            // favorites shown in dedicated tab — no extra filter here
        }

        switch selectedFilter {
        case .all: break
        case .available: stations = stations.filter { $0.mainStands.availabilities.bikes > 0 && $0.isOpen }
        case .electric:  stations = stations.filter { $0.mainStands.availabilities.electricalBikes > 0 }
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
        let contractName = selectedContract?.name ?? "Amiens"
        isLoading = true
        errorMessage = nil
        do {
            let stations = try await JCDecauxAPI.shared.fetchStations(contract: contractName)
            allStations = stations.sorted { $0.name < $1.name }
            lastRefresh = Date()
            userService.logEvent("stations_refreshed", params: ["count": stations.count, "city": contractName])
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if appUser.favoriteIDs.contains(station.number) {
            appUser.favoriteIDs.remove(station.number)
        } else {
            appUser.favoriteIDs.insert(station.number)
            userService.logEvent("station_favorited", params: ["station_id": station.number])
        }
        Task { await userService.saveUser(appUser) }
    }

    func isFavorite(_ station: Station) -> Bool { appUser.favoriteIDs.contains(station.number) }

    // MARK: - Alerts
    func toggleAlert(for station: Station) {
        let generator = UINotificationFeedbackGenerator()
        if alertedStationIDs.contains(station.number) {
            alertedStationIDs.remove(station.number)
            notifications.cancelAlert(for: station.number)
            generator.notificationOccurred(.warning)
        } else {
            Task { await notifications.requestPermission() }
            alertedStationIDs.insert(station.number)
            if station.mainStands.availabilities.bikes > 0 {
                notifications.scheduleAvailabilityAlert(for: station)
            }
            generator.notificationOccurred(.success)
        }
        appUser.alertedStationIDs = alertedStationIDs
        Task { await userService.saveUser(appUser) }
    }

    func hasAlert(_ station: Station) -> Bool { alertedStationIDs.contains(station.number) }

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
    case all       = "Tous"
    case available = "Disponibles"
    case electric  = "Électriques"
    case hasStands = "Places libres"

    var icon: String {
        switch self {
        case .all:       return "bicycle"
        case .available: return "checkmark.circle"
        case .electric:  return "bolt.fill"
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
