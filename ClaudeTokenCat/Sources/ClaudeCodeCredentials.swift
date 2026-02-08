import Foundation
import Security

/// Reads OAuth credentials stored by Claude Code CLI in the macOS Keychain.
struct ClaudeCodeCredentials {

    private static let service = "Claude Code-credentials"

    /// Loads the raw OAuth dictionary from the Keychain.
    private static func loadOAuthDict() -> [String: Any]? {
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

        guard status == errSecSuccess, let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any] else {
            return nil
        }

        return oauth
    }

    static func loadAccessToken() -> String? {
        loadOAuthDict()?["accessToken"] as? String
    }

}
