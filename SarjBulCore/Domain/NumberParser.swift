import Foundation

enum NumberParser {
    static func firstDecimal(in text: String) -> Double? {
        var buffer = ""
        var hasDigit = false

        for character in text.replacingOccurrences(of: ",", with: ".") {
            if character.isNumber || character == "." {
                buffer.append(character)
                if character.isNumber {
                    hasDigit = true
                }
            } else if hasDigit {
                break
            }
        }

        return hasDigit ? Double(buffer) : nil
    }
}

