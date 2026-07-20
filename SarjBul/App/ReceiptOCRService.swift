import CoreGraphics
import Foundation
import SarjBulCore
import Vision

actor ReceiptOCRService {
    enum Error: LocalizedError {
        case invalidImage
        case noChargingValues

        var errorDescription: String? {
            switch self {
            case .invalidImage: "The receipt image could not be read."
            case .noChargingValues: "No energy or price value was found on the receipt."
            }
        }
    }

    func recognize(cgImage: CGImage) throws -> ParsedChargingReceipt {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["tr-TR", "en-US"]
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        let receipt = ChargingReceiptParser.parse(text)
        guard receipt.energyKWh != nil || receipt.totalCostTRY != nil else { throw Error.noChargingValues }
        return receipt
    }
}
