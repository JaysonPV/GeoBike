import SwiftUI
import MapKit

struct StationMapView: View {
    @ObservedObject var viewModel: StationViewModel
    @State private var selectedStation: Station?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 49.8941, longitude: 2.2958),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var showDetail = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(viewModel.filteredStations) { station in
                    Annotation(station.cleanName, coordinate: station.coordinate, anchor: .bottom) {
                        StationPin(station: station, isSelected: selectedStation?.id == station.id)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.3)) {
                                    selectedStation = station
                                }
                            }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .top)

            // Bottom panel when a station is selected
            if let station = selectedStation {
                StationMapCard(station: station, viewModel: viewModel) {
                    showDetail = true
                } onClose: {
                    withAnimation(.spring(duration: 0.3)) { selectedStation = nil }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // Filter chips overlay
            VStack {
                filterChips
                Spacer()
            }
            .padding(.top, 8)
        }
        .sheet(isPresented: $showDetail) {
            if let station = selectedStation {
                StationDetailView(station: station, viewModel: viewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            if let loc = viewModel.location.userLocation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AvailabilityFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation {
                            viewModel.selectedFilter = filter
                        }
                    } label: {
                        Label(filter.rawValue, systemImage: filter.icon)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedFilter == filter ? Color.blue : Color(.systemBackground),
                                in: Capsule()
                            )
                            .foregroundStyle(viewModel.selectedFilter == filter ? .white : .primary)
                    }
                    .shadow(radius: 2, y: 1)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct StationPin: View {
    let station: Station
    let isSelected: Bool

    private var pinColor: Color {
        guard station.isOpen else { return .gray }
        switch station.mainStands.availabilities.bikes {
        case 0: return .red
        case 1...2: return .orange
        case 3...5: return .yellow
        default: return .green
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: isSelected ? 44 : 32, height: isSelected ? 44 : 32)
                .shadow(color: pinColor.opacity(0.5), radius: isSelected ? 8 : 4)
            Image(systemName: "bicycle")
                .font(.system(size: isSelected ? 18 : 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .animation(.spring(duration: 0.3), value: isSelected)
        .overlay(alignment: .topTrailing) {
            if station.mainStands.availabilities.bikes > 0 {
                Text("\(station.mainStands.availabilities.bikes)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(Color.black.opacity(0.6), in: Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
}

struct StationMapCard: View {
    let station: Station
    @ObservedObject var viewModel: StationViewModel
    let onDetail: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.cleanName)
                        .font(.headline)
                    Text(station.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }

            HStack(spacing: 16) {
                Label("\(station.mainStands.availabilities.mechanicalBikes) méca.", systemImage: "bicycle")
                    .font(.subheadline)
                Label("\(station.mainStands.availabilities.electricalBikes) élec.", systemImage: "bolt.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                Spacer()
                if let dist = station.formattedDistance(from: viewModel.location.userLocation) {
                    Label(dist, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onDetail) {
                Text("Voir les détails")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 8, y: 4)
    }
}
