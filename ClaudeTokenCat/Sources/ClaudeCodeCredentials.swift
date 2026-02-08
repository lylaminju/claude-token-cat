import Foundation
import Security

/// Reads OAuth credentials stored by Claude Code CLI in the macOS Keychain.
struct ClaudeCodeCredentials {

    private static let service = "Claude Code-credentials"

    /// Attempts to load the OAuth access token from Claude Code's Keychain entry.
    /// Returns nil if no credentials are found or parsing fails.
    static func loadAccessToken() -> String? {
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

        guard status == errSecSuccess, let data = result as? Data else { return nil }

        // Parse JSON: { "claudeAiOauth": { "accessToken": "...", ... } }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String else {
            return nil
        }

        return accessToken
    }
}
