import SarjBulCore
import SwiftUI

struct TripPlanView: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let plan: ChargingTripPlan

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary

                    if let advice = HolidayTrafficAdvisor.advice(for: Date()) {
                        Label(
                            settings.t("planner.holiday_advice", [
                                "holiday": advice.title,
                                "start": "\(advice.expectedPeakStartHour)",
                                "end": "\(advice.expectedPeakEndHour)"
                            ]),
                            systemImage: "exclamationmark.road.lanes"
                        )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SBColor.ink)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SBColor.warning.opacity(0.24))
                        .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
                    }

                    if plan.stops.isEmpty {
                        Label(settings.t("planner.no_stop"), systemImage: "checkmark.circle.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(SBColor.electricBlue)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .sbPremiumGlass(radius: SBRadius.lg)
                    } else {
                        Text(settings.t("planner.stops"))
                            .font(.title2.weight(.heavy))
                        ForEach(Array(plan.stops.enumerated()), id: \.element.id) { index, stop in
                            stopRow(stop, number: index + 1)
                        }
                    }

                    Text(plan.elevationAdjusted
                        ? settings.t("planner.elevation_attribution")
                        : settings.t("planner.elevation_unavailable"))
                        .font(.caption)
                        .foregroundStyle(SBColor.textSoft)
                }
                .padding(20)
            }
            .background(SBScreenBackground())
            .navigationTitle(settings.t("planner.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("status.ok")) { dismiss() }
                }
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(settings.t("planner.fastest_plan"))
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(SBColor.primaryDeep)
            Text(duration(plan.totalMinutes))
                .font(SBFont.display(size: 52, weight: .heavy))
                .foregroundStyle(SBColor.ink)
            HStack(spacing: 10) {
                metric(settings.t("planner.distance"), String(format: "%.0f km", plan.distanceKm))
                metric(settings.t("planner.charge_time"), duration(plan.chargingMinutes))
                metric(settings.t("planner.arrival"), "%\(plan.arrivalPercent)")
            }
        }
        .padding(20)
        .sbPremiumGlass(radius: SBRadius.xl)
        .sbGlowShadow()
    }

    private func stopRow(_ stop: PlannedChargingStop, number: Int) -> some View {
        HStack(spacing: 14) {
            Text("\(number)")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(SBColor.electricBlue)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(stop.candidate.station.name)
                    .font(.headline.weight(.heavy))
                    .lineLimit(2)
                Text(settings.t("planner.stop_detail", [
                    "arrival": "\(stop.arrivalPercent)",
                    "departure": "\(stop.departurePercent)",
                    "minutes": "\(stop.chargingMinutes)"
                ]))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SBColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .sbPremiumGlass(radius: SBRadius.lg)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(SBColor.muted)
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(SBColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return settings.t("planner.minutes", ["minutes": "\(remainder)"]) }
        return settings.t("planner.hours_minutes", ["hours": "\(hours)", "minutes": "\(remainder)"])
    }
}
