import Foundation
import SwiftData
import AuthenticationServices

/// iCloud sync is compiled in only when the `CLOUD_SYNC` build flag is set in
/// project.yml, which happens once the app is signed with an Apple Developer team
/// that has the iCloud (CloudKit) capability. Until then the app stays local-only.
enum CloudSync {
    static let containerID = "iCloud.app.longgame.LongGame"
    private static let enabledKey = "sync.enabled"

    static var isAvailable: Bool {
        #if CLOUD_SYNC
        true
        #else
        false
        #endif
    }

    /// The user's choice. Read at launch, so a change applies after a restart.
    static var isEnabled: Bool {
        get { isAvailable && UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static func configuration(for schema: Schema) -> ModelConfiguration {
        isEnabled
            ? ModelConfiguration(schema: schema, cloudKitDatabase: .private(containerID))
            : ModelConfiguration(schema: schema, cloudKitDatabase: .none)
    }
}

/// Remembers who signed in with Apple. Only the opaque user id is kept; no name or email.
@MainActor
@Observable
final class AccountStore {
    private static let userKey = "account.appleUserID"

    private(set) var userID: String? = UserDefaults.standard.string(forKey: AccountStore.userKey)

    var isSignedIn: Bool { userID != nil }

    func handle(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
        userID = credential.user
        UserDefaults.standard.set(credential.user, forKey: Self.userKey)
    }

    func signOut() {
        userID = nil
        UserDefaults.standard.removeObject(forKey: Self.userKey)
    }

    /// Signs out if the person revoked access in iOS Settings.
    func refreshState() async {
        guard let userID, CloudSync.isAvailable else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
        if state == .revoked || state == .notFound { signOut() }
    }
}
