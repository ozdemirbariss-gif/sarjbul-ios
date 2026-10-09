import CarPlay
import Combine
import MapKit
import Observation
import SarjBulCore

@MainActor
final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate, CPPointOfInterestTemplateDelegate {
    private let app = AppRuntime.state
    private weak var interfaceController: CPInterfaceController?
    private var nearby: CPPointOfInterestTemplate?
    private var favorites: CPListTemplate?
    private var tabs: CPTabBarTemplate?
    private var mapCenter: UserLocation?
    private var fastOnly = false
    private var candidates: [StationCandidate] = []
    private var detail: (template: CPInformationTemplate, station: Station, candidate: StationCandidate?)?
    private var loadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let nearby = CPPointOfInterestTemplate(title: t("carplay.loading"), pointsOfInterest: [], selectedIndex: NSNotFound)
        nearby.pointOfInterestDelegate = self
        nearby.tabTitle = t("carplay.nearby")
        nearby.tabImage = UIImage(systemName: "bolt.car")
        let favorites = CPListTemplate(title: t("carplay.favorites"), sections: [])
        favorites.tabTitle = t("carplay.favorites")
        favorites.tabImage = UIImage(systemName: "star")
        self.nearby = nearby
        self.favorites = favorites
        let tabs = CPTabBarTemplate(templates: [nearby, favorites])
        self.tabs = tabs
        interfaceController.setRootTemplate(tabs, animated: false, completion: nil)
        updateButtons()
        observeStores()
        app.locationManager.$lastLocation.dropFirst().sink { [weak self] _ in
            // @Published emits before storing the value; read the state on the next actor turn.
            Task { @MainActor [weak self] in self?.refresh() }
        }.store(in: &subscriptions)
        app.locationManager.$authorizationStatus.dropFirst().sink { [weak self] _ in
            // @Published emits before storing the value; read the state on the next actor turn.
            Task { @MainActor [weak self] in self?.refresh() }
        }.store(in: &subscriptions)
        app.locationManager.startCarPlayUpdates()
        app.locationManager.requestFreshLocation()
        loadTask = Task { [weak self] in
            guard let self else { return }
            // Catalog access never depends on sign-in or on opening the phone scene.
            await app.stationData.load()
            guard !Task.isCancelled else { return }
            refresh()
        }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                self?.refresh()
            }
        }
        refresh()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        loadTask?.cancel()
        searchTask?.cancel()
        timerTask?.cancel()
        subscriptions.removeAll()
        app.locationManager.stopCarPlayUpdates()
        self.interfaceController = nil
        nearby = nil
        favorites = nil
        tabs = nil
        candidates = []
        detail = nil
        mapCenter = nil
    }

    func pointOfInterestTemplate(_ pointOfInterestTemplate: CPPointOfInterestTemplate, didChangeMapRegion region: MKCoordinateRegion) {
        guard pointOfInterestTemplate === nearby, CLLocationCoordinate2DIsValid(region.center) else { return }
        let next = UserLocation(latitude: region.center.latitude, longitude: region.center.longitude, source: .manual)
        if let center = mapCenter ?? deviceLocation,
           DistanceCalculator.haversineKm(from: center, toLatitude: next.latitude, longitude: next.longitude) < 2 { return }
        mapCenter = next
        refresh()
    }

    private func observeStores() {
        withObservationTracking {
            _ = app.stationData.stations
            _ = app.stationData.loadState
            _ = app.stationData.communityInsights
            _ = app.stationData.stationStatuses
            _ = app.favorites.favorites
            _ = app.settings.language
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, interfaceController != nil else { return }
                observeStores()
                refresh()
            }
        }
    }

    private func refresh() {
        guard interfaceController != nil else { return }
        updateButtons()
        updateFavorites()
        updateDetails()
        searchTask?.cancel()
        let origin = mapCenter ?? deviceLocation
        guard let origin else {
            nearby?.title = t("carplay.explore")
            nearby?.setPointsOfInterest([], selectedIndex: NSNotFound)
            return
        }
        let filters = StationFilters(preference: .nearest, minimumPowerKW: fastOnly ? 50 : 0, socketFilters: fastOnly ? ["CCS", "CHAdeMO"] : [], rangeFilterEnabled: false)
        searchTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            guard let self else { return }
            let values = await app.stationData.candidates(origin: origin, destination: nil, routePoints: [], profile: app.settings.profile, filters: filters, limit: 12)
            guard !Task.isCancelled, interfaceController != nil else { return }
            candidates = CarPlayStationPresenter.visibleCandidates(values)
            updateDetails()
            nearby?.title = candidates.isEmpty ? emptyTitle : t(mapCenter == nil ? "carplay.nearby" : "carplay.map_area")
            let points = candidates.map { makePoint(station: $0.station, candidate: $0) }
            update(nearby, points: points)
        }
    }

    private var deviceLocation: UserLocation? {
        CarPlayStationPresenter.currentLocation(app.locationManager.lastLocation, authorization: app.locationManager.authorizationStatus)
    }

    private var emptyTitle: String {
        switch app.stationData.loadState {
        case .idle, .loading: t("carplay.loading")
        case .failed: t("carplay.load_failed")
        case .loaded: t("carplay.empty")
        }
    }

    private func updateButtons() {
        nearby?.tabTitle = t("carplay.nearby")
        favorites?.tabTitle = t("carplay.favorites")
        nearby?.leadingNavigationBarButtons = [CPBarButton(title: t(fastOnly ? "carplay.fast" : "carplay.all")) { [weak self] _ in
            guard let self else { return }
            fastOnly.toggle()
            refresh()
        }]
        nearby?.trailingNavigationBarButtons = [CPBarButton(title: t("carplay.refresh")) { [weak self] _ in
            guard let self else { return }
            mapCenter = nil
            app.locationManager.requestFreshLocation()
            refresh()
            if app.stationData.canRetryLoad {
                loadTask?.cancel()
                loadTask = Task { [weak self] in
                    await self?.app.stationData.retry()
                    self?.refresh()
                }
            }
        }]
    }

    private func updateFavorites() {
        let stations = app.favorites.favoriteStations.filter(\.hasValidCoordinate).prefix(CPListTemplate.maximumItemCount)
        favorites?.emptyViewTitleVariants = [t("carplay.no_favorites")]
        let items = stations.map { station in
            let item = CPListItem(text: station.name, detailText: station.operatorName + " · " + station.power)
            item.handler = { [weak self] _, completion in
                self?.showDetails(station, candidate: nil)
                completion()
            }
            return item
        }
        favorites?.updateSections([CPListSection(items: items)])
    }

    private func update(_ template: CPPointOfInterestTemplate?, points: [CPPointOfInterest]) {
        let selectedKey: String?
        if let template, template.pointsOfInterest.indices.contains(template.selectedIndex) {
            selectedKey = template.pointsOfInterest[template.selectedIndex].userInfo as? String
        } else { selectedKey = nil }
        let selected = points.firstIndex { ($0.userInfo as? String) == selectedKey } ?? NSNotFound
        template?.setPointsOfInterest(points, selectedIndex: selected)
    }

    private func makePoint(station: Station, candidate: StationCandidate?) -> CPPointOfInterest {
        CarPlayStationPresenter.point(station: station, language: app.settings.language) { [weak self] in
            self?.openDirections(station)
        } details: { [weak self] in
            self?.showDetails(station, candidate: candidate)
        }
    }

    private func showDetails(_ station: Station, candidate: StationCandidate?) {
        let template = CPInformationTemplate(title: station.name, layout: .leading, items: informationItems(station, candidate: candidate),
                                             actions: [CPTextButton(title: t("carplay.directions"), textStyle: .confirm) { [weak self] _ in self?.openDirections(station) }])
        detail = (template, station, candidate)
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func updateDetails() {
        guard let detail else { return }
        guard interfaceController?.topTemplate === detail.template else { self.detail = nil; return }
        let latest = candidates.first { $0.station.statusKey == detail.station.statusKey } ?? detail.candidate
        detail.template.items = informationItems(detail.station, candidate: latest)
    }

    private func informationItems(_ station: Station, candidate: StationCandidate?) -> [CPInformationItem] {
        let evidence = StationEvidenceText(station: station, insight: app.stationData.insight(for: station.statusKey), live: candidate?.liveAvailability,
                                          risky: candidate?.hasRiskyStatus == true || app.stationData.stationStatuses[station.statusKey]?.durum == "riskli", language: app.settings.language)
        return [
            CPInformationItem(title: station.operatorName, detail: station.socket + " · " + station.power),
            CPInformationItem(title: t("feed.price") + ": " + evidence.price, detail: evidence.priceSource + "\n" + t("evidence.price_verify")),
            CPInformationItem(title: t("carplay.availability"), detail: evidence.availability),
            CPInformationItem(title: t("carplay.address"), detail: station.address)
        ]
    }

    private func openDirections(_ station: Station) {
        guard station.hasValidCoordinate else { return }
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)))
        destination.name = station.name
        // A destination-only Maps request uses the driver's current location, never a saved manual origin.
        let opened = destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        if opened { app.favorites.recordRouteOpened(station) } else {
            let alert = CPAlertTemplate(titleVariants: [t("carplay.maps_failed")], actions: [CPAlertAction(title: t("status.ok"), style: .default) { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }])
            interfaceController?.presentTemplate(alert, animated: true, completion: nil)
        }
    }

    private func t(_ key: String) -> String { app.settings.t(key) }
}
