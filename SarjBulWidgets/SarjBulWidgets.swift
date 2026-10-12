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
                .containerBackground(for: .widget) { SBColor.surfaceInverted }
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
                        .foregroundStyle(context.kind == .criticalRange ? SBColor.warning : SBColor.contentPrimary)
                    Text(context.title)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(SBColor.contentPrimary.opacity(0.72))
                    Spacer(minLength: 0)
                    Text(context.value)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.contentPrimary)
                }
                Text(context.subtitle)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.contentPrimary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if let endDate = context.endDate {
                    Text(timerInterval: Date()...max(Date(), endDate), countsDown: true)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(SBColor.contentPrimary.opacity(0.72))
                }
            }
        }
        .containerBackground(SBColor.canvas, for: .widget)
    }

    private func deepLinkURL(_ value: String) -> URL {
        URL(string: value) ?? URL(fileURLWithPath: "/")
    }

    private var accent: Color { SBColor.onActionPrimary }
    private var ink: Color { SBColor.onActionPrimary }
    private var isEnglish: Bool { entry.snapshot?.languageCode == "en" }
    private var emptyMessage: String {
        isEnglish ? "Open SarjBul and search from your location." : "SarjBul'u açıp konumunla bir arama yap."
    }
}

struct ChargingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChargingActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(activityAccent)
                        .frame(width: 36, height: 36)
                        .background(activityAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(chargingTitle(context.attributes.languageCode))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SBColor.contentPrimary.opacity(0.68))
                            .lineLimit(1)
                        Text(context.attributes.stationName)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.attributes.languageCode == "en" ? "Target" : "Hedef")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(SBColor.contentPrimary.opacity(0.68))
                        Text(percent(context.state.targetPercent, languageCode: context.attributes.languageCode))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    .fixedSize()
                }
                timerProgress(context.state)
                HStack(spacing: 6) {
                    Text(initialCharge(context.state.initialPercent, languageCode: context.attributes.languageCode))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                    countdown(context.state)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(width: 66, alignment: .trailing)
                }
                .foregroundStyle(SBColor.contentPrimary.opacity(0.72))
            }
            .foregroundStyle(SBColor.contentPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .widgetURL(URL(string: "sarjbul://home"))
            .activityBackgroundTint(SBColor.canvas)
            .activitySystemActionForegroundColor(SBColor.contentPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bolt.fill").foregroundStyle(activityAccent)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.stationName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(percent(context.state.targetPercent, languageCode: context.attributes.languageCode))
                        .font(.subheadline.weight(.bold))
                        .fixedSize()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        timerProgress(context.state)
                        HStack {
                            Text(initialCharge(context.state.initialPercent, languageCode: context.attributes.languageCode))
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            countdown(context.state)
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 66, alignment: .trailing)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "bolt.fill").foregroundStyle(activityAccent)
            } compactTrailing: {
                countdown(context.state)
                    .font(.caption.monospacedDigit())
                    .frame(width: 46, alignment: .trailing)
            } minimal: {
                Image(systemName: "bolt.fill").foregroundStyle(activityAccent)
            }
            .widgetURL(URL(string: "sarjbul://home"))
            .keylineTint(activityAccent)
        }
    }

    private var activityAccent: Color { SBColor.contentPrimary }

    private func timerProgress(_ state: ChargingActivityAttributes.ContentState) -> some View {
        // The default current-value label adds a second timer below the bar.
        ProgressView(timerInterval: state.startedAt...max(state.startedAt, state.endDate), countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(activityAccent)
    }

    private func countdown(_ state: ChargingActivityAttributes.ContentState) -> some View {
        Text(timerInterval: state.startedAt...max(state.startedAt, state.endDate), countsDown: true)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }

    private func percent(_ value: Int, languageCode: String) -> String {
        languageCode == "en" ? "\(value)%" : "%\(value)"
    }

    private func initialCharge(_ value: Int, languageCode: String) -> String {
        let value = percent(value, languageCode: languageCode)
        return languageCode == "en" ? "Start \(value)" : "Başlangıç \(value)"
    }

    private func chargingTitle(_ languageCode: String) -> String {
        languageCode == "en" ? "Charging reminder" : "Şarj hatırlatıcısı"
    }
}
