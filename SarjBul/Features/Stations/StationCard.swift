import MapKit
import SarjBulCore
import SwiftUI

struct StationCard: View {
    @Environment(AppState.self) private var appState
    var candidate: StationCandidate
    var rank: Int

    var body: some View {
        VStack(spacing: 0) {
            mapPreview
            details
        }
        .background(SBColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                .stroke(SBColor.line, lineWidth: 1)
        )
        .sbCardShadow()
    }

    private var mapPreview: some View {
        StationMapPreview(station: candidate.station)
        .overlay(alignment: .topLeading) {
            Button {
                Haptic.tap()
                openInAppleMaps()
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(SBColor.electricBlue)
                    .clipShape(Circle())
                    .sbGlowShadow()
            }
            .accessibilityLabel("Rotayı Haritalar'da aç")
            .padding(16)
        }
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 2) {
                Text("\(candidate.score)")
                    .font(.title2.weight(.heavy))
                Text("SKOR")
                    .font(.caption2.weight(.black))
            }
            .foregroundStyle(SBColor.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(SBColor.glassStrong)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                    .stroke(SBColor.line, lineWidth: 1)
            )
            .padding(16)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: "%.1f km", candidate.distanceKm))
                        .font(SBFont.display(size: 42, weight: .heavy))
                    Text("\(candidate.estimatedMinutes) dk · varış %\(Int(candidate.arrivalChargePercent.rounded()))")
                        .font(.headline)
                        .foregroundStyle(SBColor.muted)
                }
                Spacer()
                Text(String(format: "%02d", rank))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(SBColor.electricBlue)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(candidate.station.name)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                    Text(candidate.station.operatorName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SBColor.muted)
                }
                Spacer(minLength: 8)
                favoriteButton
            }

            HStack(spacing: 8) {
                metric("GÜÇ", candidate.station.power)
                metric("SOKET", candidate.station.socket)
                metric("FİYAT", candidate.station.price)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
                ForEach(candidate.badges, id: \.self) { badge in
                    Text(badge.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(badgeColor(badge.tone))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(SBColor.glass)
                        .clipShape(Capsule())
                }
            }

            SBPrimaryButton(title: "Rotayı Aç", systemImage: "map") {
                Haptic.tap()
                openInAppleMaps()
            }

            if appState.isAuthenticated {
                statusActions
            }

            Text(candidate.station.address)
                .font(.footnote)
                .foregroundStyle(SBColor.muted)
                .lineLimit(3)
        }
        .padding(20)
    }

    private var favoriteButton: some View {
        let stationKey = candidate.station.statusKey
        return Button {
            Haptic.tap()
            Task { await appState.toggleFavorite(stationKey) }
        } label: {
            Image(systemName: appState.isFavorite(stationKey) ? "heart.fill" : "heart")
                .font(.headline.weight(.bold))
                .foregroundStyle(appState.isFavorite(stationKey) ? SBColor.danger : SBColor.electricBlue)
                .frame(width: 42, height: 42)
                .background(SBColor.glass)
                .clipShape(Circle())
        }
        .accessibilityLabel(appState.isFavorite(stationKey) ? "Favoriden çıkar" : "Favoriye ekle")
    }

    private var statusActions: some View {
        HStack(spacing: 8) {
            reportButton("Uygun", icon: "checkmark.circle.fill")
            reportButton("Sorun var", icon: "exclamationmark.triangle.fill")
            reportButton("Sıra var", icon: "clock.fill")
        }
    }

    private func reportButton(_ title: String, icon: String) -> some View {
        Button {
            Haptic.tap()
            Task { await appState.reportStatus(stationKey: candidate.station.statusKey, status: title) }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(SBColor.glass)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func badgeColor(_ tone: StationBadge.Tone) -> Color {
        switch tone {
        case .good, .info:
            SBColor.electricBlue
        case .warning:
            SBColor.warning
        case .risk:
            SBColor.danger
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(SBColor.muted)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(SBColor.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SBColor.glass)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                .stroke(SBColor.line, lineWidth: 1)
        )
    }

    private func openInAppleMaps() {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: candidate.station.latitude,
            longitude: candidate.station.longitude
        )))
        destination.name = candidate.station.name
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
