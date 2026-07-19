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

    var body: some View {
        Map(position: $position, selection: $selectedID) {
            if let origin = search.userLocation {
                Annotation(settings.t("map.current_location"), coordinate: CLLocationCoordinate2D(
                    latitude: origin.latitude,
                    longitude: origin.longitude
                )) {
                    ZStack {
                        Circle()
                            .fill(SBColor.accent.opacity(0.22))
                            .frame(width: 38, height: 38)
                        Circle()
                            .fill(SBColor.accent)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                }
            }

            ForEach(candidates) { candidate in
                Marker(
                    candidate.station.name,
                    systemImage: candidate.hasRiskyStatus ? "exclamationmark.triangle.fill" : "bolt.fill",
                    coordinate: CLLocationCoordinate2D(
                        latitude: candidate.station.latitude,
                        longitude: candidate.station.longitude
                    )
                )
                .tint(candidate.hasRiskyStatus ? SBColor.danger : pinColor(for: candidate))
                .tag(candidate.id)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: true))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapPitchToggle()
        }
        .onAppear(perform: frameCandidates)
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
                    .foregroundStyle(SBColor.accent)
                    .frame(width: 48, height: 48)
                    .background(SBColor.electricBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.station.name)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.ink)
                        .lineLimit(1)
                    Text(String(format: "%.1f km · %@", candidate.distanceKm, candidate.station.power))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SBColor.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.electricBlue)
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

    private func pinColor(for candidate: StationCandidate) -> Color {
        if candidate.station.powerKW >= 100 { return SBColor.accent }
        if candidate.station.powerKW >= 50 { return SBColor.primaryDeep }
        return SBColor.electricBlue
    }
}
