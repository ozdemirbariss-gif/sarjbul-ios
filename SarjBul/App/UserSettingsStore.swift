import Observation
import SarjBulCore

@MainActor
@Observable
final class UserSettingsStore {
    private let persistence: any AppPersistence

    var language: AppLanguage {
        didSet { persistence.language = language }
    }
    var profile: DrivingProfile {
        didSet { persistence.profile = profile }
    }
    var filters = StationFilters()
    var destination: JourneyDestination? {
        didSet { persistence.destination = destination }
    }
    let externalLinks: AppExternalLinks

    init(persistence: any AppPersistence, externalLinks: AppExternalLinks) {
        self.persistence = persistence
        language = persistence.language
        profile = persistence.profile
        destination = persistence.destination
        self.externalLinks = externalLinks
    }

    func t(_ key: String, _ replacements: [String: String] = [:]) -> String {
        AppLocalization.text(key, language: language, replacements: replacements)
    }

    func setLanguage(code: String) {
        language = AppLanguage(code: code)
    }
}
