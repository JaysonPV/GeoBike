import SwiftUI
import CoreLocation

struct StationCard: View {
    let station: Station
    let userLocation: CLLocation?
    let isFavorite: Bool
    let hasAlert: Bool
    let onFavorite: () -> Void
    let onAlert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.cleanName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(station.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onAlert) {
                        Image(systemName: hasAlert ? "bell.fill" : "bell")
                            .font(.system(size: 15))
                            .foregroundStyle(hasAlert ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: onFavorite) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 15))
                            .foregroundStyle(isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Bike counts
            HStack(spacing: 0) {
                BikeCountBadge(count: station.mainStands.availabilities.mechanicalBikes,
                               icon: "bicycle", label: "Méca.", color: .primary)
                Spacer()
                BikeCountBadge(count: station.mainStands.availabilities.electricalBikes,
                               icon: "bolt.fill", label: "Électrique", color: .blue)
                Spacer()
                BikeCountBadge(count: station.mainStands.availabilities.stands,
                               icon: "parkingsign", label: "Places", color: .green)
            }

            // Availability bar
            AvailabilityBar(bikes: station.mainStands.availabilities.bikes,
                            capacity: station.mainStands.capacity)

            // Footer
            HStack {
                StatusCapsule(station: station)
                Spacer()
                if let dist = station.formattedDistance(from: userLocation) {
                    Label(dist, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.systemGray4).opacity(0.5), lineWidth: 0.5)
        )
        .opacity(station.isOpen ? 1 : 0.6)
    }
}
