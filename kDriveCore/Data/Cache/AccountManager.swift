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
import InfomaniakDI
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

public extension InfomaniakLogin {
    static func apiToken(username: String, applicationPassword: String) async throws -> ApiToken {
        try await withCheckedThrowingContinuation { continuation in
            @InjectService var tokenable: InfomaniakTokenable
            tokenable.getApiToken(username: username, applicationPassword: applicationPassword) { token, error in
                if let token = token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
    }

    static func apiToken(using code: String, codeVerifier: String) async throws -> ApiToken {
        try await withCheckedThrowingContinuation { continuation in
            @InjectService var tokenable: InfomaniakTokenable
            tokenable.getApiTokenUsing(code: code, codeVerifier: codeVerifier) { token, error in
                if let token = token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
    }
}

@globalActor actor AccountActor: GlobalActor {
    static let shared = AccountActor()

    public static func run<T>(resultType: T.Type = T.self, body: @AccountActor @Sendable () throws -> T) async rethrows -> T {
        try await body()
    }
}

/// Abstract interface on AccountManager
public protocol AccountManageable {
    var currentAccount: Account! { get }
    var accounts: [Account] { get }
    var tokens: [ApiToken] { get }
    var currentUserId: Int { get }
    var currentDriveId: Int { get }
    var drives: [Drive] { get }
    var currentDriveFileManager: DriveFileManager? { get }
    var mqService: MQService { get }
    var refreshTokenLockedQueue: DispatchQueue { get }

    func forceReload()
    func reloadTokensAndAccounts()
    func getDriveFileManager(for drive: Drive) -> DriveFileManager?
    func getDriveFileManager(for driveId: Int, userId: Int) -> DriveFileManager?
    func getApiFetcher(for userId: Int, token: ApiToken) -> DriveApiFetcher
    func getDrive(for accountId: Int, driveId: Int, using realm: Realm?) -> Drive?
    func getTokenForUserId(_ id: Int) -> ApiToken?
    func didUpdateToken(newToken: ApiToken, oldToken: ApiToken)
    func didFailRefreshToken(_ token: ApiToken)
    func createAndSetCurrentAccount(code: String, codeVerifier: String) async throws -> Account
    func createAndSetCurrentAccount(token: ApiToken) async throws -> Account
    func updateUser(for account: Account, registerToken: Bool) async throws -> (Account, Drive?)
    func loadAccounts() -> [Account]
    func saveAccounts()
    func switchAccount(newAccount: Account)
    func setCurrentDriveForCurrentAccount(drive: Drive)
    func addAccount(account: Account)
    func removeAccount(toDeleteAccount: Account)
    func removeTokenAndAccount(token: ApiToken)
    func account(for token: ApiToken) -> Account?
    func account(for userId: Int) -> Account?
    func updateToken(newToken: ApiToken, oldToken: ApiToken)
}

public class AccountManager: RefreshTokenDelegate, AccountManageable {
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploader
    @LazyInjectService var tokenable: InfomaniakTokenable
    @LazyInjectService var notificationHelper: NotificationsHelpable

    private static let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    private static let group = "com.infomaniak.drive"
    public static let appGroup = "group." + group
    public static let accessGroup: String = AccountManager.appIdentifierPrefix + AccountManager.group
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

    public init() {
        self.currentDriveId = UserDefaults.shared.currentDriveId
        self.currentUserId = UserDefaults.shared.currentDriveUserId
        setSentryUserId(userId: currentUserId)

        forceReload()
    }

    public func forceReload() {
        currentDriveId = UserDefaults.shared.currentDriveId
        currentUserId = UserDefaults.shared.currentDriveUserId

        reloadTokensAndAccounts()

        if let account = account(for: currentUserId) ?? accounts.first {
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

        // Also update current account reference to prevent mismatch
        if let account = accounts.first(where: { $0.userId == currentAccount?.userId }) {
            currentAccount = account
        }

        // remove accounts with no user
        for account in accounts where account.user == nil {
            removeAccount(toDeleteAccount: account)
        }

        for token in tokens {
            if let account = account(for: token.userId) {
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
        return account(for: id)?.token
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
        if let account = account(for: token) {
            account.token = nil
            if account.userId == currentUserId {
                delegate?.currentAccountNeedsAuthentication()
                notificationHelper.sendDisconnectedNotification()
            }
        }
    }

    public func createAndSetCurrentAccount(code: String, codeVerifier: String) async throws -> Account {
        let token = try await InfomaniakLogin.apiToken(using: code, codeVerifier: codeVerifier)
        return try await createAndSetCurrentAccount(token: token)
    }

    public func createAndSetCurrentAccount(token: ApiToken) async throws -> Account {
        let apiFetcher = DriveApiFetcher(token: token, delegate: self)
        let user = try await apiFetcher.userProfile()

        let driveResponse = try await apiFetcher.userDrives()
        guard !driveResponse.drives.main.isEmpty else {
            throw DriveError.noDrive
        }

        let newAccount = Account(apiToken: token)
        newAccount.user = user
        addAccount(account: newAccount)
        setCurrentAccount(account: newAccount)

        DriveInfosManager.instance.storeDriveResponse(user: user, driveResponse: driveResponse)
        guard let mainDrive = driveResponse.drives.main.first(where: { !$0.maintenance }) else {
            removeAccount(toDeleteAccount: newAccount)
            throw driveResponse.drives.main.first?.isInTechnicalMaintenance == true ? DriveError.maintenance : DriveError.blocked
        }

        setCurrentDriveForCurrentAccount(drive: mainDrive.freeze())
        saveAccounts()
        mqService.registerForNotifications(with: driveResponse.ipsToken)

        return newAccount
    }

    public func updateUser(for account: Account, registerToken: Bool) async throws -> (Account, Drive?) {
        guard account.isConnected else {
            throw DriveError.unknownToken
        }

        let apiFetcher = await AccountActor.run {
            getApiFetcher(for: account.userId, token: account.token)
        }
        let user = try await apiFetcher.userProfile()
        account.user = user

        let driveResponse = try await apiFetcher.userDrives()
        guard !driveResponse.drives.main.isEmpty else {
            removeAccount(toDeleteAccount: account)
            throw DriveError.noDrive
        }

        let driveRemovedList = DriveInfosManager.instance.storeDriveResponse(user: user, driveResponse: driveResponse)
        clearDriveFileManagers()
        var switchedDrive: Drive?
        for driveRemoved in driveRemovedList {
            if photoLibraryUploader.isSyncEnabled && photoLibraryUploader.settings?.userId == user.id && photoLibraryUploader.settings?.driveId == driveRemoved.id {
                photoLibraryUploader.disableSync()
            }
            if currentDriveFileManager?.drive.id == driveRemoved.id {
                switchedDrive = drives.first
                setCurrentDriveForCurrentAccount(drive: switchedDrive!)
            }
            DriveFileManager.deleteUserDriveFiles(userId: user.id, driveId: driveRemoved.id)
        }

        saveAccounts()
        if registerToken {
            mqService.registerForNotifications(with: driveResponse.ipsToken)
        }

        return (account, switchedDrive)
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
        setCurrentAccount(account: newAccount)
        setCurrentDriveForCurrentAccount(drive: drives.first!)
        saveAccounts()
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
        if photoLibraryUploader.isSyncEnabled && photoLibraryUploader.settings?.userId == toDeleteAccount.userId {
            photoLibraryUploader.disableSync()
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
        if let account = account(for: token) {
            removeAccount(toDeleteAccount: account)
        }
        tokenable.deleteApiToken(token: token) { error in
            DDLogError("Failed to delete api token: \(error.localizedDescription)")
        }
    }

    public func account(for token: ApiToken) -> Account? {
        return accounts.first { $0.token?.userId == token.userId }
    }

    public func account(for userId: Int) -> Account? {
        return accounts.first { $0.userId == userId }
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
