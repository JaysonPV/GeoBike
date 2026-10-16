import ActivityKit
import WidgetKit
import SwiftUI

struct GeoBikeActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BikeActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color(red: 0.04, green: 0.28, blue: 0.72).opacity(0.9))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "bicycle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.blue)
                        Text(context.attributes.stationName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(context.state.bikes > 0 ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(context.state.isOpen ? "Ouvert" : "Fermé")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 20) {
                        Label("\(context.state.bikes)", systemImage: "bicycle")
                            .foregroundStyle(context.state.bikes > 0 ? .green : .secondary)
                        Label("\(context.state.electricBikes)", systemImage: "bolt.fill")
                            .foregroundStyle(.blue)
                        Label("\(context.state.stands)", systemImage: "parkingsign")
                            .foregroundStyle(context.state.stands > 0 ? .green : .red)
                    }
                    .font(.callout)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: "bicycle")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text("\(context.state.bikes)")
                    .monospacedDigit()
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(context.state.bikes > 0 ? .green : .red)
            } minimal: {
                Image(systemName: "bicycle")
                    .foregroundStyle(context.state.bikes > 0 ? .green : .red)
            }
            .widgetURL(URL(string: "geobike://nearby"))
            .keylineTint(.blue)
        }
    }
}

// MARK: - Lock Screen banner

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BikeActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "bicycle")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.stationName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 14) {
                    bikeCount(count: context.state.bikes, icon: "bicycle", color: .white)
                    bikeCount(count: context.state.electricBikes, icon: "bolt.fill", color: .yellow)
                    bikeCount(count: context.state.stands, icon: "parkingsign",
                              color: context.state.stands > 0 ? .white : Color.red.opacity(0.8))
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Circle()
                    .fill(context.state.bikes > 0 ? Color.green : Color.red)
                    .frame(width: 14, height: 14)
                Text(context.state.bikes > 0 ? "Dispo" : "Vide")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(16)
    }

    private func bikeCount(count: Int, icon: String, color: Color) -> some View {
        Label("\(count)", systemImage: icon)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .monospacedDigit()
    }
}
