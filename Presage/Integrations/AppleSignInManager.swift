import AuthenticationServices
import SwiftUI
import Foundation

/// Optional Sign in with Apple — required only if the user enables iCloud
/// sync, otherwise unused. Pari has no accounts by design; this exists
/// solely so iCloud-syncing users can verify their identity if they choose.
@MainActor
final class AppleSignInManager {
    static let shared = AppleSignInManager()

    private let userIDKey = "appleUserID"

    var signedInUserID: String? {
        UserDefaults.standard.string(forKey: userIDKey)
    }

    var isSignedIn: Bool {
        signedInUserID != nil
    }

    func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        UserDefaults.standard.set(credential.user, forKey: userIDKey)
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
    }

    /// Verifies the stored Apple ID is still valid. Bounded timeout so
    /// the call never hangs forever if the system never invokes the
    /// callback (which has happened in the wild on flaky network/iCloud
    /// states).
    func validateExistingCredential() async -> Bool {
        guard let userID = signedInUserID else { return false }
        let provider = ASAuthorizationAppleIDProvider()

        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    var resumed = false
                    provider.getCredentialState(forUserID: userID) { state, _ in
                        if !resumed {
                            resumed = true
                            continuation.resume(returning: state == .authorized)
                        }
                    }
                }
            }
            group.addTask {
                // 5-second ceiling.
                try? await Task.sleep(for: .seconds(5))
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }
}

struct AppleSignInButton: View {
    let onComplete: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = []
        } onCompletion: { result in
            onComplete(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}
