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

public protocol UpdateAccountDelegate: AnyObject {
    func didUpdateCurrentAccountInformations(_ currentAccount: Account)
}

public protocol AccountManagerDelegate: AnyObject {
    func currentAccountNeedsAuthentication()
}

public extension InfomaniakLogin {
    static func apiToken(using code: String, codeVerifier: String) async throws -> ApiToken {
        try await withCheckedThrowingContinuation { continuation in
            @InjectService var tokenable: InfomaniakTokenable
            tokenable.getApiTokenUsing(code: code, codeVerifier: codeVerifier) { token, error in
                if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
    }
}

/// Abstract interface on AccountManager
public protocol AccountManageable: AnyObject {
    var currentAccount: Account? { get }
    var accounts: SendableArray<Account> { get }
    var currentUserId: Int { get }
    var currentDriveId: Int { get }
    var drives: [Drive] { get }
    var currentDriveFileManager: DriveFileManager? { get }
    var mqService: MQService { get }
    var refreshTokenLockedQueue: DispatchQueue { get }
    var delegate: AccountManagerDelegate? { get set }

    func forceReload()
    func reloadTokensAndAccounts()
    func getDriveFileManager(for drive: Drive) -> DriveFileManager?
    func getDriveFileManager(for driveId: Int, userId: Int) -> DriveFileManager?
    func getFirstAvailableDriveFileManager(for userId: Int) throws -> DriveFileManager
    func getApiFetcher(for userId: Int, token: ApiToken) -> DriveApiFetcher
    func getTokenForUserId(_ id: Int) -> ApiToken?
    func didUpdateToken(newToken: ApiToken, oldToken: ApiToken)
    func didFailRefreshToken(_ token: ApiToken)
    func createAndSetCurrentAccount(code: String, codeVerifier: String) async throws -> Account
    func createAndSetCurrentAccount(token: ApiToken) async throws -> Account
    func updateUser(for account: Account, registerToken: Bool) async throws -> Account
    func loadAccounts() -> [Account]
    func saveAccounts()
    func switchAccount(newAccount: Account)
    func setCurrentDriveForCurrentAccount(drive: Drive)
    func addAccount(account: Account, token: ApiToken)
    func removeAccount(toDeleteAccount: Account)
    func removeTokenAndAccount(account: Account)
    func account(for token: ApiToken) -> Account?
    func account(for userId: Int) -> Account?
}

public class AccountManager: RefreshTokenDelegate, AccountManageable {
    @LazyInjectService var driveInfosManager: DriveInfosManager
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploader
    @LazyInjectService var tokenStore: TokenStore
    @LazyInjectService var tokenable: InfomaniakTokenable
    @LazyInjectService var notificationHelper: NotificationsHelpable
    @LazyInjectService var networkLogin: InfomaniakNetworkLoginable

    private static let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    private static let group = "com.infomaniak.drive"
    public static let appGroup = "group." + group
    public static let accessGroup: String = AccountManager.appIdentifierPrefix + AccountManager.group

    public var currentAccount: Account?
    public let refreshTokenLockedQueue = DispatchQueue(label: "com.infomaniak.drive.refreshtoken")
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
        return Array(driveInfosManager.getDrives(for: currentUserId))
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

    public let accounts = SendableArray<Account>()
    private let driveFileManagers = SendableDictionary<String, DriveFileManager>()
    private let apiFetchers = SendableDictionary<Int, DriveApiFetcher>()
    public let mqService = MQService()

    public init() {
        currentDriveId = UserDefaults.shared.currentDriveId
        currentUserId = UserDefaults.shared.currentDriveUserId
        setSentryUserId(userId: currentUserId)

        forceReload()
    }

    public func forceReload() {
        currentDriveId = UserDefaults.shared.currentDriveId
        currentUserId = UserDefaults.shared.currentDriveUserId

        reloadTokensAndAccounts()

        if let account = account(for: currentUserId) ?? accounts.first {
            setCurrentAccount(account: account)

            if let currentDrive = driveInfosManager.getDrive(id: currentDriveId, userId: currentUserId) ?? drives.first {
                setCurrentDriveForCurrentAccount(drive: currentDrive)
            }
        }
    }

    public func reloadTokensAndAccounts() {
        accounts.removeAll()
        let newAccounts = loadAccounts()
        accounts.append(contentsOf: newAccounts)

        // Also update current account reference to prevent mismatch
        if let account = accounts.first(where: { $0.userId == currentAccount?.userId }) {
            currentAccount = account
        }

        // remove accounts with no user
        for account in accounts where account.user == nil {
            removeAccount(toDeleteAccount: account)
        }
    }

    public func getDriveFileManager(for drive: Drive) -> DriveFileManager? {
        return getDriveFileManager(for: drive.id, userId: drive.userId)
    }

    public func getDriveFileManager(for driveId: Int, userId: Int) -> DriveFileManager? {
        let objectId = DriveInfosManager.getObjectId(driveId: driveId, userId: userId)

        if let mailboxManager = driveFileManagers[objectId] {
            return mailboxManager
        } else if account(for: userId) != nil,
                  let token = tokenStore.tokenFor(userId: userId),
                  let drive = driveInfosManager.getDrive(id: driveId, userId: userId) {
            let apiFetcher = getApiFetcher(for: userId, token: token)
            driveFileManagers[objectId] = DriveFileManager(
                drive: drive,
                apiFetcher: apiFetcher,
                context: drive.sharedWithMe ? .sharedWithMe : .drive
            )
            return driveFileManagers[objectId]
        } else {
            return nil
        }
    }

    public func getFirstAvailableDriveFileManager(for userId: Int) throws -> DriveFileManager {
        let userDrives = driveInfosManager.getDrives(for: userId)

        guard !userDrives.isEmpty else {
            throw DriveError.NoDriveError.noDrive
        }

        guard let firstAvailableDrive = userDrives.first(where: { !$0.inMaintenance }) else {
            if userDrives[0].isInTechnicalMaintenance {
                throw DriveError.NoDriveError.maintenance(drive: userDrives[0])
            } else {
                throw DriveError.NoDriveError.blocked(drive: userDrives[0])
            }
        }

        guard let driveFileManager = getDriveFileManager(for: firstAvailableDrive) else {
            // We should always have a driveFileManager here
            throw DriveError.NoDriveError.noDriveFileManager
        }

        return driveFileManager
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

    public func getTokenForUserId(_ id: Int) -> ApiToken? {
        return tokenStore.tokenFor(userId: id)
    }

    public func didUpdateToken(newToken: ApiToken, oldToken: ApiToken) {
        SentryDebug.logTokenMigration(newToken: newToken, oldToken: oldToken)
        tokenStore.addToken(newToken: newToken)
    }

    public func didFailRefreshToken(_ token: ApiToken) {
        let context = ["User id": token.userId,
                       "Expiration date": token.expirationDate?.timeIntervalSince1970 ?? "Infinite"] as [String: Any]
        SentryDebug.capture(message: "Failed refreshing token", context: context, contextKey: "Token Infos")

        tokenStore.removeTokenFor(userId: token.userId)
        if let account = account(for: token),
           account.userId == currentUserId {
            delegate?.currentAccountNeedsAuthentication()
            notificationHelper.sendDisconnectedNotification()
        }
    }

    public func createAndSetCurrentAccount(code: String, codeVerifier: String) async throws -> Account {
        let token = try await InfomaniakLogin.apiToken(using: code, codeVerifier: codeVerifier)
        return try await createAndSetCurrentAccount(token: token)
    }

    public func createAndSetCurrentAccount(token: ApiToken) async throws -> Account {
        let apiFetcher = DriveApiFetcher(token: token, delegate: self)
        let user = try await apiFetcher.userProfile(ignoreDefaultAvatar: true)

        let driveResponse = try await apiFetcher.userDrives()
        guard !driveResponse.drives.filter(\.isDriveUser).isEmpty else {
            networkLogin.deleteApiToken(token: token) { error in
                DDLogError("Failed to delete api token: \(error.localizedDescription)")
            }
            throw DriveError.noDrive
        }

        let newAccount = Account(apiToken: token)
        newAccount.user = user
        addAccount(account: newAccount, token: token)
        setCurrentAccount(account: newAccount)

        guard let mainDrive = driveResponse.drives.first(where: { $0.isDriveUser && !$0.inMaintenance }) else {
            removeAccount(toDeleteAccount: newAccount)
            throw driveResponse.drives.first?.isInTechnicalMaintenance == true ?
                DriveError.productMaintenance : DriveError.blocked
        }
        driveInfosManager.storeDriveResponse(user: user, driveResponse: driveResponse)

        setCurrentDriveForCurrentAccount(drive: mainDrive.freeze())
        let driveFileManager = getDriveFileManager(for: mainDrive)
        try await driveFileManager?.initRoot()

        saveAccounts()
        mqService.registerForNotifications(with: driveResponse.ips)

        return newAccount
    }

    public func updateUser(for account: Account, registerToken: Bool) async throws -> Account {
        guard let token = tokenStore.tokenFor(userId: account.userId) else {
            throw DriveError.unknownToken
        }

        let apiFetcher = getApiFetcher(for: account.userId, token: token)
        let user = try await apiFetcher.userProfile(ignoreDefaultAvatar: true)
        account.user = user

        let driveResponse = try await apiFetcher.userDrives()
        guard !driveResponse.drives.isEmpty,
              let firstDrive = driveResponse.drives.first(where: { $0.isDriveUser }) else {
            removeAccount(toDeleteAccount: account)
            throw DriveError.NoDriveError.noDrive
        }

        let driveRemovedList = driveInfosManager.storeDriveResponse(user: user, driveResponse: driveResponse)
        clearDriveFileManagers()

        for driveRemoved in driveRemovedList {
            let frozenSettings = photoLibraryUploader.frozenSettings
            if photoLibraryUploader.isSyncEnabled,
               frozenSettings?.userId == user.id,
               frozenSettings?.driveId == driveRemoved.id {
                photoLibraryUploader.disableSync()
            }
            if currentDriveFileManager?.drive.id == driveRemoved.id {
                setCurrentDriveForCurrentAccount(drive: firstDrive)
            }
            DriveFileManager.deleteUserDriveFiles(userId: user.id, driveId: driveRemoved.id)
        }

        try await currentDriveFileManager?.initRoot()

        saveAccounts()
        if registerToken {
            mqService.registerForNotifications(with: driveResponse.ips)
        }

        return account
    }

    public func loadAccounts() -> [Account] {
        var accounts = [Account]()
        if let groupDirectoryURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AccountManager.appGroup)?
            .appendingPathComponent("preferences", isDirectory: true) {
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
        if let groupDirectoryURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AccountManager.appGroup)?
            .appendingPathComponent("preferences/", isDirectory: true) {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(accounts.values) {
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
        UserDefaults.shared.lastSelectedTab = nil
        if let drive = drives.first {
            setCurrentDriveForCurrentAccount(drive: drive)
        }
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

    public func addAccount(account: Account, token: ApiToken) {
        UserDefaults.shared.lastSelectedTab = nil

        if accounts.contains(account) {
            removeAccount(toDeleteAccount: account)
        }
        accounts.append(account)
        tokenStore.addToken(newToken: token)
        saveAccounts()
    }

    public func removeAccount(toDeleteAccount: Account) {
        UserDefaults.shared.lastSelectedTab = nil

        if currentAccount == toDeleteAccount {
            currentAccount = nil
            currentDriveId = 0
            currentUserId = 0
        }
        if photoLibraryUploader.isSyncEnabled && photoLibraryUploader.frozenSettings?.userId == toDeleteAccount.userId {
            photoLibraryUploader.disableSync()
        }
        driveInfosManager.deleteFileProviderDomains(for: toDeleteAccount.userId)
        DriveFileManager.deleteUserDriveFiles(userId: toDeleteAccount.userId)
        driveInfosManager.removeDrivesFor(userId: toDeleteAccount.userId)
        driveFileManagers.removeAll()
        apiFetchers.removeAll()
        accounts.removeAll { account -> Bool in
            account == toDeleteAccount
        }
    }

    public func removeTokenAndAccount(account: Account) {
        let removedToken = tokenStore.removeTokenFor(userId: account.userId) ?? account.token
        removeAccount(toDeleteAccount: account)

        guard let removedToken else { return }

        tokenable.deleteApiToken(token: removedToken) { error in
            DDLogError("Failed to delete api token: \(error.localizedDescription)")
        }
    }

    public func account(for token: ApiToken) -> Account? {
        return accounts.first { $0.token?.userId == token.userId }
    }

    public func account(for userId: Int) -> Account? {
        return accounts.first { $0.userId == userId }
    }
}
