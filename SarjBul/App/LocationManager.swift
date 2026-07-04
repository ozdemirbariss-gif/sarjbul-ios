import CoreLocation
import Foundation
import SarjBulCore

@MainActor
final class LocationManager: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: UserLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestLocation() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .notDetermined {
            #if os(macOS)
            manager.requestAlwaysAuthorization()
            #else
            manager.requestWhenInUseAuthorization()
            #endif
        } else if locationAccessGranted {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if locationAccessGranted {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        lastLocation = UserLocation(latitude: coordinate.latitude, longitude: coordinate.longitude, source: .device)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // UI manuel konum kartını göstermeye devam eder.
    }

    private var locationAccessGranted: Bool {
        #if os(macOS)
        authorizationStatus == .authorizedAlways
        #else
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
        #endif
    }
}
