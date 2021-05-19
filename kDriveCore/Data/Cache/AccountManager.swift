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
import InfomaniakLogin
import InfomaniakCore
import CocoaLumberjackSwift
import Sentry

public protocol SwitchAccountDelegate {
    func didUpdateCurrentAccountInformations(_ currentAccount: Account)
    func didSwitchCurrentAccount(_ newAccount: Account)
}

public protocol AccountManagerDelegate: AnyObject {
    func currentAccountNeedsAuthentication()
}

public class AccountManager: RefreshTokenDelegate {

    private static let group = "com.infomaniak.drive"
    public static let appGroup = "group." + group
    private let accessGroup: String
    public static var instance = AccountManager()
    private let tag = "ch.infomaniak.token".data(using: .utf8)!
    public var currentAccount: Account!
    public var accounts = [Account]()
    public var tokens = [ApiToken]()
    public var refreshTokenLock = DispatchGroup()
    public weak var delegate: AccountManagerDelegate?
    public var currentUserId: Int {
        didSet {
            UserDefaults.shared.currentDriveUserId = currentUserId
        }
    }
    public var currentDriveId: Int {
        didSet {
            UserDefaults.shared.currentDriveId = currentDriveId
        }
    }
    public var drives: [Drive] {
        return DriveInfosManager.instance.getDrives(for: currentUserId)
    }
    public var currentDriveFileManager: DriveFileManager? {
        if let currentDriveFileManager = getDriveFileManager(for: currentDriveId, userId: currentUserId) {
            return currentDriveFileManager
        } else if let newCurrentDrive = drives.first {
            setCurrentDriveForCurrentAccount(drive: newCurrentDrive)
            return getDriveFileManager(for: newCurrentDrive)
        } else {
            return nil
        }
    }
    private var driveFileManagers = [String: DriveFileManager]()

    private init() {
        let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
        accessGroup = appIdentifierPrefix + AccountManager.group

        self.currentDriveId = UserDefaults.shared.currentDriveId
        self.currentUserId = UserDefaults.shared.currentDriveUserId

        forceReload()
    }

    public func forceReload() {
        self.currentDriveId = UserDefaults.shared.currentDriveId
        self.currentUserId = UserDefaults.shared.currentDriveUserId
        self.tokens = loadTokens()
        self.accounts = loadAccounts()

        //remove accounts with no user
        for account in accounts {
            if account.user == nil {
                removeAccount(toDeleteAccount: account)
            }
        }

        for token in tokens {
            if let account = self.accounts.first(where: { $0.userId == token.userId }) {
                account.token = token
            } else {
                //Remove token with no account
                removeTokenAndAccount(token: token)
            }
        }

        if let account = accounts.first(where: { $0.userId == currentUserId }) ?? accounts.first {
            setCurrentAccount(account: account)

            if let currentDrive = DriveInfosManager.instance.getDrive(id: currentDriveId, userId: currentUserId) ?? drives.first {
                setCurrentDriveForCurrentAccount(drive: currentDrive)
            }
        }
    }

    public func getDriveFileManager(for drive: Drive) -> DriveFileManager? {
        return getDriveFileManager(for: drive.id, userId: drive.userId)
    }

    public func getDriveFileManager(for driveId: Int, userId: Int) -> DriveFileManager? {
        let objectId = DriveInfosManager.getObjectId(driveId: driveId, userId: userId)

        if let driveFileManager = driveFileManagers[objectId] {
            return driveFileManager
        } else if let token = getTokenForUserId(userId),
            let drive = DriveInfosManager.instance.getDrive(id: driveId, userId: userId) {
            driveFileManagers[objectId] = DriveFileManager(drive: drive, apiToken: token, refreshTokenDelegate: self)
            return driveFileManagers[objectId]
        } else {
            return nil
        }
    }

    public func getDrive(for accountId: Int, driveId: Int) -> Drive? {
        return DriveInfosManager.instance.getDrive(id: driveId, userId: accountId)
    }

    public func getTokenForUserId(_ id: Int) -> ApiToken? {
        return accounts.first(where: { $0.userId == id })?.token
    }

    public func didUpdateToken(newToken: ApiToken, oldToken: ApiToken) {
        self.updateToken(newToken: newToken, oldToken: oldToken)
    }

