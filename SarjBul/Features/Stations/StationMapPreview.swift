import MapKit
import SarjBulCore
import SwiftUI

struct StationMapPreview: View {
    let station: Station
    let origin: SarjBulCore.UserLocation?
    let route: StationRoute?
    var interactive = false

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position, interactionModes: interactive ? [.pan, .zoom, .rotate] : []) {
            if let origin {
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: origin.latitude,
                    longitude: origin.longitude
                )) {
                    Circle()
                        .fill(SBColor.accent)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .shadow(color: SBColor.accent.opacity(0.45), radius: 12)
                }
            }

            Marker(
                station.name,
                systemImage: "bolt.fill",
                coordinate: CLLocationCoordinate2D(
                    latitude: station.latitude,
                    longitude: station.longitude
                )
            )
            .tint(SBColor.electricBlue)

            if let route {
                MapPolyline(route.polyline)
                    .stroke(SBColor.electricBlue, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: true))
        .mapControls {
            if interactive {
                MapCompass()
                MapScaleView()
            }
        }
        .onAppear(perform: updateCamera)
        .onChange(of: route?.distanceKm) { _, _ in updateCamera() }
        .onChange(of: station.id) { _, _ in updateCamera() }
        .accessibilityLabel(station.name)
    }

    private func updateCamera() {
        if let route {
            let padded = route.polyline.boundingMapRect.insetBy(dx: -1_500, dy: -1_500)
            position = .rect(padded)
            return
        }

        if let origin {
            let stationPoint = MKMapPoint(CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude))
            let originPoint = MKMapPoint(CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude))
            let rect = MKMapRect(
                x: min(stationPoint.x, originPoint.x),
                y: min(stationPoint.y, originPoint.y),
                width: max(1_500, abs(stationPoint.x - originPoint.x)),
                height: max(1_500, abs(stationPoint.y - originPoint.y))
            )
            position = .rect(rect.insetBy(dx: -2_000, dy: -2_000))
        } else {
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
            ))
        }
    }
}

struct FullRouteMapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let candidate: StationCandidate
    let route: StationRoute?

    var body: some View {
        NavigationStack {
            StationMapPreview(
                station: candidate.station,
                origin: appState.userLocation,
                route: route,
                interactive: true
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(candidate.station.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.t("status.ok")) { dismiss() }
                }
            }
        }
    }
}
