import Foundation
import SarjBulCore

struct APNsDeviceRegistration: Codable, Equatable, Sendable {
    let token: String
    let environment: PushTokenEnvironment

    init(deviceToken: Data, environment: PushTokenEnvironment) {
        token = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.environment = environment
    }
}

@MainActor
enum APNsDeviceTokenInbox {
    static let didUpdate = Notification.Name("com.ozdemirbaris.sarjbul.apns-device-token-did-update")
    private static let storageKey = "apnsDeviceRegistration"

    static var latest: APNsDeviceRegistration? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(APNsDeviceRegistration.self, from: data)
    }

    static func receive(_ registration: APNsDeviceRegistration) {
        if let data = try? JSONEncoder().encode(registration) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        NotificationCenter.default.post(name: didUpdate, object: registration)
    }

}

@MainActor
final class PushTokenRegistrationStore {
    private let client: any PushTokenClient
    private var completedRegistrations = Set<String>()
    private var registrationsInFlight = Set<String>()

    init(client: any PushTokenClient) {
        self.client = client
    }

    func register(_ registration: APNsDeviceRegistration, using auth: AuthStore) async {
        do {
            try await auth.authenticatedRequest { [self, client] session in
                try await upload(registration, session: session, client: client)
            }
        } catch {
            AppLogger.data.warning(
                "Push token upload deferred: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func register(_ registration: APNsDeviceRegistration, session: FirebaseAuthSession) async {
        do {
            try await upload(registration, session: session, client: client)
        } catch {
            AppLogger.data.warning(
                "Push token refresh upload deferred: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func upload(
        _ registration: APNsDeviceRegistration,
        session: FirebaseAuthSession,
        client: any PushTokenClient
    ) async throws {
        let key = "\(session.uid):\(registration.environment.rawValue):\(registration.token)"
        guard !completedRegistrations.contains(key), !registrationsInFlight.contains(key) else { return }
        registrationsInFlight.insert(key)
        do {
            try await client.registerPushToken(
                registration.token,
                environment: registration.environment,
                uid: session.uid,
                idToken: session.idToken
            )
            registrationsInFlight.remove(key)
            completedRegistrations.insert(key)
        } catch {
            registrationsInFlight.remove(key)
            throw error
        }
    }
}
