import Foundation

enum NumberParser {
    static func firstDecimal(in text: String) -> Double? {
        var token = ""
        var hasDigit = false

        for character in text {
            if character.isNumber || character == "." || character == "," {
                token.append(character)
                if character.isNumber {
                    hasDigit = true
                }
            } else if hasDigit {
                break
            }
        }

        guard hasDigit else { return nil }
        return Double(normalizedDecimalToken(token))
    }

    private static func normalizedDecimalToken(_ token: String) -> String {
        let dotCount = token.filter { $0 == "." }.count
        let commaCount = token.filter { $0 == "," }.count

        if dotCount > 0 && commaCount > 0 {
            let decimalSeparator: Character = token.lastIndex(of: ",")! > token.lastIndex(of: ".")! ? "," : "."
            return normalizeMixedSeparators(token, decimalSeparator: decimalSeparator)
        }

        if commaCount > 0 {
            return normalizeSingleSeparator(token, separator: ",")
        }

        if dotCount > 0 {
            return normalizeSingleSeparator(token, separator: ".")
        }

        return token
    }

    private static func normalizeMixedSeparators(_ token: String, decimalSeparator: Character) -> String {
        token.compactMap { character -> Character? in
            if character.isNumber { return character }
            if character == decimalSeparator { return "." }
            return nil
        }
        .map(String.init)
        .joined()
    }

    private static func normalizeSingleSeparator(_ token: String, separator: Character) -> String {
        let parts = token.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count > 1 else { return token }

        let lastCount = parts.last?.count ?? 0
        let looksLikeGrouping = lastCount == 3 && parts.dropLast().allSatisfy { (1...3).contains($0.count) }
        if looksLikeGrouping {
            return parts.joined()
        }

        let integerPart = parts.dropLast().joined()
        let decimalPart = parts.last ?? ""
        return "\(integerPart).\(decimalPart)"
    }
}
