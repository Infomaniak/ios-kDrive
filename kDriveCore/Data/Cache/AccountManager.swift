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
import DeviceAssociation
import Foundation
import InfomaniakBugTracker
import InfomaniakCore
import InfomaniakDI
import InfomaniakLogin
import kDriveResources
import MyKSuite
import RealmSwift
import Sentry

public protocol UpdateAccountDelegate: AnyObject {
    @MainActor func didUpdateCurrentAccountInformations(_ currentAccount: Account)
}

public protocol AccountManagerDelegate: AnyObject {
    func currentAccountNeedsAuthentication()
}

public extension InfomaniakLogin {
    static func apiToken(using code: String, codeVerifier: String) async throws -> ApiToken {
        @InjectService var tokenable: InfomaniakNetworkLoginable
        return try await tokenable.apiTokenUsing(code: code, codeVerifier: codeVerifier)
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
    func getDriveFileManager(for driveId: Int, userId: Int) -> DriveFileManager?
    @MainActor func getMatchingDriveFileManagerOrSwitchAccount(deeplink: Any) async -> DriveFileManager?
    func getFirstAvailableDriveFileManager(for userId: Int) throws -> DriveFileManager
    func getFirstMatchingDriveFileManager(for userId: Int, driveId: Int) throws -> DriveFileManager?

    /// Create on the fly an "in memory" DriveFileManager for a specific share
    func getInMemoryDriveFileManager(for publicShareId: String, driveId: Int, rootFileId: Int) -> DriveFileManager?
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
    func switchToNextAvailableAccount()
    func setCurrentDriveForCurrentAccount(for driveId: Int, userId: Int)
    func addAccount(account: Account, token: ApiToken)
    func removeAccount(toDeleteAccount: Account)
    func removeTokenAndAccount(account: Account)
    func account(for token: ApiToken) -> Account?
    func account(for userId: Int) -> Account?
    func logoutCurrentAccountAndSwitchToNextIfPossible()
}

public class AccountManager: RefreshTokenDelegate, AccountManageable {
    @LazyInjectService var deviceManager: DeviceManagerable
    @LazyInjectService var driveInfosManager: DriveInfosManager
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploadable
    @LazyInjectService var photoLibrarySync: PhotoLibrarySyncable
    @LazyInjectService var tokenStore: TokenStore
    @LazyInjectService var bugTracker: BugTracker
    @LazyInjectService var notificationHelper: NotificationsHelpable
    @LazyInjectService var networkLogin: InfomaniakNetworkLoginable
    @LazyInjectService var appNavigable: AppNavigable
    @LazyInjectService var deeplinkService: DeeplinkServiceable
    @LazyInjectService var myKSuiteStore: MyKSuiteStore

    private static let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    private static let group = "com.infomaniak.drive"
    public static let appGroup = "group." + group
    public static let accessGroup: String = AccountManager.appIdentifierPrefix + AccountManager.group

    @SendableProperty public var currentAccount: Account?
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
            setCurrentDriveForCurrentAccount(for: newCurrentDrive.id, userId: newCurrentDrive.userId)
            return getDriveFileManager(for: newCurrentDrive.id, userId: newCurrentDrive.userId)
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
                setCurrentDriveForCurrentAccount(for: currentDrive.id, userId: currentDrive.userId)
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

