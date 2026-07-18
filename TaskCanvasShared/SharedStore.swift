import Foundation
import Security

final class SharedStore {
    static let appGroupID = "group.49BW44PPG7.com.codex.TaskCanvas"

    private let sharedDefaults: UserDefaults?
    private let standardDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let snapshotKey = "widget_snapshot"
    private let primarySnapshotKey = "primary_widget_snapshot"
    private let demoModeKey = "review_demo_mode"
    private let demoSignedInKey = "review_demo_signed_in"

    private let keychainService = "com.codex.TaskCanvas.oauth"
    private let tokenAccount = "oauth_tokens"

    init() {
        sharedDefaults = UserDefaults(suiteName: Self.appGroupID)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func saveSnapshot(_ snapshot: WidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        sharedDefaults?.set(data, forKey: snapshotKey)
        standardDefaults.set(data, forKey: snapshotKey)
    }

    func loadSnapshot() -> WidgetSnapshot {
        guard
            let data = sharedDefaults?.data(forKey: snapshotKey) ?? standardDefaults.data(forKey: snapshotKey),
            let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }

    func savePrimarySnapshot(_ snapshot: WidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        sharedDefaults?.set(data, forKey: primarySnapshotKey)
        standardDefaults.set(data, forKey: primarySnapshotKey)
    }

    func loadPrimarySnapshot() -> WidgetSnapshot {
        guard
            let data = sharedDefaults?.data(forKey: primarySnapshotKey) ?? standardDefaults.data(forKey: primarySnapshotKey),
            let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }

    /// Google Tasks由来のローカルキャッシュを、サインアウト時に消去する。
    func clearTaskSnapshots() {
        sharedDefaults?.removeObject(forKey: snapshotKey)
        sharedDefaults?.removeObject(forKey: primarySnapshotKey)
        standardDefaults.removeObject(forKey: snapshotKey)
        standardDefaults.removeObject(forKey: primarySnapshotKey)
    }

    func loadOAuthClientID() -> String {
        AppConfiguration.googleOAuthClientID
    }

    func loadOAuthClientSecret() -> String {
        AppConfiguration.googleOAuthClientSecret
    }

    func saveDemoModeEnabled(_ enabled: Bool) {
        sharedDefaults?.set(enabled, forKey: demoModeKey)
        standardDefaults.set(enabled, forKey: demoModeKey)
    }

    func loadDemoModeEnabled() -> Bool {
        let shared = sharedDefaults?.object(forKey: demoModeKey) as? Bool
        let standard = standardDefaults.object(forKey: demoModeKey) as? Bool
        return shared ?? standard ?? false
    }

    func saveDemoSignedIn(_ signedIn: Bool) {
        sharedDefaults?.set(signedIn, forKey: demoSignedInKey)
        standardDefaults.set(signedIn, forKey: demoSignedInKey)
    }

    func loadDemoSignedIn() -> Bool {
        let shared = sharedDefaults?.object(forKey: demoSignedInKey) as? Bool
        let standard = standardDefaults.object(forKey: demoSignedInKey) as? Bool
        return shared ?? standard ?? false
    }

    private let widgetListIDKey = "widget_list_id"

    func saveWidgetListID(_ listID: String?) {
        if let listID {
            sharedDefaults?.set(listID, forKey: widgetListIDKey)
            standardDefaults.set(listID, forKey: widgetListIDKey)
        } else {
            sharedDefaults?.removeObject(forKey: widgetListIDKey)
            standardDefaults.removeObject(forKey: widgetListIDKey)
        }
    }

    func loadWidgetListID() -> String? {
        sharedDefaults?.string(forKey: widgetListIDKey) ?? standardDefaults.string(forKey: widgetListIDKey)
    }

    private let fontSizeLevelKey = "font_size_level"

    func saveFontSizeLevel(_ level: Int) {
        sharedDefaults?.set(level, forKey: fontSizeLevelKey)
        standardDefaults.set(level, forKey: fontSizeLevelKey)
    }

    func loadFontSizeLevel() -> Int {
        let value = sharedDefaults?.integer(forKey: fontSizeLevelKey) ?? standardDefaults.integer(forKey: fontSizeLevelKey)
        // return 2 (100%) as default if not set
        return value == 0 ? 2 : value
    }

    func saveShowModeDescription(_ show: Bool) {
        sharedDefaults?.set(show, forKey: "show_mode_description")
        standardDefaults.set(show, forKey: "show_mode_description")
    }

    func loadShowModeDescription() -> Bool {
        // return true as default if not set
        let shared = sharedDefaults?.object(forKey: "show_mode_description") as? Bool
        let standard = standardDefaults.object(forKey: "show_mode_description") as? Bool
        return shared ?? standard ?? true
    }

    func saveShowListTitle(_ show: Bool) {
        sharedDefaults?.set(show, forKey: "show_list_title")
        standardDefaults.set(show, forKey: "show_list_title")
    }

    func loadShowListTitle() -> Bool {
        let shared = sharedDefaults?.object(forKey: "show_list_title") as? Bool
        let standard = standardDefaults.object(forKey: "show_list_title") as? Bool
        return shared ?? standard ?? true
    }

    func saveTokens(_ tokens: OAuthTokens?) {
        if let tokens {
            guard let data = try? encoder.encode(tokens) else { return }
            saveKeychainData(data, account: tokenAccount)
        } else {
            deleteKeychainData(account: tokenAccount)
        }
    }

    func loadTokens() -> OAuthTokens? {
        guard
            let data = loadKeychainData(account: tokenAccount),
            let tokens = try? decoder.decode(OAuthTokens.self, from: data)
        else {
            return nil
        }
        return tokens
    }

    private func saveKeychainData(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private func loadKeychainData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteKeychainData(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
