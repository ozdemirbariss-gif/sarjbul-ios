import Foundation

public enum StationDatasetQualityGate {
    public static func minimumAcceptedCount(referenceCount: Int) -> Int {
        max(1_000, Int(Double(referenceCount) * 0.70))
    }

    public static func accepts(candidateCount: Int, referenceCount: Int) -> Bool {
        candidateCount >= minimumAcceptedCount(referenceCount: referenceCount)
    }
}

/// The shipping app accepts a freshly normalized EPDK inventory only. The
/// unrestricted mode supports repositories used by domain tests and other clients.
public enum StationSourcePolicy: Sendable {
    case unrestricted
    case epdkOnly

    func accepts(manifestPolicy: String?) -> Bool {
        switch self {
        case .unrestricted: true
        case .epdkOnly: manifestPolicy == "epdk-only-v1"
        }
    }

    func decode(_ data: Data, using decoder: JSONDecoder) throws -> [Station] {
        if case .epdkOnly = self {
            let fields: Set<String> = [
                "id", "isim", "adres", "enlem", "boylam", "hiz", "operator", "soket", "fiyat",
                "kaynak", "kaynaklar", "source_ids", "epdk_license", "epdk_sockets", "guven_skoru",
                "sarj_uniteleri", "kaynak_gozlem_tarihi"
            ]
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  !rows.isEmpty else { throw StationRepositoryError.invalidRemoteData }
            var identifiers: Set<String> = []
            for row in rows {
                guard row["kaynak"] as? String == "epdk",
                      row["kaynaklar"] as? [String] == ["epdk"],
                      let sources = row["source_ids"] as? [String: String],
                      Set(sources.keys) == ["epdk"], let number = sources["epdk"],
                      number.hasPrefix("ŞRJ/"),
                      !number.dropFirst(4).isEmpty,
                      number.dropFirst(4).allSatisfy({ $0.isASCII && $0.isNumber }),
                      let identifier = row["id"] as? String,
                      identifier == "epdk_" + number.dropFirst(4),
                      identifiers.insert(identifier).inserted,
                      Set(row.keys).isSubset(of: fields) else {
                    throw StationRepositoryError.invalidRemoteData
                }
            }
        }
        return try decoder.decode([Station].self, from: data)
    }
}
