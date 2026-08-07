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
                .containerBackground(for: .widget) { Color(white: 0.96) }
        }
        .configurationDisplayName("SarjBul")
        .description("En yakın hızlı şarjı ve güvenli menzilini gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct NearestStationEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
    var context: WidgetContextSnapshot?
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
            ),
            context: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NearestStationEntry) -> Void) {
        completion(NearestStationEntry(
            date: Date(),
            snapshot: WidgetSnapshotStore.load(),
            context: WidgetContextSnapshotStore.load()
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NearestStationEntry>) -> Void) {
        let context = WidgetContextSnapshotStore.load()
        let entry = NearestStationEntry(date: Date(), snapshot: WidgetSnapshotStore.load(), context: context)
        let refreshDate = context?.endDate ?? Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

private struct NearestStationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NearestStationEntry

    var body: some View {
        if let context = entry.context {
            contextualView(context)
        } else if let snapshot = entry.snapshot {
            Link(destination: deepLinkURL("sarjbul://quick/fast")) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("ŞarjBul", systemImage: "bolt.car.fill")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(accent)
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
                Image(systemName: "bolt.car.fill").foregroundStyle(accent)
                Text(emptyMessage)
                    .font(.headline.weight(.bold))
            }
        }
    }

    private func contextualView(_ context: WidgetContextSnapshot) -> some View {
        Link(destination: deepLinkURL(context.deepLink)) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: context.icon)
                        .foregroundStyle(context.kind == .criticalRange ? Color.orange : Color.white)
                    Text(context.title)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer(minLength: 0)
                    Text(context.value)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                }
                Text(context.subtitle)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if let endDate = context.endDate {
                    Text(timerInterval: Date()...max(Date(), endDate), countsDown: true)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
        .containerBackground(Color.black, for: .widget)
    }

    private func deepLinkURL(_ value: String) -> URL {
        URL(string: value) ?? URL(fileURLWithPath: "/")
    }

    private var accent: Color { .black }
    private var ink: Color { .black }
    private var isEnglish: Bool { entry.snapshot?.languageCode == "en" }
    private var emptyMessage: String {
        isEnglish ? "Open SarjBul and search from your location." : "SarjBul'u açıp konumunla bir arama yap."
    }
}

struct ChargingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChargingActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(activityAccent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(chargingTitle(context.attributes.languageCode))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.68))
                        Text(context.attributes.stationName)
                            .font(.headline.weight(.heavy))
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("%\(context.state.targetPercent)")
                        .font(.title3.weight(.heavy))
                }
                ProgressView(
                    timerInterval: context.state.startedAt...context.state.endDate,
                    countsDown: false
                )
                .tint(activityAccent)
                HStack {
                    Text("%\(context.state.initialPercent)")
                    Spacer()
                    Text(timerInterval: Date()...max(Date(), context.state.endDate), countsDown: true)
                        .monospacedDigit()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 4)
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bolt.fill").foregroundStyle(activityAccent)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.stationName).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("%\(context.state.targetPercent)").fontWeight(.heavy)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(
                            timerInterval: context.state.startedAt...context.state.endDate,
                            countsDown: false
                        )
                        .tint(activityAccent)
                        Text(timerInterval: Date()...max(Date(), context.state.endDate), countsDown: true)
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Image(systemName: "bolt.fill").foregroundStyle(activityAccent)
            } compactTrailing: {
                Text(timerInterval: Date()...max(Date(), context.state.endDate), countsDown: true)
                    .monospacedDigit()
                    .frame(width: 46)
            } minimal: {
                Image(systemName: "bolt.fill").foregroundStyle(activityAccent)
            }
            .widgetURL(URL(string: "sarjbul://lounge"))
            .keylineTint(activityAccent)
        }
    }

    private var activityAccent: Color { .white }

    private func chargingTitle(_ languageCode: String) -> String {
        languageCode == "en" ? "Charging" : "Şarj devam ediyor"
    }
}
