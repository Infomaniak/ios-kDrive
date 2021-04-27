/*
Infomaniak kDrive - iOS App
Copyright (C) 2021 Infomaniak Network SA

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import Foundation
import RealmSwift
import Sentry
import InfomaniakLogin
import InfomaniakCore

public class MigrationResult {

    public enum MigrationError: Error {
        case noAccount
        case authFailed
        case unknown
    }

    public let success: Bool
    public let error: MigrationError?
    public let photoSyncEnabled: Bool

    init(success: Bool, error: MigrationError?, photoSyncEnabled: Bool) {
        self.success = success
        self.error = error
        self.photoSyncEnabled = photoSyncEnabled
    }
}

public class MigrationHelper {

    private static let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    private static let group = "com.infomaniak.Crypto-Cloud"
    private static let accessGroup = appIdentifierPrefix + group
    private static let nextcloudGroup: String = "group." + group
    private static let nextcloudRealmUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("nextcloud.realm")
    private static let databaseSchemaVersion: UInt64 = 153

    public static func migrate(completion: @escaping (MigrationResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let savedAccounts = getKeychainAccounts()
            if savedAccounts.isEmpty {
                SentrySDK.capture(message: "[Migration] No keychain account")
                completion(MigrationResult(success: false, error: .noAccount, photoSyncEnabled: false))
                return
            }

            var successful = true
            let group = DispatchGroup()
            for (account, password) in savedAccounts {
                group.enter()
                InfomaniakLogin.getApiToken(username: account, applicationPassword: password) { (token, error) in
                    if let token = token {
                        AccountManager.instance.createAndSetCurrentAccount(token: token) { (account, error) in
                            if account == nil {
                                successful = false
                            }
                            group.leave()
                        }
                    } else {
                        successful = false
                        group.leave()
                    }
                }
            }
            group.wait()
            if !successful {
                SentrySDK.capture(message: "[Migration] Auth failed")
                completion(MigrationResult(success: false, error: .authFailed, photoSyncEnabled: false))
                return
            }

            let photoSyncEnabled = isPhotoSyncEnabled()
            UserDefaults.store(migrated: true)
            UserDefaults.store(migrationPhotoSyncEnabled: photoSyncEnabled)
            completion(MigrationResult(success: true, error: nil, photoSyncEnabled: photoSyncEnabled))
        }
    }

    private static func getKeychainAccounts() -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecReturnRef as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?

        let lastResultCode = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        var values = [String: String]()
        if lastResultCode == noErr {
            let array = result as? Array<Dictionary<String, Any>>

            for item in array! {
                if let key = item[kSecAttrAccount as String] as? String,
                    let value = item[kSecValueData as String] as? Data {
                    values[key] = String(data: value, encoding: .utf8)
                }
            }
        }

        var savedAccounts = [String: String]()
        for key in values.keys {
            //Nextcloud accounts are saved in keychain using this format: password + usernameemail + " " + driveUrl
            let passwordMatch = "password"
            if key.starts(with: passwordMatch) {
                var accountName = key
                accountName.removeFirst(passwordMatch.count)
                accountName = String(accountName.split(separator: " ")[0])
                savedAccounts[accountName] = values[key]
            }
        }
        return savedAccounts
    }

    private static func isPhotoSyncEnabled() -> Bool {
        do {
            let config = Realm.Configuration(
                fileURL: MigrationHelper.nextcloudRealmUrl,
                schemaVersion: MigrationHelper.databaseSchemaVersion)
            let realm = try Realm(configuration: config)
            let accounts = realm.objects(tableAccount.self)

            for account in accounts {
                if account.autoUpload {
                    return true
                }
            }

            return false
        } catch {
            SentrySDK.capture(message: "[Migration] Cannot read database")
            return false
        }
    }

    public static func canMigrate() -> Bool {
        return FileManager.default.fileExists(atPath: nextcloudRealmUrl!.path)
    }

    public static func cleanup() {
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            let documentBaseUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let groupBaseUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: nextcloudGroup)!

            if let groupFiles = try? fileManager.contentsOfDirectory(atPath: groupBaseUrl.path) {
                for filePath in groupFiles {
                    try? fileManager.removeItem(atPath: groupBaseUrl.appendingPathComponent(filePath).path)
                }
            }

            if let documentFiles = try? fileManager.contentsOfDirectory(atPath: documentBaseUrl.path) {
                for filePath in documentFiles {
                    try? fileManager.removeItem(atPath: documentBaseUrl.appendingPathComponent(filePath).path)
                }
            }

            var queryDelete: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccessGroup as String: accessGroup,
            ]
            _ = SecItemDelete(queryDelete as CFDictionary)

            queryDelete = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrAccessGroup as String: accessGroup,
            ]
            _ = SecItemDelete(queryDelete as CFDictionary)

        }
    }

}