    @discardableResult
    public func getDriveFileManager(for driveId: Int, userId: Int) -> DriveFileManager? {
        let objectId = DriveInfosManager.getObjectId(driveId: driveId, userId: userId)

        if let driveFileManager = driveFileManagers[objectId] {
            return driveFileManager
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

    @MainActor public func getMatchingDriveFileManagerOrSwitchAccount(deeplink: Any) async
        -> DriveFileManager? {
        var driveFileManager: DriveFileManager?
        var matchingAccount: Account?
        let driveId: Int

        switch deeplink {
        case let deeplink as PublicShareLink:
            driveId = deeplink.driveId
        case let deeplink as SharedWithMeLink:
            driveId = deeplink.driveId
        case let deeplink as TrashLink:
            driveId = deeplink.driveId
        case let deeplink as OfficeLink:
            driveId = deeplink.driveId
        default:
            return nil
        }

        for account in accounts {
            if let matchingDriveFileManager = try? getFirstMatchingDriveFileManager(
                for: account.userId,
                driveId: driveId
            ) {
                driveFileManager = matchingDriveFileManager
                matchingAccount = account
            }
        }

        if let matchingAccount, let currentAccount, matchingAccount != currentAccount {
            DDLogInfo("switching to account \(matchingAccount.userId) to accommodate sharedWithMeLink navigation")
            deeplinkService.setLastPublicShare(deeplink)
            switchAccount(newAccount: matchingAccount)
            appNavigable.prepareRootViewController(
                currentState: RootViewControllerState.getCurrentState(),
                restoration: false
            )
            return nil
        }

        if driveFileManager == nil, !accounts.isEmpty {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.wrongAccountConnected)
        }

        guard let driveFileManager else {
            return nil
        }

        if driveId != currentDriveId {
            DDLogInfo("switching to drive \(driveId) to accommodate sharedWithMeLink navigation")

            try? await driveFileManager.switchDriveAndReloadUI()
            deeplinkService.setLastPublicShare(deeplink)
            deeplinkService.processDeeplinksPostAuthentication()

            return nil
        }

        return driveFileManager
    }

    public func getInMemoryDriveFileManager(for publicShareId: String, driveId: Int, rootFileId: Int) -> DriveFileManager? {
        if let inMemoryDriveFileManager = driveFileManagers[publicShareId] {
            return inMemoryDriveFileManager
        }

        // FileViewModel K.O. without a valid drive in Realm, therefore add one
        let publicShareDrive = Drive()
        publicShareDrive.objectId = publicShareId

        do {
            try driveInfosManager.storePublicShareDrive(drive: publicShareDrive)
        } catch {
            DDLogError("Failed to store public share drive in base, \(error)")
            return nil
        }

        let frozenPublicShareDrive = publicShareDrive.freeze()
        let publicShareProxy = PublicShareProxy(driveId: driveId, fileId: rootFileId, shareLinkUid: publicShareId)
        let context = DriveFileManagerContext.publicShare(shareProxy: publicShareProxy)

        return DriveFileManager(drive: frozenPublicShareDrive, apiFetcher: DriveApiFetcher(), context: context)
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

        guard let driveFileManager = getDriveFileManager(for: firstAvailableDrive.id, userId: firstAvailableDrive.userId) else {
            // We should always have a driveFileManager here
            throw DriveError.NoDriveError.noDriveFileManager
        }

        return driveFileManager
    }

    public func getFirstMatchingDriveFileManager(for userId: Int, driveId: Int) throws -> DriveFileManager? {
        let userDrives = driveInfosManager.getDrives(for: userId)
        for drive in userDrives {
            if drive.id == driveId {
                guard let driveFileManager = getDriveFileManager(for: driveId, userId: userId) else {
                    throw DriveError.NoDriveError.noDriveFileManager
                }
                return driveFileManager
            }
        }
        return nil
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

        let tokenUserId = token.userId
        tokenStore.removeTokenFor(userId: token.userId)

        // Remove matching account
        guard let accountToDelete = accounts.first(where: { account in
            account.userId == tokenUserId
        }) else {
            SentryDebug.capture(message: "Failed matching failed token to account \(tokenUserId)",
                                context: context,
                                contextKey: "Token Infos")
            DDLogError("Failed matching failed token to account \(tokenUserId)")
            return
        }

        if accountToDelete == currentAccount {
            DDLogInfo("matched \(currentAccount) to \(accountToDelete), removing current account")
            notificationHelper.sendDisconnectedNotification()
            logoutCurrentAccountAndSwitchToNextIfPossible()
        } else {
            DDLogInfo("user with token error \(accountToDelete) do not match current account, doing nothing")
            removeAccount(toDeleteAccount: accountToDelete)
        }
    }

    public func createAndSetCurrentAccount(code: String, codeVerifier: String) async throws -> Account {
        let token = try await InfomaniakLogin.apiToken(using: code, codeVerifier: codeVerifier)
        return try await createAndSetCurrentAccount(token: token)
    }

    public func createAndSetCurrentAccount(token: ApiToken) async throws -> Account {
        let apiFetcher = DriveApiFetcher(token: token, delegate: self)
        let user = try await apiFetcher.userProfile(ignoreDefaultAvatar: true)

        attachDeviceToApiToken(token, apiFetcher: apiFetcher)

        let driveResponse = try await apiFetcher.userDrives()
        guard !driveResponse.drives.filter(\.isDriveUser).isEmpty else {
            try? await networkLogin.deleteApiToken(token: token)
            throw DriveError.noDrive
        }

        await updateMyKSuiteIfNeeded(for: driveResponse.drives, userId: user.id, apiFetcher: apiFetcher)

        let newAccount = Account(apiToken: token)
        newAccount.user = user
        addAccount(account: newAccount, token: token)
        setCurrentAccount(account: newAccount)

        guard let mainDrive = driveResponse.drives.first(where: { $0.isDriveUser && !$0.inMaintenance }) else {
            removeAccount(toDeleteAccount: newAccount)
            if let drive = driveResponse.drives.first, drive.isInTechnicalMaintenance {
                throw driveResponse.drives.count > 1 ? DriveError.productMaintenance : DriveError.NoDriveError
                    .maintenance(drive: drive)
            }
            throw DriveError.blocked
        }
        driveInfosManager.storeDriveResponse(user: user, driveResponse: driveResponse)

        let frozenDrive = mainDrive.freeze()
        setCurrentDriveForCurrentAccount(for: frozenDrive.id, userId: frozenDrive.userId)
        let driveFileManager = getDriveFileManager(for: mainDrive.id, userId: mainDrive.userId)
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

        attachDeviceToApiToken(token, apiFetcher: apiFetcher)

        let driveResponse = try await apiFetcher.userDrives()
        guard !driveResponse.drives.isEmpty,
              let firstDrive = driveResponse.drives.first(where: { $0.isDriveUser }) else {
            removeAccount(toDeleteAccount: account)
            throw DriveError.NoDriveError.noDrive
        }

        await updateMyKSuiteIfNeeded(for: driveResponse.drives, userId: account.userId, apiFetcher: apiFetcher)

        let driveRemovedList = driveInfosManager.storeDriveResponse(user: user, driveResponse: driveResponse)
        clearDriveFileManagers()

        for driveRemoved in driveRemovedList {
            let frozenSettings = photoLibraryUploader.frozenSettings
            if photoLibraryUploader.isSyncEnabled,
               frozenSettings?.userId == user.id,
               frozenSettings?.driveId == driveRemoved.id {
                photoLibrarySync.disableSync()
            }
            if currentDriveFileManager?.driveId == driveRemoved.id {
                setCurrentDriveForCurrentAccount(for: firstDrive.id, userId: firstDrive.userId)
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

    private func attachDeviceToApiToken(_ token: ApiToken, apiFetcher: ApiFetcher) {
        Task {
            do {
                let device = try await deviceManager.getOrCreateCurrentDevice()
                try await deviceManager.attachDeviceIfNeeded(device, to: token, apiFetcher: apiFetcher)
            } catch {
                SentryDebug.capture(message: SentryDebug.ErrorNames.failedToAttachDeviceError,
                                    context: ["error": error],
                                    level: .error)
            }
        }
    }

    private func updateMyKSuiteIfNeeded(for drives: [Drive], userId: Int, apiFetcher: DriveApiFetcher) async {
        guard drives.contains(where: { $0.pack.drivePackId == .myKSuite || $0.pack.drivePackId == .myKSuitePlus }) else {
            return
        }
        _ = try? await myKSuiteStore.updateMyKSuite(with: apiFetcher, id: userId)
    }

    public func loadAccounts() -> [Account] {
        guard let groupDirectoryURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AccountManager.appGroup)?
            .appendingPathComponent("preferences", isDirectory: true) else { return [] }
        let data: Data
        do {
            data = try Data(contentsOf: groupDirectoryURL.appendingPathComponent("accounts.json"))
        } catch {
            DDLogError("Error loading accounts \(error)")
            return []
        }

        do {
            let decoder = JSONDecoder()
            let savedAccounts = try decoder.decode([Account].self, from: data)

            return savedAccounts
        } catch is DecodingError {
            do {
                let migrationDecoder = JSONDecoder()
                migrationDecoder.keyDecodingStrategy = .convertFromSnakeCase

                let savedAccounts = try migrationDecoder.decode([Account].self, from: data)

                return savedAccounts
            } catch {
                DDLogError("Error migrating accounts \(error)")
                return []
            }
        } catch {
            DDLogError("Error loading accounts \(error)")
            return []
        }
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
            setCurrentDriveForCurrentAccount(for: drive.id, userId: drive.userId)
        }
        saveAccounts()
    }

    public func switchToNextAvailableAccount() {
        guard let nextAccount = nextAvailableAccount else {
            return
        }

        switchAccount(newAccount: nextAccount)
    }

    private var nextAvailableAccount: Account? {
        let allAccounts = accounts.values
        guard allAccounts.count > 1 else {
            return nil
        }

        guard let currentAccount else {
            return nil
        }

        guard let currentIndex = allAccounts.firstIndex(of: currentAccount) else {
            return nil
        }

        let nextIndex = currentIndex + 1
        guard let nextAccount = allAccounts[safe: nextIndex] else {
            return allAccounts.first
        }

        return nextAccount
    }

    private func setCurrentAccount(account: Account) {
        currentAccount = account
        currentUserId = account.userId
        enableBugTrackerIfAvailable()

        guard let token = account.token else { return }
        let apiFetcher = getApiFetcher(for: account.userId, token: token)
        attachDeviceToApiToken(token, apiFetcher: apiFetcher)
    }

    private func setSentryUserId(userId: Int) {
        guard userId != 0 else {
            return
        }
        let user = Sentry.User(userId: "\(userId)")
        user.ipAddress = "{{auto}}"
        SentrySDK.setUser(user)
    }

    public func setCurrentDriveForCurrentAccount(for driveId: Int, userId: Int) {
        currentDriveId = driveId
        getDriveFileManager(for: driveId, userId: userId)
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
            photoLibrarySync.disableSync()
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

        networkLogin.deleteApiToken(token: removedToken) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                DDLogError("Failed to delete api token: \(error.localizedDescription)")
            }
        }
    }

