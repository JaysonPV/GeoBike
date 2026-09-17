import SwiftUI

struct AvailabilityBar: View {
    let bikes: Int
    let capacity: Int
    var showLabel = true

    private var ratio: Double {
        capacity > 0 ? min(Double(bikes) / Double(capacity), 1.0) : 0
    }

    private var barColor: Color {
        switch ratio {
        case 0: return .red
        case ..<0.2: return .orange
        case ..<0.5: return .yellow
        default: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * ratio, height: 8)
                        .animation(.spring(duration: 0.5), value: ratio)
                }
            }
            .frame(height: 8)

            if showLabel {
                Text("\(bikes)/\(capacity) vélos")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BikeCountBadge: View {
    let count: Int
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                    Text("\(count)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatusCapsule: View {
    let station: Station

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(station.isOpen ? Color.green : Color.red)
                .frame(width: 7, height: 7)
            Text(station.isOpen ? "Ouverte" : "Fermée")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(station.isOpen ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
        )
        .foregroundStyle(station.isOpen ? .green : .red)
    }
}
