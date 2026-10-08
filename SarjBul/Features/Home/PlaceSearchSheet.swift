import Combine
@preconcurrency import MapKit
import SarjBulCore
import SwiftUI

enum PlaceSearchMode: String, Identifiable {
    case origin
    case destination

    var id: String { rawValue }
}

@MainActor
final class PlaceSearchModel: ObservableObject {
    @Published var query = ""
    @Published var position: MapCameraPosition = .automatic
    @Published private(set) var results: [MKMapItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?

    func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []
        errorMessage = nil
        isSearching = !text.isEmpty
        guard !text.isEmpty else { return }
        do {
            try await Task.sleep(for: .milliseconds(350))
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            request.resultTypes = [.address, .pointOfInterest]
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0),
                span: MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 24)
            )
            let response = try await MKLocalSearch(request: request).start()
            try Task.checkCancellation()
            guard query.trimmingCharacters(in: .whitespacesAndNewlines) == text else { return }
            results = Array(response.mapItems.prefix(12))
            position = .automatic
            isSearching = false
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            isSearching = false
        }
    }
}

struct PlaceSearchSheet: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = PlaceSearchModel()
    let mode: PlaceSearchMode
    let selection: (JourneyDestination) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !model.results.isEmpty {
                    // Attachment 6 §2.4: each displayed address has a matching Apple map.
                    Map(position: $model.position) {
                        ForEach(Array(model.results.enumerated()), id: \.offset) { _, item in
                            Marker(item.name ?? "", coordinate: item.placemark.coordinate)
                        }
                    }
                    .frame(height: 220)
                    .accessibilityIdentifier("place-search-map")
                }
                List {
                    if model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView(
                            settings.t(mode == .origin ? "place.origin_hint" : "place.destination_hint"),
                            systemImage: mode == .origin ? "location" : "flag.checkered"
                        )
                    } else if model.isSearching {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                    ForEach(Array(model.results.enumerated()), id: \.offset) { _, item in
                        Button {
                            selection(JourneyDestination(
                                name: item.name ?? "",
                                address: item.placemark.title ?? "",
                                latitude: item.placemark.coordinate.latitude,
                                longitude: item.placemark.coordinate.longitude
                            ))
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "")
                                    .font(.headline)
                                    .foregroundStyle(SBColor.contentPrimary)
                                Text(item.placemark.title ?? "")
                                    .font(.caption)
                                    .foregroundStyle(SBColor.contentTertiary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(SBColor.surfaceBase)
                    }
                    if let errorMessage = model.errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(SBColor.danger)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(SBScreenBackground())
            .searchable(
                text: $model.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: settings.t("place.search_prompt")
            )
            .task(id: model.query) { await model.search() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { model.query = "" }
            }
            .navigationTitle(settings.t(mode == .origin ? "place.origin_title" : "place.destination_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("status.cancel")) { dismiss() }
                }
            }
        }
    }
}

struct PlaceResultMap: View {
    let latitude: Double
    let longitude: Double

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))) {
            Marker("", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        .id("\(latitude):\(longitude)")
    }
}
