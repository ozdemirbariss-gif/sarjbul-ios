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
final class PlaceSearchModel: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet { completer.queryFragment = query }
    }
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    @Published private(set) var isResolving = false
    @Published private(set) var errorMessage: String?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0),
            span: MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 24)
        )
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = Array(completer.results.prefix(12))
        errorMessage = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> JourneyDestination? {
        isResolving = true
        defer { isResolving = false }
        do {
            let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
            guard let item = response.mapItems.first else { return nil }
            return JourneyDestination(
                name: item.name ?? completion.title,
                address: completion.subtitle,
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

struct PlaceSearchSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PlaceSearchModel()
    let mode: PlaceSearchMode
    let selection: (JourneyDestination) -> Void

    var body: some View {
        NavigationStack {
            List {
                if model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        appState.t(mode == .origin ? "place.origin_hint" : "place.destination_hint"),
                        systemImage: mode == .origin ? "location" : "flag.checkered"
                    )
                } else if model.results.isEmpty && model.errorMessage == nil {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                ForEach(Array(model.results.enumerated()), id: \.offset) { _, result in
                    Button {
                        Task {
                            guard let destination = await model.resolve(result) else { return }
                            selection(destination)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(SBColor.electricBlue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.headline)
                                    .foregroundStyle(SBColor.ink)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(SBColor.muted)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .disabled(model.isResolving)
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(SBColor.danger)
                }
            }
            .searchable(
                text: $model.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: appState.t("place.search_prompt")
            )
            .navigationTitle(appState.t(mode == .origin ? "place.origin_title" : "place.destination_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appState.t("auth.delete_cancel")) { dismiss() }
                }
            }
        }
    }
}
