import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: StationViewModel

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
                    Text("Cycliste Amiénois")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("GeoBike Amiens")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

                // Network info
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Réseau Amiens")

                    infoRow(icon: "building.2.fill", label: "Opérateur", value: "JCDecaux / Vélam")
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

                // Notifications section
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Préférences")

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

                // Firebase note
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "cloud.fill")
                            .foregroundStyle(.blue)
                        Text("Synchronisation Cloud")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("Activez Firebase pour synchroniser vos favoris et alertes sur tous vos appareils.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
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
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 11)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct NotificationSettingsView: View {
    @ObservedObject var viewModel: StationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(viewModel.favoriteStations) { station in
            HStack {
                VStack(alignment: .leading) {
                    Text(station.cleanName).font(.subheadline)
                    Text("\(station.mainStands.availabilities.bikes) vélos dispo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
