import Foundation
import XCTest
@testable import SarjBul

@MainActor
final class AppTelemetryPrivacyTests: XCTestCase {
    func testNetworkErrorCannotForwardRequestURLOrUnderlyingUserInfo() {
        let original = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [
            NSURLErrorFailingURLErrorKey: URL(string: "https://fixture.invalid/?auth=secret&latitude=38.12345") as Any,
            NSLocalizedDescriptionKey: "private station and calendar title",
            NSUnderlyingErrorKey: NSError(domain: "private-user-id", code: 123)
        ])
        let result = AppTelemetry.sanitizedError(original, operation: "context_weather")
        XCTAssertEqual(result.domain, NSURLErrorDomain)
        XCTAssertEqual(result.code, NSURLErrorTimedOut)
        XCTAssertEqual(result.userInfo as? [String: String], [NSLocalizedDescriptionKey: "context_weather"])
    }

    func testUnknownDomainAndDynamicOperationAreDiscarded() {
        let original = NSError(domain: "user@example.invalid", code: 987654321, userInfo: [:])
        let result = AppTelemetry.sanitizedError(original, operation: "demand:38p1_27p2:private-id")
        XCTAssertEqual(result.domain, "SarjBul.OperationError")
        XCTAssertEqual(result.code, 1)
        XCTAssertEqual(result.userInfo as? [String: String], [NSLocalizedDescriptionKey: "unclassified_operation"])
    }
}
