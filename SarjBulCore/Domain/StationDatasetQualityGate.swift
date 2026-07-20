public enum StationDatasetQualityGate {
    public static func minimumAcceptedCount(referenceCount: Int) -> Int {
        max(1_000, Int(Double(referenceCount) * 0.70))
    }

    public static func accepts(candidateCount: Int, referenceCount: Int) -> Bool {
        candidateCount >= minimumAcceptedCount(referenceCount: referenceCount)
    }
}
