import SwiftUI
import CoreLocation

struct NearbyView: View {
    @ObservedObject var viewModel: StationViewModel
    @State private var selectedStation: Station?

    var body: some View {
        Group {
            if viewModel.location.isPermissionDenied {
                locationDeniedView
            } else if !viewModel.location.hasPermission {
                requestLocationView
            } else if viewModel.location.userLocation == nil {
                loadingLocationView
            } else if viewModel.nearbyStations.isEmpty {
                emptyView
            } else {
                stationList
            }
        }
        .sheet(item: $selectedStation) { station in
            StationDetailView(station: station, viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var stationList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let loc = viewModel.location.userLocation {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Stations les plus proches")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)

                    ForEach(viewModel.nearbyStations) { station in
                        Button {
                            selectedStation = station
                        } label: {
                            StationCard(
                                station: station,
                                userLocation: loc,
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
            }
            .padding(.vertical)
        }
        .refreshable { await viewModel.fetchStations() }
    }

    private var requestLocationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("Localisation requise")
                .font(.title2)
                .fontWeight(.bold)
            Text("Pour voir les stations proches de vous, GeoBike a besoin d'accéder à votre position.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button {
                viewModel.location.requestPermission()
            } label: {
                Label("Autoriser la localisation", systemImage: "location.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal)
            }
        }
    }

    private var locationDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("Localisation désactivée")
                .font(.title2)
                .fontWeight(.bold)
            Text("Activez la localisation dans les réglages pour utiliser cette fonctionnalité.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Ouvrir les Réglages", systemImage: "gear")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.primary)
                    .padding(.horizontal)
            }
        }
    }

    private var loadingLocationView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Localisation en cours...")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bicycle.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Aucune station à proximité")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}
