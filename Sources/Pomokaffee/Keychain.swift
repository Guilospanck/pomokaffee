import Foundation
import Security

/// One generic-password item per key, in the login keychain, under the app's bundle id.
enum Keychain {
    private static let service = Bundle.main.bundleIdentifier ?? "com.guilospanck.pomokaffee"

    private static func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
    }

    static func get(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Stores `value`, replacing the old one only after the new one is saved; an empty value deletes the item.
    /// Returns false if the Keychain refused.
    @discardableResult
    static func set(_ key: String, _ value: String) -> Bool {
        guard !value.isEmpty else {
            let s = SecItemDelete(query(key) as CFDictionary)
            return s == errSecSuccess || s == errSecItemNotFound
        }
        let data = Data(value.utf8)
        var status = SecItemUpdate(query(key) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query(key)
            q[kSecValueData as String] = data
            status = SecItemAdd(q as CFDictionary, nil)
        }
        if status != errSecSuccess { Log.write("keychain write failed for \(key): \(status)") }
        return status == errSecSuccess
    }
}
