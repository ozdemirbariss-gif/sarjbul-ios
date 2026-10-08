import Foundation
import Observation
import SarjBulCore

@MainActor
@Observable
final class UserSettingsStore {
    private let persistence: any AppPersistence

    var language: AppLanguage {
        didSet { persistence.language = language }
    }
    var appearance: AppAppearance {
        didSet { persistence.appearance = appearance }
    }
    var navigationAppPreference: NavigationAppPreference? {
        didSet { persistence.navigationAppPreference = navigationAppPreference }
    }
    var profile: DrivingProfile {
        didSet {
            persistence.profile = profile
            if profile != oldValue { persistence.manualProfileUpdatedAt = Date() }
        }
    }
    var manualProfileUpdatedAt: Date? { persistence.manualProfileUpdatedAt }
    var filters = StationFilters()
    // Apple search results are temporary session state, never a saved address book.
    var destination: JourneyDestination?
    var demandAnalyticsEnabled: Bool {
        didSet { persistence.demandAnalyticsEnabled = demandAnalyticsEnabled }
    }
    var autonomousChargingPolicy: AutonomousChargingPolicy {
        didSet { persistence.autonomousChargingPolicy = autonomousChargingPolicy }
    }
    let externalLinks: AppExternalLinks

    init(persistence: any AppPersistence, externalLinks: AppExternalLinks) {
        self.persistence = persistence
        language = persistence.language
        appearance = persistence.appearance
        navigationAppPreference = persistence.navigationAppPreference
        profile = persistence.profile
        demandAnalyticsEnabled = persistence.demandAnalyticsEnabled
        autonomousChargingPolicy = persistence.autonomousChargingPolicy
        self.externalLinks = externalLinks
    }

    func t(_ key: String, _ replacements: [String: String] = [:]) -> String {
        AppLocalization.text(key, language: language, replacements: replacements)
    }

    func setLanguage(code: String) {
        language = AppLanguage(code: code)
    }
}