    public func didFailRefreshToken(_ token: ApiToken) {
        tokens.removeAll { $0.accessToken == token.accessToken }
        self.deleteToken(token)
        if let account = getAccountForToken(token: token) {
            account.token = nil
            if account.userId == currentUserId {
                delegate?.currentAccountNeedsAuthentication()
                NotificationsHelper.sendDisconnectedNotification()
            }
        }
    }


    public func createAndSetCurrentAccount(code: String, codeVerifier: String, completion: @escaping (Account?, Error?) -> Void) {
        InfomaniakLogin.getApiTokenUsing(code: code, codeVerifier: codeVerifier) { (apiToken, error) in
            if let token = apiToken {
                self.createAndSetCurrentAccount(token: token, completion: completion)
            } else {
                completion(nil, error)
            }
        }
    }

    public func createAndSetCurrentAccount(token: ApiToken, completion: @escaping (Account?, Error?) -> Void) {
        let newAccount = Account(apiToken: token)
        self.addAccount(account: newAccount)
        self.setCurrentAccount(account: newAccount)
        let apiFetcher = ApiFetcher(token: token, delegate: self)
        apiFetcher.getUserForAccount { (response, error) in
            if let user = response?.data {
                newAccount.user = user

                apiFetcher.getUserDrives { (response, error) in
                    if let driveResponse = response?.data,
                        driveResponse.drives.main.count > 0 {
                        DriveInfosManager.instance.storeDriveResponse(user: user, driveResponse: driveResponse)

                        guard let mainDrive = driveResponse.drives.main.first(where: { !$0.maintenance }) else {
                            self.removeAccount(toDeleteAccount: newAccount)
                            completion(nil, DriveError.maintenance)
                            return
                        }
                        self.setCurrentDriveForCurrentAccount(drive: mainDrive.freeze())
                        self.saveAccounts()
                        completion(newAccount, nil)
                    } else {
                        self.removeAccount(toDeleteAccount: newAccount)
                        completion(nil, error)
                    }
                }
            } else {
                completion(nil, error)
            }
        }
    }

    public func updateUserForAccount(_ account: Account, completion: @escaping (Account?, Drive?, Error?) -> Void) {
        guard account.isConnected else { return }
        let apiFetcher = ApiFetcher(token: account.token, delegate: self)
        apiFetcher.getUserForAccount { (response, error) in
            if let user = response?.data {
                account.user = user
                apiFetcher.getUserDrives { (response, error) in
                    if let driveResponse = response?.data,
                        driveResponse.drives.main.count > 0 {
                        let driveRemovedList = DriveInfosManager.instance.storeDriveResponse(user: user, driveResponse: driveResponse)
                        var switchedDrive: Drive?
                        for driveRemoved in driveRemovedList {
                            if PhotoLibraryUploader.instance.isSyncEnabled && PhotoLibraryUploader.instance.settings.userId == user.id && PhotoLibraryUploader.instance.settings.driveId == driveRemoved.id {
                                PhotoLibraryUploader.instance.disableSync()
                            }
                            if self.currentDriveFileManager?.drive.id == driveRemoved.id {
                                switchedDrive = self.drives.first
                                self.setCurrentDriveForCurrentAccount(drive: switchedDrive!)
                            }
                            DriveFileManager.deleteUserDriveFiles(userId: user.id, driveId: driveRemoved.id)
                        }
                        self.saveAccounts()
                        completion(account, switchedDrive, nil)
                    } else {
                        if let error = error as? DriveError, error == .noDrive {
                            self.removeAccount(toDeleteAccount: account)
                        }
                        completion(nil, nil, error)
                    }
                }
            } else {
                completion(nil, nil, error)
            }
        }
    }

