import MapKit
import SarjBulCore
import SwiftUI

struct StationCard: View {
    var candidate: StationCandidate
    var rank: Int

    @State private var camera: MapCameraPosition

    init(candidate: StationCandidate, rank: Int) {
        self.candidate = candidate
        self.rank = rank
        let center = CLLocationCoordinate2D(latitude: candidate.station.latitude, longitude: candidate.station.longitude)
        _camera = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
        )))
    }

    var body: some View {
        VStack(spacing: 0) {
            mapPreview
            details
        }
        .background(SBColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 16)
    }

    private var mapPreview: some View {
        Map(position: $camera) {
            Marker(candidate.station.name, coordinate: CLLocationCoordinate2D(
                latitude: candidate.station.latitude,
                longitude: candidate.station.longitude
            ))
            .tint(SBColor.navy)
        }
        .frame(height: 210)
        .overlay(alignment: .topLeading) {
            Button {
                openInAppleMaps()
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(SBColor.navy)
                    .clipShape(Circle())
                    .shadow(radius: 12)
            }
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
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(16)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: "%.1f km", candidate.distanceKm))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                    Text("\(candidate.estimatedMinutes) dk · varış %\(Int(candidate.arrivalChargePercent.rounded()))")
                        .font(.headline)
                        .foregroundStyle(SBColor.muted)
                }
                Spacer()
                Text(String(format: "%02d", rank))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(SBColor.navy)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.station.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                Text(candidate.station.operatorName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SBColor.muted)
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
                        .foregroundStyle(badge.tone == .warning ? .orange : SBColor.navy)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.72))
                        .clipShape(Capsule())
                }
            }

            SBPrimaryButton(title: "Rotayı Aç", systemImage: "map") {
                openInAppleMaps()
            }

            Text(candidate.station.address)
                .font(.footnote)
                .foregroundStyle(SBColor.muted)
                .lineLimit(3)
        }
        .padding(20)
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
        .background(.white.opacity(0.70))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

