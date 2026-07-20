import ActivityKit
import SwiftUI
import WidgetKit

@main
struct SarjBulWidgets: WidgetBundle {
    var body: some Widget {
        SarjBulNearestWidget()
        ChargingLiveActivityWidget()
    }
}

struct SarjBulNearestWidget: Widget {
    let kind = "SarjBulNearestWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NearestStationProvider()) { entry in
            NearestStationWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(red: 0.97, green: 0.98, blue: 0.94) }
        }
        .configurationDisplayName("SarjBul")
        .description("En yakın hızlı şarjı ve güvenli menzilini gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct NearestStationEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
}

private struct NearestStationProvider: TimelineProvider {
    func placeholder(in context: Context) -> NearestStationEntry {
        NearestStationEntry(
            date: Date(),
            snapshot: WidgetSnapshot(
                stationName: "En yakın hızlı şarj",
                distanceKm: 2.4,
                power: "180 kW",
                safeRangeKm: 100,
                updatedAt: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NearestStationEntry) -> Void) {
        completion(NearestStationEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NearestStationEntry>) -> Void) {
        let entry = NearestStationEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

private struct NearestStationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NearestStationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            Link(destination: URL(string: "sarjbul://quick/fast")!) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("ŞarjBul", systemImage: "bolt.car.fill")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(neon)
                    Text(snapshot.stationName)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(ink)
                        .lineLimit(family == .systemSmall ? 2 : 1)
                    Spacer(minLength: 0)
                    HStack {
                        Text(String(format: "%.1f km", snapshot.distanceKm))
                        Spacer()
                        Text(snapshot.power)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ink.opacity(0.72))
                    Text(isEnglish
                         ? "\(snapshot.safeRangeKm) km safe range"
                         : "\(snapshot.safeRangeKm) km güvenli menzil")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ink.opacity(0.62))
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "bolt.car.fill").foregroundStyle(neon)
                Text(emptyMessage)
                    .font(.headline.weight(.bold))
            }
        }
    }

    private var neon: Color { Color(red: 0.76, green: 1, blue: 0.05) }
    private var ink: Color { Color(red: 0.05, green: 0.07, blue: 0.05) }
    private var isEnglish: Bool { entry.snapshot?.languageCode == "en" }
    private var emptyMessage: String {
        isEnglish ? "Open SarjBul and search from your location." : "SarjBul'u açıp konumunla bir arama yap."
    }
}

struct ChargingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChargingActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(neon)
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.stationName)
                        .font(.headline.weight(.heavy))
                        .lineLimit(1)
                    Text(timerInterval: Date()...max(Date(), context.state.endDate), countsDown: true)
                        .font(.subheadline.monospacedDigit().weight(.bold))
                }
                Spacer()
                Text("%\(context.state.targetPercent)")
                    .font(.title3.weight(.heavy))
            }
            .padding(.horizontal, 4)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bolt.fill").foregroundStyle(neon)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.stationName).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("%\(context.state.targetPercent)").fontWeight(.heavy)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(timerInterval: Date()...max(Date(), context.state.endDate), countsDown: true)
                        .monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: "bolt.fill").foregroundStyle(neon)
            } compactTrailing: {
                Text(timerInterval: Date()...max(Date(), context.state.endDate), countsDown: true)
                    .monospacedDigit()
                    .frame(width: 46)
            } minimal: {
                Image(systemName: "bolt.fill").foregroundStyle(neon)
            }
            .widgetURL(URL(string: "sarjbul://lounge"))
            .keylineTint(neon)
        }
    }

    private var neon: Color { Color(red: 0.76, green: 1, blue: 0.05) }
}