    public func loadAccounts() -> [Account] {
        var accounts = [Account]()
        if let groupDirectoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AccountManager.appGroup)?.appendingPathComponent("preferences", isDirectory: true) {
            let decoder = JSONDecoder()
            do {
                let data = try Data(contentsOf: groupDirectoryURL.appendingPathComponent("accounts.json"))
                let savedAccounts = try decoder.decode([Account].self, from: data)
                accounts = savedAccounts

            } catch {
                DDLogError("Error loading accounts \(error)")
            }
        }
        return accounts
    }

    public func saveAccounts() {
        if let groupDirectoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AccountManager.appGroup)?.appendingPathComponent("preferences/", isDirectory: true) {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(accounts) {
                do {
                    try FileManager.default.createDirectory(atPath: groupDirectoryURL.path, withIntermediateDirectories: true)
                    try data.write(to: groupDirectoryURL.appendingPathComponent("accounts.json"))
                } catch {
                    DDLogError("Error saving accounts \(error)")
                }
            }
        }
    }

    public func switchAccount(newAccount: Account) {
        AccountManager.instance.setCurrentAccount(account: newAccount)
        AccountManager.instance.setCurrentDriveForCurrentAccount(drive: drives.first!)
        AccountManager.instance.saveAccounts()
    }

    private func setCurrentAccount(account: Account) {
        currentAccount = account
        currentUserId = account.userId
        // Set Sentry user
        let user = Sentry.User(userId: "\(account.userId)")
        user.ipAddress = "{{auto}}"
        SentrySDK.setUser(user)
    }

    public func setCurrentDriveForCurrentAccount(drive: Drive) {
        currentDriveId = drive.id
        _ = getDriveFileManager(for: drive)
    }

    public func addAccount(account: Account) {
        if accounts.contains(account) {
            self.removeAccount(toDeleteAccount: account)
        }
        accounts.append(account)
        self.storeToken(account.token)
        self.saveAccounts()
    }

    public func removeAccount(toDeleteAccount: Account) {
        if currentAccount == toDeleteAccount {
            currentAccount = nil
            currentDriveId = 0
        }
        if PhotoLibraryUploader.instance.isSyncEnabled && PhotoLibraryUploader.instance.settings.userId == toDeleteAccount.userId {
            PhotoLibraryUploader.instance.disableSync()
        }
        DriveInfosManager.instance.deleteFileProviderDomains(for: toDeleteAccount.userId)
        DriveFileManager.deleteUserDriveFiles(userId: toDeleteAccount.userId)
        accounts.removeAll { (account) -> Bool in
            account == toDeleteAccount
        }
    }

    public func removeTokenAndAccount(token: ApiToken) {
        tokens.removeAll { $0.accessToken == token.accessToken }
        self.deleteToken(token)
        if let account = getAccountForToken(token: token) {
            self.removeAccount(toDeleteAccount: account)
        }
    }

    public func getAccountForToken(token: ApiToken) -> Account? {
        return accounts.first { (account) -> Bool in
            account.token?.accessToken == token.accessToken
        }
    }

    public func updateToken(newToken: ApiToken, oldToken: ApiToken) {
        self.deleteToken(oldToken)
        self.storeToken(newToken)
        if oldToken.accessToken == currentAccount.token?.accessToken {
            currentAccount.token = newToken
        }
        tokens.removeAll { $0.accessToken == oldToken.accessToken }
        tokens.append(newToken)

        //Update token for the other drive file manager
        for driveFileManager in driveFileManagers.values where driveFileManager.drive != currentDriveFileManager?.drive {
            if driveFileManager.apiFetcher.currentToken?.userId == newToken.userId {
                driveFileManager.apiFetcher.currentToken = newToken
            }
        }
    }

    public func deleteAllTokens() {
        let queryDelete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tag
        ]
        let resultCode = SecItemDelete(queryDelete as CFDictionary)
        DDLogInfo("Successfully deleted all tokens ? \(resultCode == noErr)")
    }

    func deleteToken(_ token: ApiToken) {
        let queryDelete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tag,
            kSecAttrAccount as String: "\(token.userId)"
        ]
        let resultCode = SecItemDelete(queryDelete as CFDictionary)
        DDLogInfo("Successfully deleted token ? \(resultCode == noErr)")
    }

    func storeToken(_ token: ApiToken) {
        self.deleteToken(token)
        let tokenData = try! JSONEncoder().encode(token)
        let queryAdd: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccessGroup as String: accessGroup,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrService as String: tag,
            kSecAttrAccount as String: "\(token.userId)",
            kSecValueData as String: tokenData]
        let resultCode = SecItemAdd(queryAdd as CFDictionary, nil)
        DDLogInfo("Successfully saved token ? \(resultCode == noErr)")
    }

    func loadTokens() -> [ApiToken] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tag,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecReturnRef as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?

        let resultCode = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        DDLogInfo("Successfully loaded tokens ? \(resultCode == noErr)")

        var values = [ApiToken]()
        if resultCode == noErr {
            let jsonDecoder = JSONDecoder()
            if let array = result as? Array<Dictionary<String, Any>> {
                for item in array {
                    if let value = item[kSecValueData as String] as? Data {
                        if let token = try? jsonDecoder.decode(ApiToken.self, from: value) {
                            values.append(token)
                        }
                    }
                }
            }
        }

        return values
    }

}
