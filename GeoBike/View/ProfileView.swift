import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: StationViewModel
    @State private var showCityPicker = false
    @State private var showAvatarPicker = false

    private var stats: AppStats { viewModel.stats }

    private var avatarSymbol: String { viewModel.appUser.avatarSymbol ?? "figure.outdoor.cycle" }
    private var avatarColor: Color { resolveColor(viewModel.appUser.avatarColorName) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Avatar
                VStack(spacing: 12) {
                    Button { showAvatarPicker = true } label: {
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [avatarColor, avatarColor.opacity(0.6)],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 90, height: 90)
                                Image(systemName: avatarSymbol)
                                    .font(.system(size: 38))
                                    .foregroundStyle(.white)
                            }
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .background(Color(.systemBackground), in: Circle())
                                .offset(x: 4, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    Text("Cycliste GeoBike")
                        .font(.title2)
                        .fontWeight(.bold)
                    if let contract = viewModel.selectedContract {
                        Text(contract.displayName.capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(value: "\(viewModel.appUser.favoriteIDs.count)", label: "Favoris", icon: "star.fill", color: .yellow)
                    StatCard(value: "\(viewModel.activeAlertsCount)", label: "Alertes actives", icon: "bell.fill", color: .orange)
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
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerView(
                avatarSymbol: $viewModel.appUser.avatarSymbol,
                avatarColorName: $viewModel.appUser.avatarColorName
            )
            .onDisappear { viewModel.saveProfile() }
        }
    }

    private func resolveColor(_ name: String?) -> Color {
        switch name {
        case "green":  return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red":    return .red
        case "teal":   return .teal
        case "yellow": return .yellow
        default:       return .blue
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

// MARK: - Avatar Picker
struct AvatarPickerView: View {
    @Binding var avatarSymbol: String?
    @Binding var avatarColorName: String?
    @Environment(\.dismiss) private var dismiss

    private let icons = [
        "figure.outdoor.cycle", "bicycle", "figure.run", "figure.walk",
        "bolt.fill", "leaf.fill", "map.fill", "star.fill",
        "heart.fill", "trophy.fill", "flag.fill", "location.fill"
    ]
    private let colors: [(String, Color)] = [
        ("blue", .blue), ("green", .green), ("orange", .orange),
        ("purple", .purple), ("red", .red), ("teal", .teal)
    ]

    private var currentSymbol: String { avatarSymbol ?? "figure.outdoor.cycle" }
    private var currentColor: Color {
        colors.first { $0.0 == (avatarColorName ?? "blue") }?.1 ?? .blue
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [currentColor, currentColor.opacity(0.6)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 110, height: 110)
                        Image(systemName: currentSymbol)
                            .font(.system(size: 48))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)
                    .animation(.spring(duration: 0.3), value: currentSymbol)
                    .animation(.spring(duration: 0.3), value: avatarColorName)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Couleur").font(.headline).padding(.horizontal)
                        HStack(spacing: 14) {
                            ForEach(colors, id: \.0) { name, color in
                                Button {
                                    avatarColorName = name
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 42, height: 42)
                                        .overlay {
                                            if (avatarColorName ?? "blue") == name {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .shadow(color: color.opacity(0.4), radius: 4, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Icône").font(.headline).padding(.horizontal)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                            ForEach(icons, id: \.self) { icon in
                                Button {
                                    avatarSymbol = icon
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(currentSymbol == icon
                                                  ? currentColor.opacity(0.15)
                                                  : Color(.secondarySystemBackground))
                                            .frame(width: 68, height: 68)
                                            .overlay {
                                                if currentSymbol == icon {
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(currentColor, lineWidth: 2)
                                                }
                                            }
                                        Image(systemName: icon)
                                            .font(.system(size: 26))
                                            .foregroundStyle(currentSymbol == icon ? currentColor : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Mon avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terminer") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
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
        List(viewModel.alertedStations) { station in
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
            if viewModel.alertedStations.isEmpty {
                ContentUnavailableView("Aucune alerte active", systemImage: "bell.slash",
                    description: Text("Activez une alerte sur une station depuis la liste ou la carte."))
            }
        }
    }
}
