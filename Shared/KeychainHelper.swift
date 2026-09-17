import Foundation
import Security

/// Stores the Transmission RPC password in the Keychain so it's available
/// to both the host app and the widget extension. Requires the "Keychain
/// Sharing" capability enabled on BOTH targets with a matching access group.
enum KeychainHelper {
    /// project.yml declares the keychain-access-group as
    /// "$(AppIdentifierPrefix)com.halozero.transmissionwidget" for both targets,
    /// which Xcode resolves to "<YourTeamID>.com.halozero.transmissionwidget" at
    /// build time. Fill in your Team ID below (Xcode → Signing & Capabilities
    /// will show it once DEVELOPMENT_TEAM is set), or check the built app's
    /// entitlements to confirm the exact resolved string.
    static var accessGroup: String? = "YOUR_TEAM_ID.com.halozero.transmissionwidget"

    private static let service = "com.halozero.transmissionwidget.password"
    private static let account = "transmission-rpc"

    static func savePassword(_ password: String) {
        let data = Data(password.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            print("KeychainHelper: failed to save password, status \(status)")
        }
    }

    static func loadPassword() -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deletePassword() {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }
        SecItemDelete(query as CFDictionary)
    }
}
