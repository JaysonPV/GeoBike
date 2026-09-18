import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: StationViewModel
    @State private var showCityPicker = false

    private var stats: AppStats { viewModel.stats }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Avatar
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 90, height: 90)
                        Image(systemName: "figure.outdoor.cycle")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                    }
                    Text("Cycliste GeoBike")
                        .font(.title2)
                        .fontWeight(.bold)
                    if let contract = viewModel.selectedContract {
                        Text(contract.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(value: "\(viewModel.appUser.favoriteIDs.count)", label: "Favoris", icon: "star.fill", color: .yellow)
                    StatCard(value: "\(viewModel.appUser.alertedStationIDs.count)", label: "Alertes actives", icon: "bell.fill", color: .orange)
                    StatCard(value: "\(stats.openStations)", label: "Stations ouvertes", icon: "checkmark.circle.fill", color: .green)
                    StatCard(value: "\(stats.totalBikes)", label: "Vélos dispo", icon: "bicycle", color: .blue)
                }
                .padding(.horizontal)

                // Current city banner
                if let contract = viewModel.selectedContract {
                    Button { showCityPicker = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ville sélectionnée")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(contract.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(16)
                        .background(
                            LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                // Network info
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Réseau actuel")

                    infoRow(icon: "building.2.fill", label: "Opérateur", value: "JCDecaux")
                    Divider().padding(.leading, 44)
                    infoRow(icon: "bicycle", label: "Stations totales", value: "\(stats.totalStations)")
                    Divider().padding(.leading, 44)
                    infoRow(icon: "bolt.fill", label: "Vélos électriques", value: "\(stats.totalElectric)")
                    Divider().padding(.leading, 44)
                    if let refresh = viewModel.lastRefresh {
                        infoRow(icon: "clock.fill", label: "Dernière mise à jour", value: refresh.formatted(.relative(presentation: .named)))
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Preferences
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Préférences")

                    // City picker
                    Button {
                        showCityPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                                .padding(.leading, 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ville")
                                    .foregroundStyle(.primary)
                                if let contract = viewModel.selectedContract {
                                    Text(contract.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 14)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 16)
                        }
                    }

                    Divider().padding(.leading, 44)

                    // Notification settings
                    NavigationLink {
                        NotificationSettingsView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.orange)
                                .frame(width: 24)
                                .padding(.leading, 16)
                            Text("Alertes de disponibilité")
                                .foregroundStyle(.primary)
                                .padding(.vertical, 14)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerView(viewModel: viewModel, isPresented: $showCityPicker)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
                .padding(.leading, 16)
            Text(label).foregroundStyle(.primary)
            Spacer()
            Text(value).foregroundStyle(.secondary).padding(.trailing, 16)
        }
        .padding(.vertical, 11)
    }
}

// MARK: - City Picker
struct CityPickerView: View {
    @ObservedObject var viewModel: StationViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""

    private var filtered: [Contract] {
        if searchText.isEmpty { return viewModel.availableContracts }
        return viewModel.availableContracts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.brandName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { contract in
                Button {
                    Task {
                        await viewModel.selectContract(contract)
                        isPresented = false
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contract.displayName)
                                .foregroundStyle(.primary)
                                .fontWeight(viewModel.selectedContract?.name == contract.name ? .semibold : .regular)
                            if let brand = contract.brandName {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if viewModel.selectedContract?.name == contract.name {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher une ville…")
            .navigationTitle("Choisir une ville")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if viewModel.isLoadingContracts {
                    ZStack {
                        Color(.systemBackground).opacity(0.85)
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Chargement des villes…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if !searchText.isEmpty && filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if viewModel.availableContracts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Impossible de charger les villes")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Réessayer") {
                            Task { await viewModel.refreshContracts() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoadingContracts {
                        ProgressView().scaleEffect(0.8)
                    }
                }
            }
            .task {
                await viewModel.refreshContracts()
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.title2)
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Notification Settings
struct NotificationSettingsView: View {
    @ObservedObject var viewModel: StationViewModel

    var body: some View {
        List(viewModel.favoriteStations) { station in
            HStack {
                VStack(alignment: .leading) {
                    Text(station.cleanName).font(.subheadline)
                    Text("\(station.mainStands.availabilities.bikes) vélos dispo.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.hasAlert(station) },
                    set: { _ in viewModel.toggleAlert(for: station) }
                ))
            }
        }
        .navigationTitle("Alertes")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.favoriteStations.isEmpty {
                ContentUnavailableView("Aucun favori", systemImage: "star.slash",
                    description: Text("Ajoutez des stations en favoris pour configurer des alertes."))
            }
        }
    }
}
