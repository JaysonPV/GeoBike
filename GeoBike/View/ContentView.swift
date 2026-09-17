import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = StationViewModel()
    @State private var selectedTab: AppTab = .nearby
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Carte", systemImage: "map.fill", value: AppTab.map) {
                NavigationStack {
                    StationMapView(viewModel: viewModel)
                        .navigationTitle("Carte")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { refreshToolbarButton }
                        }
                }
            }

            Tab("À proximité", systemImage: "location.fill", value: AppTab.nearby) {
                NavigationStack {
                    NearbyView(viewModel: viewModel)
                        .navigationTitle("À proximité")
                        .searchable(text: $viewModel.searchText, prompt: "Chercher une station...")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { refreshToolbarButton }
                        }
                }
            }

            Tab("Stations", systemImage: "list.bullet", value: AppTab.list) {
                NavigationStack {
                    StationListView(viewModel: viewModel)
                        .navigationTitle("Stations")
                        .searchable(text: $viewModel.searchText, prompt: "Chercher une station...")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) { filterMenuButton }
                            ToolbarItem(placement: .topBarTrailing) { refreshToolbarButton }
                        }
                }
            }

            Tab("Favoris", systemImage: "star.fill", value: AppTab.favorites) {
                NavigationStack {
                    FavoritesView(viewModel: viewModel)
                        .navigationTitle("Favoris")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { refreshToolbarButton }
                        }
                }
            }
            .badge(viewModel.appUser.favoriteIDs.count)

            Tab("Profil", systemImage: "person.circle.fill", value: AppTab.profile) {
                NavigationStack {
                    ProfileView(viewModel: viewModel)
                        .navigationTitle("Mon Profil")
                }
            }
        }
        .task {
            await viewModel.fetchStations()
            viewModel.location.startUpdating()
            viewModel.startAutoRefresh(interval: 60)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(viewModel: viewModel, isPresented: $showOnboarding)
                .interactiveDismissDisabled()
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "onboarding_done") {
                showOnboarding = true
            }
        }
    }

    @ViewBuilder
    private var refreshToolbarButton: some View {
        Button {
            Task { await viewModel.fetchStations() }
        } label: {
            if viewModel.isLoading {
                ProgressView().scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
    }

    @ViewBuilder
    private var filterMenuButton: some View {
        Menu {
            Picker("Filtre", selection: $viewModel.selectedFilter) {
                ForEach(AvailabilityFilter.allCases, id: \.self) { filter in
                    Label(filter.rawValue, systemImage: filter.icon).tag(filter)
                }
            }
        } label: {
            Image(systemName: viewModel.selectedFilter == .all
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(viewModel.selectedFilter == .all ? Color.primary : Color.blue)
        }
    }
}

enum AppTab: Hashable {
    case map, nearby, list, favorites, profile
}

// MARK: - Station List View
struct StationListView: View {
    @ObservedObject var viewModel: StationViewModel
    @State private var selectedStation: Station?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.allStations.isEmpty {
                ProgressView("Chargement des stations...")
            } else if let error = viewModel.errorMessage, viewModel.allStations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundStyle(.red)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Réessayer") { Task { await viewModel.fetchStations() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if !viewModel.filteredStations.isEmpty {
                            HStack {
                                Text("\(viewModel.filteredStations.count) station(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let last = viewModel.lastRefresh {
                                    Text("MàJ \(last.formatted(.relative(presentation: .named)))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal)
                        }

                        ForEach(viewModel.filteredStations) { station in
                            Button {
                                selectedStation = station
                            } label: {
                                StationCard(
                                    station: station,
                                    userLocation: viewModel.location.userLocation,
                                    isFavorite: viewModel.isFavorite(station),
                                    hasAlert: viewModel.hasAlert(station),
                                    onFavorite: { viewModel.toggleFavorite(for: station) },
                                    onAlert: { viewModel.toggleAlert(for: station) }
                                )
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable { await viewModel.fetchStations() }
            }
        }
        .sheet(item: $selectedStation) { station in
            StationDetailView(station: station, viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
