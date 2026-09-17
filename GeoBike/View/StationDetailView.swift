import SwiftUI
import MapKit

struct StationDetailView: View {
    let station: Station
    @ObservedObject var viewModel: StationViewModel
    @Environment(\.dismiss) private var dismiss

    private var isFavorite: Bool { viewModel.isFavorite(station) }
    private var hasAlert: Bool { viewModel.hasAlert(station) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Map preview
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: station.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    ))) {
                        Marker(station.cleanName, coordinate: station.coordinate)
                            .tint(station.isOpen ? .green : .red)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Status + distance
                    HStack(spacing: 12) {
                        StatusCapsule(station: station)
                        if let dist = station.formattedDistance(from: viewModel.location.userLocation) {
                            Label(dist, systemImage: "location.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color(.systemGray6)))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Address
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundStyle(.blue)
                        Text(station.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Bike counters
                    HStack(spacing: 20) {
                        bikeCard(
                            count: station.mainStands.availabilities.mechanicalBikes,
                            icon: "bicycle",
                            label: "Mécaniques",
                            color: .primary
                        )
                        bikeCard(
                            count: station.mainStands.availabilities.electricalBikes,
                            icon: "bolt.fill",
                            label: "Électriques",
                            color: .blue
                        )
                        bikeCard(
                            count: station.mainStands.availabilities.stands,
                            icon: "parkingsign",
                            label: "Places",
                            color: station.mainStands.availabilities.stands > 0 ? .green : .red
                        )
                    }
                    .padding(.horizontal)

                    // Availability bar full
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Taux de remplissage")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        AvailabilityBar(bikes: station.mainStands.availabilities.bikes,
                                        capacity: station.mainStands.capacity,
                                        showLabel: true)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Actions
                    VStack(spacing: 12) {
                        // Navigate button
                        Button {
                            openInMaps()
                        } label: {
                            Label("Itinéraire", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }

                        HStack(spacing: 12) {
                            // Favorite button
                            Button {
                                viewModel.toggleFavorite(for: station)
                            } label: {
                                Label(isFavorite ? "Favori" : "Ajouter", systemImage: isFavorite ? "star.fill" : "star")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isFavorite ? Color.yellow.opacity(0.2) : Color(.systemGray6),
                                                in: RoundedRectangle(cornerRadius: 14))
                                    .foregroundStyle(isFavorite ? .yellow : .primary)
                            }

                            // Alert button
                            Button {
                                viewModel.toggleAlert(for: station)
                            } label: {
                                Label(hasAlert ? "Alerté" : "Alerter", systemImage: hasAlert ? "bell.fill" : "bell")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(hasAlert ? Color.orange.opacity(0.2) : Color(.systemGray6),
                                                in: RoundedRectangle(cornerRadius: 14))
                                    .foregroundStyle(hasAlert ? .orange : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(station.cleanName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func bikeCard(count: Int, icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func openInMaps() {
        let coordinate = station.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = station.cleanName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}
