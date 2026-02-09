import Foundation
import Security

enum KeychainResult {
    case success(String)
    case notFound
    case accessDenied
}

/// Reads OAuth credentials stored by Claude Code CLI in the macOS Keychain.
struct ClaudeCodeCredentials {

    private static let service = "Claude Code-credentials"

    static func loadAccessToken() -> KeychainResult {
        let account = NSUserName()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let oauth = json["claudeAiOauth"] as? [String: Any],
                  let token = oauth["accessToken"] as? String else {
                return .notFound
            }
            return .success(token)
        case errSecItemNotFound:
            return .notFound
        default:
            // errSecUserCanceled (Deny clicked), errSecAuthFailed,
            // errSecInteractionNotAllowed, etc.
            return .accessDenied
        }
    }

}
