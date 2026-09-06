import SwiftUI

struct AutonomousProposalCard: View {
    let presentation: ChargingSuggestionPresentation
    var dismiss: () -> Void
    var openRoute: () -> Void
    @State private var showsReason = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Label(presentation.heading, systemImage: "bolt.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SBColor.contentSecondary)
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SBColor.contentTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(presentation.text("agent.dismiss"))
            }

            Text(presentation.stationName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(SBColor.contentPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("agent-station-name")
                .accessibilityAddTraits(.isHeader)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(presentation.duration)
                    Text("·").accessibilityHidden(true)
                    Text(presentation.arrival)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 8) {
                    Text(presentation.duration)
                    Text(presentation.arrival)
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(SBColor.contentPrimary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("agent-estimated-metrics")

            if let lowCharge = presentation.confirmedLowCharge {
                Label(lowCharge, systemImage: "battery.25percent")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(SBColor.warning)
                    .accessibilityIdentifier("agent-confirmed-low-charge")
            }

            Text(presentation.source)
                .font(.footnote)
                .foregroundStyle(SBColor.contentSecondary)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup(isExpanded: $showsReason) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(presentation.reason)
                    Text(presentation.distance)
                }
                .font(.footnote)
                .foregroundStyle(SBColor.contentSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .accessibilityIdentifier("agent-reason-details")
            } label: {
                Text(presentation.text("agent.why_station"))
                    .font(.subheadline)
                    .foregroundStyle(SBColor.contentSecondary)
                    .frame(minHeight: 44)
            }
            .tint(SBColor.contentSecondary)
            .accessibilityIdentifier("agent-reason-toggle")

            Button(action: openRoute) {
                HStack(spacing: 12) {
                    Text(presentation.text("agent.open_route"))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .accessibilityHidden(true)
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(SBColor.onActionPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(SBColor.actionPrimary, in: RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            }
            .buttonStyle(SBPremiumButtonStyle())
            .accessibilityIdentifier("agent-open-route-button")
        }
        .padding(20)
        .background(SBColor.surfaceRaised, in: RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous)
                .stroke(SBColor.divider, lineWidth: 1)
        )
        .sbSoftShadow()
        .accessibilityIdentifier("autonomous-proposal-card")
    }
}
