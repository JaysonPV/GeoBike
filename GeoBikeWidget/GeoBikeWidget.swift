import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct StationEntry: TimelineEntry {
    let date: Date
    let stations: [WidgetStation]
    let contractLabel: String
    let isPlaceholder: Bool
}

// MARK: - Timeline Provider

struct StationTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StationEntry {
        StationEntry(date: .now, stations: Self.samples, contractLabel: "Vélam", isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StationEntry) -> Void) {
        let data = WidgetDataManager.shared.load()
        completion(StationEntry(
            date: .now,
            stations: data?.stations ?? Self.samples,
            contractLabel: data?.contractLabel ?? "GeoBike",
            isPlaceholder: data == nil
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StationEntry>) -> Void) {
        let data  = WidgetDataManager.shared.load()
        let entry = StationEntry(
            date: .now,
            stations: data?.stations ?? [],
            contractLabel: data?.contractLabel ?? "GeoBike",
            isPlaceholder: data == nil
        )
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private static let samples: [WidgetStation] = [
        WidgetStation(id: 1, cleanName: "Gare Saint-Roch",  bikes: 5, electricBikes: 2, stands: 8,  isOpen: true,  distanceMeters: 250,  latitude: 49.89, longitude: 2.30),
        WidgetStation(id: 2, cleanName: "Place Gambetta",   bikes: 2, electricBikes: 0, stands: 12, isOpen: true,  distanceMeters: 480,  latitude: 49.90, longitude: 2.30),
        WidgetStation(id: 3, cleanName: "Citadelle",        bikes: 0, electricBikes: 0, stands: 15, isOpen: false, distanceMeters: 820,  latitude: 49.91, longitude: 2.29),
    ]
}

// MARK: - Color helper

private extension WidgetStation {
    var availabilityColor: Color {
        guard isOpen else { return .gray }
        if bikes == 0  { return .red    }
        if bikes <= 2  { return .orange }
        return .green
    }

    var distanceLabel: String? {
        guard let d = distanceMeters else { return nil }
        return d < 1000 ? "\(Int(d)) m" : String(format: "%.1f km", d / 1000)
    }
}

// MARK: - Small widget (1 station)

private struct SmallWidgetView: View {
    let entry: StationEntry

    var body: some View {
        if let station = entry.stations.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "bicycle")
                        .font(.caption2.bold())
                        .foregroundStyle(.blue)
                    Text("GeoBike")
                        .font(.caption2.bold())
                        .foregroundStyle(.blue)
                }

                Spacer()

                Circle()
                    .fill(station.availabilityColor)
                    .frame(width: 9, height: 9)

                Text(station.cleanName)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "bicycle")
                            .font(.caption2)
                        Text("\(station.bikes)")
                            .font(.title3.bold())
                            .foregroundStyle(station.availabilityColor)
                    }
                    if station.electricBikes > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text("\(station.electricBikes)")
                                .font(.caption.bold())
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                if let label = station.distanceLabel {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
        } else {
            EmptyWidgetView()
        }
    }
}

// MARK: - Medium widget (3 stations)

private struct MediumWidgetView: View {
    let entry: StationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "bicycle")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                    Text("GeoBike")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text(entry.contractLabel.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let age = ageLabel {
                    Text("· \(age)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if entry.stations.isEmpty {
                Spacer()
                Text("Ouvre GeoBike pour charger les stations à proximité.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entry.stations.prefix(3).enumerated()), id: \.element.id) { index, station in
                        StationRowView(station: station)
                        if index < min(2, entry.stations.count - 1) {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
    }

    private var ageLabel: String? {
        let age = Date.now.timeIntervalSince(entry.date)
        if age < 120  { return nil }
        if age < 3600 { return "\(Int(age / 60)) min" }
        return "\(Int(age / 3600)) h"
    }
}

private struct StationRowView: View {
    let station: WidgetStation

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(station.availabilityColor)
                .frame(width: 8, height: 8)

            Text(station.cleanName)
                .font(.caption.bold())
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let label = station.distanceLabel {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .trailing)
            }

            HStack(spacing: 3) {
                Image(systemName: "bicycle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(station.bikes)")
                    .font(.caption.bold())
                    .foregroundStyle(station.availabilityColor)
                    .frame(width: 22, alignment: .trailing)

                if station.electricBikes > 0 {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("\(station.electricBikes)")
                        .font(.caption2.bold())
                        .foregroundStyle(.yellow)
                        .frame(width: 16, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Empty state

private struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bicycle")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("GeoBike")
                .font(.caption.bold())
                .foregroundStyle(.blue)
            Text("Ouvre l'app pour charger les stations.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Entry view (dispatches by family)

struct GeoBikeWidgetEntryView: View {
    let entry: StationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall: SmallWidgetView(entry: entry)
            default:           MediumWidgetView(entry: entry)
            }
        }
        .widgetURL(URL(string: "geobike://nearby"))
    }
}

// MARK: - Widget configuration

struct GeoBikeWidget: Widget {
    let kind = "GeoBikeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StationTimelineProvider()) { entry in
            GeoBikeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("GeoBike")
        .description("Les vélos disponibles à proximité, en un coup d'œil.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