    public func account(for token: ApiToken) -> Account? {
        return accounts.first { $0.token?.userId == token.userId }
    }

    public func account(for userId: Int) -> Account? {
        return accounts.first { $0.userId == userId }
    }

    public func logoutCurrentAccountAndSwitchToNextIfPossible() {
        Task { @MainActor in
            deeplinkService.clearLastPublicShare()

            if let currentAccount {
                deviceManager.forgetLocalDeviceHash(forUserId: currentAccount.userId)
                removeTokenAndAccount(account: currentAccount)
            }

            if let nextAccount = accounts.first {
                switchAccount(newAccount: nextAccount)
                await appNavigable.refreshCacheScanLibraryAndUpload(preload: true, isSwitching: true)
            } else {
                SentrySDK.setUser(nil)
            }
            saveAccounts()
            appNavigable.prepareRootViewController(
                currentState: RootViewControllerState.getCurrentState(),
                restoration: false
            )
        }
    }

    public func enableBugTrackerIfAvailable() {
        if let currentUser = currentAccount?.user,
           let token = tokenStore.tokenFor(userId: currentUser.id),
           let isStaff = currentUser.isStaff,
           isStaff {
            bugTracker.activateOnScreenshot()
            let apiFetcher = getApiFetcher(for: currentUser.id, token: token)
            bugTracker.configure(with: apiFetcher)
        } else {
            bugTracker.stopActivatingOnScreenshot()
        }
    }
}
