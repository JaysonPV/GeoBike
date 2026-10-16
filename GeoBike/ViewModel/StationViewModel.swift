import Foundation
import CoreLocation
import UIKit
import Combine
import WidgetKit
import ActivityKit

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
    @Published var isTrackingStation = false

    // Contract / city
    @Published var availableContracts: [Contract] = []
    @Published var selectedContract: Contract?
    @Published var isLoadingContracts = false
    @Published var cityUnavailableMessage: String?

    // MARK: - Dependencies
    let location: LocationService
    private let userService: UserServiceProtocol
    private let notifications = NotificationService.shared
    private var refreshTask: Task<Void, Never>?
    private var liveActivity: Activity<BikeActivityAttributes>?
    private var trackedStationID: Int?

    // MARK: - Init
    init() {
        self.location = LocationService()
        self.userService = FirebaseUserService()
        Task { await loadUser() }
    }

    // MARK: - Setup (called once at launch)
    func setup() async {
        async let contractLoad: () = loadContractsAndAutoDetect()
        async let userLoad: () = { @MainActor in }()
        _ = await (contractLoad, userLoad)
        await fetchStations()
    }

    // MARK: - Contracts
    func loadContractsAndAutoDetect() async {
        do {
            let contracts = try await JCDecauxAPI.shared.fetchContracts()
            availableContracts = contracts.sorted { $0.displayName < $1.displayName }
            Task { await backgroundFilterEmptyContracts() }
        } catch {
            #if DEBUG
            print("[ViewModel] loadContractsAndAutoDetect error: \(error)")
            #endif
            availableContracts = [Contract(name: "amiens", commercialName: "Vélam", countryCode: "FR", status: "Active", cities: nil)]
        }

        // Restore city the user previously chose manually
        if let savedName = UserDefaults.standard.string(forKey: "selected_contract"),
           let saved = availableContracts.first(where: { $0.name.localizedCaseInsensitiveCompare(savedName) == .orderedSame }) {
            selectedContract = saved
            return
        }

        // Auto-detect from GPS
        await autoDetectContract()

        // Last resort: pick the first available contract
        if selectedContract == nil {
            selectedContract = availableContracts.first
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
                Task { await backgroundFilterEmptyContracts() }
            }
        } catch {
            #if DEBUG
            print("[ViewModel] refreshContracts error: \(error)")
            #endif
        }
    }

    func selectContract(_ contract: Contract) async {
        let previousContract = selectedContract
        let previousStations = allStations

        selectedContract = contract
        UserDefaults.standard.set(contract.name, forKey: "selected_contract")
        await fetchStations()

        if allStations.isEmpty && !previousStations.isEmpty {
            selectedContract = previousContract
            if let prev = previousContract {
                UserDefaults.standard.set(prev.name, forKey: "selected_contract")
            }
            allStations = previousStations
            cityUnavailableMessage = "\(contract.displayName.capitalized) ne dispose pas de stations actives en ce moment. Retour sur \((previousContract?.displayName ?? "la ville précédente").capitalized)."
            // Remember immediately so it won't reappear in the picker
            var unavailable = unavailableContractNames
            unavailable.insert(contract.name)
            unavailableContractNames = unavailable
            availableContracts = availableContracts.filter { $0.name != contract.name }
        }
    }

    // Finds the nearest contract by comparing city coordinates from the API response.
    // Falls back to reverse geocoding if the API returned no coordinates.
    private func autoDetectContract() async {
        guard let userLocation = location.userLocation else { return }

        let nearest = availableContracts
            .compactMap { contract -> (Contract, Double)? in
                guard let loc = contract.mainLocation else { return nil }
                return (contract, userLocation.distance(from: loc))
            }
            .min { $0.1 < $1.1 }
            .map { $0.0 }

        if let nearest {
            selectedContract = nearest
            return
        }

        // Fallback: reverse geocoding when contracts carry no coordinates
        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(userLocation),
              let city = placemarks.first?.locality else { return }

        selectedContract = availableContracts.first {
            $0.name.localizedCaseInsensitiveContains(city) ||
            city.localizedCaseInsensitiveContains($0.name)
        }
    }

    // Re-runs GPS detection after onboarding grants location permission.
    // No-op if the user has already manually chosen a city.
    func refreshDetectionIfNeeded() async {
        guard UserDefaults.standard.string(forKey: "selected_contract") == nil else { return }
        await autoDetectContract()
        if selectedContract != nil { await fetchStations() }
    }

    // MARK: - Contract filtering (hide cities with no stations)

    private var unavailableContractNames: Set<String> {
        get {
            guard let data = UserDefaults.standard.data(forKey: "unavailable_contracts_v1"),
                  let set = try? JSONDecoder().decode(Set<String>.self, from: data) else { return [] }
            return set
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "unavailable_contracts_v1")
            }
        }
    }

    private func applyContractFilter() {
        let unavailable = unavailableContractNames
        guard !unavailable.isEmpty else { return }
        availableContracts = availableContracts.filter { !unavailable.contains($0.name) }
    }

    // Checks every contract for stations in batches of 5 concurrently. Result cached 24h.
    private func backgroundFilterEmptyContracts() async {
        applyContractFilter()

        if let date = UserDefaults.standard.object(forKey: "unavailable_contracts_date") as? Date,
           Date().timeIntervalSince(date) < 86400 { return }

        let contracts = availableContracts
        guard !contracts.isEmpty else { return }
        var emptyNames = Set<String>()

        for batchStart in stride(from: 0, to: contracts.count, by: 5) {
            let batch = Array(contracts[batchStart..<min(batchStart + 5, contracts.count)])
            await withTaskGroup(of: (String, Bool).self) { group in
                for contract in batch {
                    group.addTask {
                        let stations = try? await JCDecauxAPI.shared.fetchStations(contract: contract.name)
                        return (contract.name, stations?.isEmpty ?? true)
                    }
                }
                for await (name, isEmpty) in group {
                    if isEmpty { emptyNames.insert(name) }
                }
            }
        }

        UserDefaults.standard.set(Date(), forKey: "unavailable_contracts_date")
        unavailableContractNames = emptyNames

        let selected = selectedContract?.name
        if !emptyNames.isEmpty {
            availableContracts = availableContracts
                .filter { !emptyNames.contains($0.name) || $0.name == selected }
                .sorted { $0.displayName < $1.displayName }
        }
    }

    // MARK: - Filtered Stations
    var filteredStations: [Station] {
        var stations = allStations

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

    var alertedStations: [Station] {
        allStations.filter { alertedStationIDs.contains($0.number) }
    }

    var activeAlertsCount: Int {
        alertedStationIDs.filter { id in allStations.contains { $0.number == id } }.count
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
        guard let contractName = selectedContract?.name else { return }
        isLoading = true
        errorMessage = nil
        do {
            let stations = try await JCDecauxAPI.shared.fetchStations(contract: contractName)
            allStations = stations.sorted { $0.name < $1.name }
            lastRefresh = Date()
            userService.logEvent("stations_refreshed", params: ["count": stations.count, "city": contractName])
            checkAlertsAfterRefresh()
            updateWidget(contractName: contractName)
            if let id = trackedStationID,
               let tracked = allStations.first(where: { $0.number == id }) {
                await updateLiveActivity(for: tracked)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // Writes the nearest open stations to the shared App Group so the widget can read them.
    private func updateWidget(contractName: String) {
        let userLoc = location.userLocation
        let sorted: [Station]
        if let loc = userLoc {
            sorted = allStations.filter(\.isOpen).sorted { $0.distance(from: loc) < $1.distance(from: loc) }
        } else {
            sorted = allStations.filter(\.isOpen)
        }
        let widgetStations = sorted.prefix(5).map { s in
            WidgetStation(
                id: s.number,
                cleanName: s.cleanName,
                bikes: s.mainStands.availabilities.bikes,
                electricBikes: s.mainStands.availabilities.electricalBikes,
                stands: s.mainStands.availabilities.stands,
                isOpen: s.isOpen,
                distanceMeters: userLoc.map { s.distance(from: $0) },
                latitude: s.position.latitude,
                longitude: s.position.longitude
            )
        }
        let label = selectedContract?.commercialName ?? selectedContract?.name ?? contractName
        WidgetDataManager.shared.save(stations: Array(widgetStations), contractLabel: label)
        WidgetCenter.shared.reloadAllTimelines()
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

    // MARK: - Live Activity

    func isTracking(_ station: Station) -> Bool {
        trackedStationID == station.number && isTrackingStation
    }

    func startLiveActivity(for station: Station) async {
        // End any existing live activity first
        if let existing = liveActivity {
            await existing.end(nil, dismissalPolicy: .immediate)
            liveActivity = nil
            isTrackingStation = false
            trackedStationID = nil
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = BikeActivityAttributes(stationName: station.cleanName, stationID: station.number)
        let contentState = BikeActivityAttributes.ContentState(
            bikes: station.mainStands.availabilities.bikes,
            electricBikes: station.mainStands.availabilities.electricalBikes,
            stands: station.mainStands.availabilities.stands,
            isOpen: station.isOpen
        )
        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: .now.addingTimeInterval(600))
            )
            trackedStationID = station.number
            isTrackingStation = true
        } catch {
            #if DEBUG
            print("[LiveActivity] start error: \(error)")
            #endif
        }
    }

    func endLiveActivity() {
        guard let activity = liveActivity else { return }
        Task { await activity.end(nil, dismissalPolicy: .default) }
        liveActivity = nil
        isTrackingStation = false
        trackedStationID = nil
    }

    private func updateLiveActivity(for station: Station) async {
        guard let activity = liveActivity,
              activity.activityState == .active else {
            liveActivity = nil
            isTrackingStation = false
            trackedStationID = nil
            return
        }
        let newState = BikeActivityAttributes.ContentState(
            bikes: station.mainStands.availabilities.bikes,
            electricBikes: station.mainStands.availabilities.electricalBikes,
            stands: station.mainStands.availabilities.stands,
            isOpen: station.isOpen
        )
        await activity.update(.init(state: newState, staleDate: .now.addingTimeInterval(600)))
    }

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

    func saveProfile() {
        Task { await userService.saveUser(appUser) }
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
