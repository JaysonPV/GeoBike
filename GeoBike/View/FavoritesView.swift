import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: StationViewModel
    @State private var selectedStation: Station?

    var body: some View {
        Group {
            if viewModel.favoriteStations.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.favoriteStations) { station in
                            Button {
                                selectedStation = station
                            } label: {
                                StationCard(
                                    station: station,
                                    userLocation: viewModel.location.userLocation,
                                    isFavorite: true,
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

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow.opacity(0.7))
            Text("Aucun favori")
                .font(.title2)
                .fontWeight(.bold)
            Text("Ajoutez des stations à vos favoris depuis la liste ou la carte pour les retrouver ici.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
    }
}
