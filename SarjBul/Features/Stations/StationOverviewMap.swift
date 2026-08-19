import MapKit
import SarjBulCore
import SwiftUI

struct StationOverviewMap: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(SearchCoordinator.self) private var search
    let candidates: [StationCandidate]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedID: String?
    @State private var detailCandidate: StationCandidate?
    @State private var isochrone: [CLLocationCoordinate2D] = []
    private let isochroneService = RangeIsochroneService()

    var body: some View {
        Map(position: $position, selection: $selectedID) {
            if isochrone.count >= 3 {
                MapPolygon(coordinates: isochrone)
                    .foregroundStyle(SBColor.contentPrimary.opacity(0.08))
                    .stroke(SBColor.contentPrimary.opacity(0.55), lineWidth: 2)
            }

            if let origin = search.userLocation {
                Annotation(settings.t("map.current_location"), coordinate: CLLocationCoordinate2D(
                    latitude: origin.latitude,
                    longitude: origin.longitude
                )) {
                    ZStack {
                        Circle()
                            .fill(SBColor.contentPrimary.opacity(0.16))
                            .frame(width: 38, height: 38)
                        Circle()
                            .fill(SBColor.contentPrimary)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(SBColor.surfaceInverted, lineWidth: 3))
                    }
                }
            }

            ForEach(candidates) { candidate in
                Annotation(
                    candidate.station.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: candidate.station.latitude,
                        longitude: candidate.station.longitude
                    )
                ) {
                    StationPowerPin(
                        candidate: candidate,
                        isSelected: selectedID == candidate.id
                    )
                }
                .tag(candidate.id)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: true))
        .saturation(0)
        .mapControls {
            MapCompass()
            MapScaleView()
            MapPitchToggle()
        }
        .onAppear(perform: frameCandidates)
        .task(id: isochroneTaskID) {
            guard let origin = search.userLocation else { return }
            isochrone = await isochroneService.polygon(
                origin: origin,
                rangeKm: settings.profile.safeRangeKm
            )
        }
        .onChange(of: selectedID) { _, _ in Haptic.tap() }
        .safeAreaInset(edge: .bottom) {
            if let selectedCandidate {
                selectedPanel(selectedCandidate)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: selectedID)
        .sheet(item: $detailCandidate) { candidate in
            ScrollView {
                StationCard(
                    candidate: candidate,
                    rank: (candidates.firstIndex(of: candidate) ?? 0) + 1,
                    total: candidates.count
                )
                .padding(18)
            }
            .background(SBScreenBackground())
            .presentationDetents([.large])
        }
    }

    private var selectedCandidate: StationCandidate? {
        candidates.first { $0.id == selectedID }
    }

    private func selectedPanel(_ candidate: StationCandidate) -> some View {
        Button {
            detailCandidate = candidate
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.onActionPrimary)
                    .frame(width: 48, height: 48)
                    .background(SBColor.actionPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.station.name)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.contentPrimary)
                        .lineLimit(1)
                    Text(String(format: "%.1f km · %@", candidate.distanceKm, candidate.station.power))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SBColor.contentTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.actionPrimary)
            }
            .padding(12)
            .sbPremiumGlass(radius: SBRadius.lg, interactive: true)
            .sbCardShadow()
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityHint(settings.t("map.open_detail"))
    }

    private func frameCandidates() {
        let points = candidates.prefix(80).map {
            MKMapPoint(CLLocationCoordinate2D(latitude: $0.station.latitude, longitude: $0.station.longitude))
        } + (search.userLocation.map {
            [MKMapPoint(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))]
        } ?? [])
        guard let first = points.first else { return }

        var rect = MKMapRect(x: first.x, y: first.y, width: 1, height: 1)
        for point in points.dropFirst() {
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        position = .rect(rect.insetBy(dx: -6_000, dy: -6_000))
    }

    private var isochroneTaskID: String {
        guard let location = search.userLocation else { return "none" }
        return "\(location.latitude)-\(location.longitude)-\(Int(settings.profile.safeRangeKm))"
    }
}

private struct StationPowerPin: View {
    let candidate: StationCandidate
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: isSelected ? 14 : 12, style: .continuous)
                    .fill(fillColor)
                RoundedRectangle(cornerRadius: isSelected ? 14 : 12, style: .continuous)
                    .stroke(borderColor, lineWidth: candidate.station.powerKW < 50 ? 2 : 1)
                Image(systemName: symbol)
                    .font(.caption.weight(.black))
                    .foregroundStyle(foregroundColor)
            }
            .frame(width: isSelected ? 42 : 36, height: isSelected ? 42 : 36)

            Text(powerLabel)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(SBColor.contentPrimary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(SBColor.surfaceGlassStrong, in: Capsule())
                .overlay(Capsule().stroke(SBColor.divider, lineWidth: 1))
        }
        .shadow(color: SBColor.canvas.opacity(0.34), radius: 8, y: 5)
        .scaleEffect(isSelected ? 1.06 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(candidate.station.name), \(candidate.station.power)")
    }

    private var fillColor: Color {
        if candidate.hasRiskyStatus { return SBColor.danger }
        if candidate.station.powerKW >= 100 { return SBColor.stationHighPower }
        if candidate.station.powerKW >= 50 { return SBColor.stationMediumPower }
        return SBColor.surfaceInteractive
    }

    private var borderColor: Color {
        if candidate.hasRiskyStatus { return SBColor.danger }
        if candidate.station.powerKW < 50 { return SBColor.stationStandardPower }
        return SBColor.dividerStrong
    }

    private var foregroundColor: Color {
        candidate.station.powerKW < 50 && !candidate.hasRiskyStatus
            ? SBColor.contentPrimary
            : SBColor.onActionPrimary
    }

    private var symbol: String {
        if candidate.hasRiskyStatus { return "exclamationmark.triangle.fill" }
        if candidate.station.powerKW >= 100 { return "bolt.fill" }
        if candidate.station.powerKW >= 50 { return "bolt" }
        return "powerplug"
    }

    private var powerLabel: String {
        if candidate.station.powerKW >= 100 { return "HPC" }
        if candidate.station.powerKW >= 50 { return "DC" }
        if candidate.station.powerKW > 0 { return "<50" }
        return "?"
    }
}
