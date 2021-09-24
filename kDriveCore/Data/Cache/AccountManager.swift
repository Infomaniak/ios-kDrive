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

import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import InfomaniakLogin
import RealmSwift
import Sentry

public protocol SwitchAccountDelegate: AnyObject {
    func didUpdateCurrentAccountInformations(_ currentAccount: Account)
    func didSwitchCurrentAccount(_ newAccount: Account)
}

public protocol AccountManagerDelegate: AnyObject {
    func currentAccountNeedsAuthentication()
}

public class AccountManager: RefreshTokenDelegate {
    private static let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    private static let group = "com.infomaniak.drive"
    public static let appGroup = "group." + group
    public static let accessGroup: String = AccountManager.appIdentifierPrefix + AccountManager.group
    public static var instance = AccountManager()
    private let tag = "ch.infomaniak.token".data(using: .utf8)!
    public var currentAccount: Account!
    public var accounts = [Account]()
    public var tokens = [ApiToken]()
    public let refreshTokenLockedQueue = DispatchQueue(label: "com.infomaniak.drive.refreshtoken")
    private let keychainQueue = DispatchQueue(label: "com.infomaniak.drive.keychain")
    public weak var delegate: AccountManagerDelegate?
    public var currentUserId: Int {
        didSet {
            UserDefaults.shared.currentDriveUserId = currentUserId
            setSentryUserId(userId: currentUserId)
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
    private var apiFetchers = [Int: DriveApiFetcher]()
    public let mqService = MQService()

    private init() {
        self.currentDriveId = UserDefaults.shared.currentDriveId
        self.currentUserId = UserDefaults.shared.currentDriveUserId
        setSentryUserId(userId: currentUserId)

        forceReload()
    }

    public func forceReload() {
        currentDriveId = UserDefaults.shared.currentDriveId
        currentUserId = UserDefaults.shared.currentDriveUserId

        reloadTokensAndAccounts()

        if let account = accounts.first(where: { $0.userId == currentUserId }) ?? accounts.first {
            setCurrentAccount(account: account)

            if let currentDrive = DriveInfosManager.instance.getDrive(id: currentDriveId, userId: currentUserId) ?? drives.first {
                setCurrentDriveForCurrentAccount(drive: currentDrive)
            }
        }
    }

    public func reloadTokensAndAccounts() {
        accounts = loadAccounts()
        if !accounts.isEmpty {
            tokens = KeychainHelper.loadTokens()
        }

        // remove accounts with no user
        for account in accounts where account.user == nil {
            removeAccount(toDeleteAccount: account)
        }

        for token in tokens {
            if let account = accounts.first(where: { $0.userId == token.userId }) {
                account.token = token
            } else {
                // Remove token with no account
                removeTokenAndAccount(token: token)
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
            let apiFetcher = getApiFetcher(for: userId, token: token)
            driveFileManagers[objectId] = DriveFileManager(drive: drive, apiFetcher: apiFetcher)
            return driveFileManagers[objectId]
        } else {
            return nil
        }
    }

    private func clearDriveFileManagers() {
        driveFileManagers.removeAll()
    }

    public func getApiFetcher(for userId: Int, token: ApiToken) -> DriveApiFetcher {
        if let apiFetcher = apiFetchers[userId] {
            return apiFetcher
        } else {
            let apiFetcher = DriveApiFetcher(token: token, delegate: self)
            apiFetchers[userId] = apiFetcher
            return apiFetcher
        }
    }

    public func getDrive(for accountId: Int, driveId: Int, using realm: Realm? = nil) -> Drive? {
        return DriveInfosManager.instance.getDrive(id: driveId, userId: accountId, using: realm)
    }

    public func getTokenForUserId(_ id: Int) -> ApiToken? {
        return accounts.first { $0.userId == id }?.token
    }

    public func didUpdateToken(newToken: ApiToken, oldToken: ApiToken) {
        updateToken(newToken: newToken, oldToken: oldToken)
    }

    public func didFailRefreshToken(_ token: ApiToken) {
        SentrySDK.capture(message: "Failed refreshing token") { scope in
            scope.setContext(value: ["User id": token.userId, "Expiration date": token.expirationDate.timeIntervalSince1970], key: "Token Infos")
        }
        tokens.removeAll { $0.userId == token.userId }
        KeychainHelper.deleteToken(for: token.userId)
        if let account = getAccountForToken(token: token) {
            account.token = nil
            if account.userId == currentUserId {
                delegate?.currentAccountNeedsAuthentication()
                NotificationsHelper.sendDisconnectedNotification()
            }
        }
    }

    public func createAndSetCurrentAccount(code: String, codeVerifier: String, completion: @escaping (Account?, Error?) -> Void) {
        InfomaniakLogin.getApiTokenUsing(code: code, codeVerifier: codeVerifier) { apiToken, error in
            if let token = apiToken {
                self.createAndSetCurrentAccount(token: token, completion: completion)
            } else {
                completion(nil, error)
            }
        }
    }

    public func createAndSetCurrentAccount(token: ApiToken, completion: @escaping (Account?, Error?) -> Void) {
        let newAccount = Account(apiToken: token)
        addAccount(account: newAccount)
        setCurrentAccount(account: newAccount)
        let apiFetcher = ApiFetcher(token: token, delegate: self)
        apiFetcher.getUserForAccount { response, error in
            if let user = response?.data {
                newAccount.user = user

                apiFetcher.getUserDrives { response, error in
                    if let driveResponse = response?.data {
                        guard !driveResponse.drives.main.isEmpty else {
                            self.removeAccount(toDeleteAccount: newAccount)
                            completion(nil, DriveError.noDrive)
                            return
                        }

                        DriveInfosManager.instance.storeDriveResponse(user: user, driveResponse: driveResponse)

                        guard let mainDrive = driveResponse.drives.main.first(where: { !$0.maintenance }) else {
                            self.removeAccount(toDeleteAccount: newAccount)
                            completion(nil, DriveError.maintenance)
                            return
                        }
                        self.setCurrentDriveForCurrentAccount(drive: mainDrive.freeze())
                        self.saveAccounts()
                        self.mqService.registerForNotifications(with: driveResponse.ipsToken)
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

    public func updateUserForAccount(_ account: Account, registerToken: Bool, completion: @escaping (Account?, Drive?, Error?) -> Void) {
        guard account.isConnected else { return }

        let apiFetcher = getApiFetcher(for: account.userId, token: account.token)
        apiFetcher.getUserForAccount { response, error in
            if let user = response?.data {
                account.user = user
                apiFetcher.getUserDrives { response, error in
                    if let driveResponse = response?.data,
                       !driveResponse.drives.main.isEmpty {
                        let driveRemovedList = DriveInfosManager.instance.storeDriveResponse(user: user, driveResponse: driveResponse)
                        self.clearDriveFileManagers()
                        var switchedDrive: Drive?
                        for driveRemoved in driveRemovedList {
                            if PhotoLibraryUploader.instance.isSyncEnabled && PhotoLibraryUploader.instance.settings?.userId == user.id && PhotoLibraryUploader.instance.settings?.driveId == driveRemoved.id {
                                PhotoLibraryUploader.instance.disableSync()
                            }
                            if self.currentDriveFileManager?.drive.id == driveRemoved.id {
                                switchedDrive = self.drives.first
                                self.setCurrentDriveForCurrentAccount(drive: switchedDrive!)
                            }
                            DriveFileManager.deleteUserDriveFiles(userId: user.id, driveId: driveRemoved.id)
                        }
                        self.saveAccounts()
                        if registerToken {
                            self.mqService.registerForNotifications(with: driveResponse.ipsToken)
                        }
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
    }

    private func setSentryUserId(userId: Int) {
        guard userId != 0 else {
            return
        }
        let user = Sentry.User(userId: "\(userId)")
        user.ipAddress = "{{auto}}"
        SentrySDK.setUser(user)
    }

    public func setCurrentDriveForCurrentAccount(drive: Drive) {
        currentDriveId = drive.id
        _ = getDriveFileManager(for: drive)
    }

    public func addAccount(account: Account) {
        if accounts.contains(account) {
            removeAccount(toDeleteAccount: account)
        }
        accounts.append(account)
        KeychainHelper.storeToken(account.token)
        saveAccounts()
    }

    public func removeAccount(toDeleteAccount: Account) {
        if currentAccount == toDeleteAccount {
            currentAccount = nil
            currentDriveId = 0
        }
        if PhotoLibraryUploader.instance.isSyncEnabled && PhotoLibraryUploader.instance.settings?.userId == toDeleteAccount.userId {
            PhotoLibraryUploader.instance.disableSync()
        }
        DriveInfosManager.instance.deleteFileProviderDomains(for: toDeleteAccount.userId)
        DriveFileManager.deleteUserDriveFiles(userId: toDeleteAccount.userId)
        accounts.removeAll { account -> Bool in
            account == toDeleteAccount
        }
    }

    public func removeTokenAndAccount(token: ApiToken) {
        tokens.removeAll { $0.userId == token.userId }
        KeychainHelper.deleteToken(for: token.userId)
        if let account = getAccountForToken(token: token) {
            removeAccount(toDeleteAccount: account)
        }
    }

    public func getAccountForToken(token: ApiToken) -> Account? {
        return accounts.first { account -> Bool in
            account.token?.userId == token.userId
        }
    }

    public func updateToken(newToken: ApiToken, oldToken: ApiToken) {
        KeychainHelper.storeToken(newToken)
        for account in accounts where oldToken.userId == account.userId {
            account.token = newToken
        }
        tokens.removeAll { $0.userId == oldToken.userId }
        tokens.append(newToken)

        // Update token for the other drive file manager
        for driveFileManager in driveFileManagers.values where driveFileManager.drive != currentDriveFileManager?.drive && driveFileManager.apiFetcher.currentToken?.userId == newToken.userId {
            driveFileManager.apiFetcher.currentToken = newToken
        }
    }
}
