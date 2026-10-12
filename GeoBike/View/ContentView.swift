import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = StationViewModel()
    @State private var selectedTab: AppTab = .nearby
    @State private var showOnboarding = false
    @State private var showTutorial = false
    @State private var tutorialStep = 0

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
            viewModel.location.startUpdating()
            await viewModel.setup()
            viewModel.startAutoRefresh(interval: 60)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(viewModel: viewModel, isPresented: $showOnboarding)
                .interactiveDismissDisabled()
        }
        .alert("Ville indisponible", isPresented: Binding(
            get: { viewModel.cityUnavailableMessage != nil },
            set: { if !$0 { viewModel.cityUnavailableMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.cityUnavailableMessage = nil }
        } message: {
            if let msg = viewModel.cityUnavailableMessage { Text(msg) }
        }
        .onChange(of: showOnboarding) { _, isShowing in
            guard !isShowing else { return }
            // Re-detect nearest city now that location permission may have been granted
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                await viewModel.refreshDetectionIfNeeded()
            }
            // Show tutorial if not yet seen
            if !UserDefaults.standard.bool(forKey: "tutorial_done") {
                Task {
                    try? await Task.sleep(for: .seconds(0.6))
                    withAnimation(.spring(duration: 0.5)) { showTutorial = true }
                }
            }
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "onboarding_done") {
                showOnboarding = true
            } else if !UserDefaults.standard.bool(forKey: "tutorial_done") {
                Task {
                    try? await Task.sleep(for: .seconds(0.8))
                    withAnimation(.spring(duration: 0.5)) { showTutorial = true }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showTutorial {
                TutorialCardView(step: $tutorialStep, selectedTab: $selectedTab) {
                    UserDefaults.standard.set(true, forKey: "tutorial_done")
                    withAnimation(.spring(duration: 0.4)) {
                        showTutorial = false
                        tutorialStep = 0
                    }
                }
                .padding(.bottom, 88)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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

// MARK: - Tutorial Card
private struct TutorialCardView: View {
    @Binding var step: Int
    @Binding var selectedTab: AppTab
    let onFinish: () -> Void

    private struct TutorialStep {
        let tab: AppTab
        let icon: String
        let color: Color
        let title: String
        let hint: String
    }

    private static let steps: [TutorialStep] = [
        TutorialStep(tab: .map,       icon: "map.fill",           color: .blue,
                     title: "Explore la carte",
                     hint: "Les points colorés indiquent la disponibilité. Appuie sur un pour voir les détails."),
        TutorialStep(tab: .nearby,    icon: "location.fill",      color: .teal,
                     title: "Stations à proximité",
                     hint: "Tes stations triées par distance. Active la localisation pour un résultat précis."),
        TutorialStep(tab: .list,      icon: "list.bullet",        color: .indigo,
                     title: "Ajoute un favori",
                     hint: "Appuie sur l'étoile d'une station pour la sauvegarder et activer une alerte."),
        TutorialStep(tab: .favorites, icon: "star.fill",          color: .orange,
                     title: "Tes favoris",
                     hint: "Retrouve ici toutes tes stations préférées, synchronisées dans le cloud."),
        TutorialStep(tab: .profile,   icon: "person.circle.fill", color: .purple,
                     title: "Ton profil",
                     hint: "Change de ville, personnalise ton avatar et gère tes alertes de disponibilité.")
    ]

    private var current: TutorialStep { Self.steps[step] }

    var body: some View {
        let c = current
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 46, height: 46)
                    Image(systemName: c.icon)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(c.hint)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                HStack(spacing: 5) {
                    ForEach(0..<Self.steps.count, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.white : Color.white.opacity(0.3))
                            .frame(width: i == step ? 18 : 6, height: 6)
                            .animation(.spring(duration: 0.3), value: step)
                    }
                }
                Spacer()
                HStack(spacing: 12) {
                    if step < Self.steps.count - 1 {
                        Button("Passer") { onFinish() }
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Button {
                        if step < Self.steps.count - 1 {
                            withAnimation(.spring(duration: 0.35)) { step += 1 }
                        } else {
                            onFinish()
                        }
                    } label: {
                        Text(step == Self.steps.count - 1 ? "C'est parti !" : "Suivant →")
                            .font(.subheadline.bold())
                            .foregroundStyle(c.color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.white, in: Capsule())
                    }
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [c.color, c.color.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .shadow(color: c.color.opacity(0.45), radius: 20, y: 6)
        .padding(.horizontal, 16)
        .onChange(of: step) { _, _ in
            withAnimation(.spring(duration: 0.3)) {
                selectedTab = Self.steps[step].tab
            }
        }
        .onAppear { selectedTab = c.tab }
    }
}
