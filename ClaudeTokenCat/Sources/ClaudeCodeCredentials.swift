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
        switch loadKeychainData() {
        case .success(let oauth):
            guard let token = oauth["accessToken"] as? String else {
                return .notFound
            }
            return .success(token)
        case .notFound:
            return .notFound
        case .accessDenied:
            return .accessDenied
        }
    }

    static func loadRefreshToken() -> String? {
        guard case .success(let oauth) = loadKeychainData() else { return nil }
        return oauth["refreshToken"] as? String
    }

    static func saveTokens(accessToken: String, refreshToken: String, expiresAt: String) -> Bool {
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
        guard status == errSecSuccess,
              let data = result as? Data,
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        var oauth = (json["claudeAiOauth"] as? [String: Any]) ?? [:]
        oauth["accessToken"] = accessToken
        oauth["refreshToken"] = refreshToken
        oauth["expiresAt"] = expiresAt
        json["claudeAiOauth"] = oauth

        guard let updatedData = try? JSONSerialization.data(withJSONObject: json) else {
            return false
        }

        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: updatedData
        ]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
        return updateStatus == errSecSuccess
    }

    // MARK: - Private

    private enum OAuthResult {
        case success([String: Any])
        case notFound
        case accessDenied
    }

    private static func loadKeychainData() -> OAuthResult {
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
                  let oauth = json["claudeAiOauth"] as? [String: Any] else {
                return .notFound
            }
            return .success(oauth)
        case errSecItemNotFound:
            return .notFound
        default:
            return .accessDenied
        }
    }

}
