import Observation

@MainActor
@Observable
final class LoungeStore {
    private let persistence: any AppPersistence
    var bestScore: Int {
        didSet { persistence.loungeBestScore = bestScore }
    }

    init(persistence: any AppPersistence) {
        self.persistence = persistence
        bestScore = persistence.loungeBestScore
    }
}
