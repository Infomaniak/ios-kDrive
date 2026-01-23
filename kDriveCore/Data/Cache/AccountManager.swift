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
import InfomaniakNotifications
import kDriveResources
import MyKSuite
import RealmSwift
import Sentry

public protocol UpdateAccountDelegate: AnyObject {
    @MainActor func didUpdateCurrentUserProfile(_ currentUser: InfomaniakCore.UserProfile)
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
    var currentAccount: ApiToken? { get }
    var accounts: [ApiToken] { get }
    var accountIds: [Int] { get }
    var currentUserId: Int { get }
    var currentDriveId: Int { get }
    var drives: [Drive] { get }
    var currentDriveFileManager: DriveFileManager? { get }
    var mqService: MQService { get }
    var refreshTokenLockedQueue: DispatchQueue { get }
    var userProfileStore: UserProfileStore { get }
    var delegate: AccountManagerDelegate? { get set }

    func getCurrentUser() async -> InfomaniakCore.UserProfile?
    func getDriveFileManager(for driveId: Int, userId: Int) -> DriveFileManager?
    @MainActor func getMatchingDriveFileManagerOrSwitchAccount(deeplink: LinkDriveProvider) async -> DriveFileManager?
    func updateAccountsInfos() async throws
    func getFirstAvailableDriveFileManager(for userId: Int) throws -> DriveFileManager
    func getFirstMatchingDriveFileManager(for userId: Int, driveId: Int) throws -> DriveFileManager?

    /// Create on the fly an "in memory" DriveFileManager for a specific share
    func getInMemoryDriveFileManager(for publicShareId: String, driveId: Int, token: String?,
                                     metadata: PublicShareMetadata) -> DriveFileManager?
    func getApiFetcher(for userId: Int, token: ApiToken) -> DriveApiFetcher
    func getTokenForUserId(_ id: Int) -> ApiToken?
    func didUpdateToken(newToken: ApiToken, oldToken: ApiToken)
    func didFailRefreshToken(_ token: ApiToken)
    func createAndSetCurrentAccount(code: String, codeVerifier: String) async throws -> ApiToken
    func createAndSetCurrentAccount(token: ApiToken) async throws -> ApiToken
    func updateUser(for account: ApiToken, registerToken: Bool) async throws -> ApiToken
    func switchAccount(newAccount: ApiToken)
    func switchToNextAvailableAccount()
    func setCurrentDriveForCurrentAccount(for driveId: Int, userId: Int)
    func addAccount(token: ApiToken) async throws
    func removeAccountFor(userId: Int)
    func removeTokenAndAccountFor(userId: Int)
    func removeCachedProperties()
    func account(for token: ApiToken) -> ApiToken?
    func account(for userId: Int) -> ApiToken?
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
    @LazyInjectService var notificationService: InfomaniakNotifications

    private static let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    private static let group = "com.infomaniak.drive"
    public static let appGroup = "group." + group
    public static let accessGroup: String = AccountManager.appIdentifierPrefix + AccountManager.group

    @SendableProperty public var currentAccount: ApiToken?
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

    public var accounts: [ApiToken] {
        return tokenStore.getAllTokens().values.map { $0.apiToken }
    }

    public var accountIds: [Int] {
        return Array(accounts.map(\.userId))
    }

    public let userProfileStore = UserProfileStore()
    private let driveFileManagers = SendableDictionary<String, DriveFileManager>()
    private let apiFetchers = SendableDictionary<Int, DriveApiFetcher>()
    public let mqService = MQService()

    public init() {
        currentDriveId = UserDefaults.shared.currentDriveId
        currentUserId = UserDefaults.shared.currentDriveUserId

        if let account = account(for: currentUserId) ?? accounts.first {
            setCurrentAccount(account: account)

            switchToFirstValidDriveFileManager()
        }
    }

    public func getCurrentUser() async -> InfomaniakCore.UserProfile? {
        return await userProfileStore.getUserProfile(id: currentUserId)
    }

    @discardableResult
    public func getDriveFileManager(for driveId: Int, userId: Int) -> DriveFileManager? {
        let objectId = DriveInfosManager.getObjectId(driveId: driveId, userId: userId)

        if let driveFileManager = driveFileManagers[objectId] {
            return driveFileManager
        } else if let token = tokenStore.tokenFor(userId: userId),
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

    private func getMatchingDriveAndAccount(deeplink: LinkDriveProvider, accounts: [ApiToken]) async
        -> (driveFileManager: DriveFileManager?, matchingAccount: ApiToken?)? {
        var driveFileManager: DriveFileManager?
        var matchingAccount: ApiToken?

        if let privateShareLink = deeplink as? PrivateShareLink {
            for account in accounts {
                guard let matchingDriveFileManager = getDriveFileManager(for: deeplink.driveId,
                                                                         userId: account.userId) else {
                    continue
                }
                do {
                    _ = try await matchingDriveFileManager.file(ProxyFile(
                        driveId: matchingDriveFileManager.driveId,
                        id: privateShareLink.fileId
                    ))

                    driveFileManager = matchingDriveFileManager
                    matchingAccount = account
                    break

                } catch {}
            }
        } else {
            for account in accounts {
                if let matchingDriveFileManager = try? getFirstMatchingDriveFileManager(
                    for: account.userId,
                    driveId: deeplink.driveId
                ) {
                    driveFileManager = matchingDriveFileManager
                    matchingAccount = account
                }
            }
        }

        return (driveFileManager, matchingAccount)
    }

    private func updateAccountsAndGetMatchingDrive(deeplink: LinkDriveProvider, accounts: [ApiToken]) async
        -> (driveFileManager: DriveFileManager?, matchingAccount: ApiToken?)? {
        if let match = await getMatchingDriveAndAccount(deeplink: deeplink, accounts: accounts),
           match.driveFileManager != nil && match.matchingAccount != nil {
            return match
        }
        do {
            try await updateAccountsInfos()
        } catch {}

        return await getMatchingDriveAndAccount(deeplink: deeplink, accounts: accounts)
    }

    @MainActor
    public func getMatchingDriveFileManagerOrSwitchAccount(deeplink: LinkDriveProvider) async -> DriveFileManager? {
        var driveFileManager: DriveFileManager?
        var matchingAccount: ApiToken?

        let orderedAccounts = accounts.sorted { account1, account2 in
            let isAccount1Connected = account1.userId == currentAccount?.userId
            let isAccount2Connected = account2.userId == currentAccount?.userId

            if isAccount1Connected && !isAccount2Connected {
                return true
            } else {
                return false
            }
        }

        if let match = await updateAccountsAndGetMatchingDrive(deeplink: deeplink, accounts: orderedAccounts) {
            driveFileManager = match.driveFileManager
            matchingAccount = match.matchingAccount
        }

        if let matchingAccount, let currentAccount, matchingAccount.userId != currentAccount.userId {
            DDLogInfo("switching to account \(matchingAccount.userId) to accommodate sharedWithMeLink navigation")
            deeplinkService.setLastDeeplink(deeplink)
            switchAccount(newAccount: matchingAccount)
            Task {
                await appNavigable.refreshCacheScanLibraryAndUpload(preload: false, isSwitching: false)
            }
            appNavigable.prepareRootViewController(
                currentState: RootViewControllerState.getCurrentState(),
                restoration: false
            )
            return nil
        }

        if driveFileManager == nil, !accounts.isEmpty {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.noRightsToOfficeLink)
        }

        guard let driveFileManager else {
            return nil
        }

        if deeplink.driveId != currentDriveId && !(deeplink is PrivateShareLink) {
            DDLogInfo("switching to drive \(deeplink.driveId) to accommodate sharedWithMeLink navigation")

            try? await driveFileManager.switchDriveAndReloadUI()
            deeplinkService.setLastDeeplink(deeplink)
            deeplinkService.processDeeplinksPostAuthentication()

            return nil
        }

        return driveFileManager
    }

    public func updateAccountsInfos() async throws {
        let allAccountsToUpdate = accounts
        try await allAccountsToUpdate.concurrentForEach(customConcurrency: Constants.networkParallelism) { account in
            _ = try await self.updateUser(for: account, registerToken: false)
        }
    }

    public func getInMemoryDriveFileManager(for publicShareId: String, driveId: Int, token: String?,
                                            metadata: PublicShareMetadata) -> DriveFileManager? {
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
        let publicShareProxy = PublicShareProxy(driveId: driveId, fileId: metadata.fileId,
                                                shareLinkUid: publicShareId, token: token)
        let context = DriveFileManagerContext.publicShare(shareProxy: publicShareProxy, metadata: metadata)

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

    public func removeCachedProperties() {
        driveFileManagers.removeAll()
        apiFetchers.removeAll()
    }

    public func getApiFetcher(for userId: Int, token: AssociatedApiToken) -> DriveApiFetcher {
        getApiFetcher(for: userId, token: token.apiToken)
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
        return tokenStore.tokenFor(userId: id)?.apiToken
    }

    public func didUpdateToken(newToken: ApiToken, oldToken: ApiToken) {
        SentryDebug.logTokenMigration(newToken: newToken, oldToken: oldToken)
        Task {
            let deviceId = try await deviceManager.getOrCreateCurrentDevice().uid
            tokenStore.addToken(newToken: newToken, associatedDeviceId: deviceId)
        }
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

        if accountToDelete.userId == currentAccount?.userId {
            DDLogInfo("matched \(String(describing: currentAccount)) to \(accountToDelete), removing current account")
            notificationHelper.sendDisconnectedNotification()
            logoutCurrentAccountAndSwitchToNextIfPossible()
        } else {
            DDLogInfo("user with token error \(accountToDelete) do not match current account, doing nothing")
            removeAccountFor(userId: accountToDelete.userId)
        }
    }

    public func createAndSetCurrentAccount(code: String, codeVerifier: String) async throws -> ApiToken {
        let token = try await InfomaniakLogin.apiToken(using: code, codeVerifier: codeVerifier)
        return try await createAndSetCurrentAccount(token: token)
    }

    public func createAndSetCurrentAccount(token: ApiToken) async throws -> ApiToken {
        let apiFetcher = DriveApiFetcher(token: token, delegate: self)
        let user = try await userProfileStore.updateUserProfile(with: apiFetcher)

        let driveResponse = try await apiFetcher.userDrives()
        guard !driveResponse.drives.filter(\.isDriveUser).isEmpty else {
            try? await networkLogin.deleteApiToken(token: token)
            throw DriveError.noDrive
        }

        attachDeviceToApiToken(token, apiFetcher: apiFetcher)
        async let _ = notificationService.updateTopicsIfNeeded([Topic.twoFAPushChallenge], userApiFetcher: apiFetcher)

        await updateMyKSuiteIfNeeded(for: driveResponse.drives, userId: user.id, apiFetcher: apiFetcher)

        try await addAccount(token: token)
        setCurrentAccount(account: token)

        guard let mainDrive = driveResponse.drives.first(where: { $0.isDriveUser && !$0.inMaintenance }) else {
            removeAccountFor(userId: token.userId)
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

        mqService.registerForNotifications(with: driveResponse.ips)

        return token
    }

    public func updateUser(for account: ApiToken, registerToken: Bool) async throws -> ApiToken {
        guard let token = tokenStore.tokenFor(userId: account.userId) else {
            throw DriveError.unknownToken
        }

        let apiFetcher = getApiFetcher(for: account.userId, token: token)
        let user = try await userProfileStore.updateUserProfile(with: apiFetcher)

        attachDeviceToApiToken(token.apiToken, apiFetcher: apiFetcher)
        async let _ = notificationService.updateTopicsIfNeeded([Topic.twoFAPushChallenge], userApiFetcher: apiFetcher)

        let driveResponse = try await apiFetcher.userDrives()
        guard !driveResponse.drives.isEmpty,
              let firstDrive = driveResponse.drives.first(where: { $0.isDriveUser }) else {
            removeAccountFor(userId: token.userId)
            throw DriveError.NoDriveError.noDrive
        }

        await updateMyKSuiteIfNeeded(for: driveResponse.drives, userId: account.userId, apiFetcher: apiFetcher)

        let driveRemovedList = driveInfosManager.storeDriveResponse(user: user, driveResponse: driveResponse)
        clearDriveFileManagers()

        for driveRemoved in driveRemovedList {
            let frozenSettings = photoLibraryUploader.frozenSettings
            if photoLibraryUploader.isSyncEnabled,
               frozenSettings?.userId == account.userId,
               frozenSettings?.driveId == driveRemoved.id {
                photoLibrarySync.disableSync()
            }
            if currentDriveFileManager?.driveId == driveRemoved.id {
                setCurrentDriveForCurrentAccount(for: firstDrive.id, userId: firstDrive.userId)
            }
            DriveFileManager.deleteUserDriveFiles(userId: token.userId, driveId: driveRemoved.id)
        }

        try await currentDriveFileManager?.initRoot()

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

    func switchToFirstValidDriveFileManager() {
        if let firstValidDriveFileManager = currentDriveFileManager, !firstValidDriveFileManager.drive.inMaintenance {
            return
        }

        guard let availableDriveFileManager = try? getFirstAvailableDriveFileManager(for: currentUserId) else {
            return
        }

        setCurrentDriveForCurrentAccount(for: availableDriveFileManager.driveId, userId: currentUserId)
    }

    public func switchAccount(newAccount: ApiToken) {
        setCurrentAccount(account: newAccount)
        UserDefaults.shared.lastSelectedTab = nil
        if let drive = drives.first {
            setCurrentDriveForCurrentAccount(for: drive.id, userId: drive.userId)
        }
    }

    public func switchToNextAvailableAccount() {
        guard let nextAccount = nextAvailableAccount else {
            return
        }

        switchAccount(newAccount: nextAccount)
    }

    private var nextAvailableAccount: ApiToken? {
        let allAccounts = accounts
        guard allAccounts.count > 1 else {
            return nil
        }

        guard let currentAccount else {
            return nil
        }

        if let currentIndex = allAccounts.firstIndex(where: { $0.userId == currentAccount.userId }) {
            let nextIndex = (currentIndex + 1) % allAccounts.count
            return allAccounts[nextIndex]
        }

        return nil
    }

    private func setCurrentAccount(account: ApiToken) {
        currentAccount = account
        currentUserId = account.userId

        let apiFetcher = getApiFetcher(for: account.userId, token: account)
        attachDeviceToApiToken(account, apiFetcher: apiFetcher)

        Task {
            await enableBugTrackerIfAvailable()
        }
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

    public func addAccount(token: ApiToken) async throws {
        UserDefaults.shared.lastSelectedTab = nil

        if accounts.contains(where: { $0.userId == token.userId }) {
            removeAccountFor(userId: token.userId)
        }

        let deviceId = try await deviceManager.getOrCreateCurrentDevice().uid
        tokenStore.addToken(newToken: token, associatedDeviceId: deviceId)
    }

    public func removeAccountFor(userId: Int) {
        UserDefaults.shared.lastSelectedTab = nil

        if currentAccount?.userId == userId {
            currentAccount = nil
            currentDriveId = 0
            currentUserId = 0
        }
        if photoLibraryUploader.isSyncEnabled && photoLibraryUploader.frozenSettings?.userId == userId {
            photoLibrarySync.disableSync()
        }
        driveInfosManager.deleteFileProviderDomains(for: userId)
        DriveFileManager.deleteUserDriveFiles(userId: userId)
        driveInfosManager.removeDrivesFor(userId: userId)
        driveFileManagers.removeAll()
        apiFetchers.removeAll()
    }

    public func removeTokenAndAccountFor(userId: Int) {
        let removedToken = tokenStore.removeTokenFor(userId: userId)
        removeAccountFor(userId: userId)

        Task {
            await notificationService.removeStoredTokenFor(userId: userId)
        }

        guard let removedToken else { return }

        networkLogin.deleteApiToken(token: removedToken) { result in
            guard case .failure(let error) = result else { return }
            DDLogError("Failed to delete api token: \(error.localizedDescription)")
        }
    }

    public func account(for token: ApiToken) -> ApiToken? {
        return tokenStore.tokenFor(userId: token.userId)?.apiToken
    }

    public func account(for userId: Int) -> ApiToken? {
        return tokenStore.tokenFor(userId: userId)?.apiToken
    }

    public func logoutCurrentAccountAndSwitchToNextIfPossible() {
        Task { @MainActor in
            deeplinkService.clearLastDeeplink()

            if let currentAccount {
                deviceManager.forgetLocalDeviceHash(forUserId: currentAccount.userId)
                removeTokenAndAccountFor(userId: currentAccount.userId)
            }

            if let nextAccount = accounts.first {
                switchAccount(newAccount: nextAccount)
                await appNavigable.refreshCacheScanLibraryAndUpload(preload: true, isSwitching: true)
            } else {
                SentrySDK.setUser(nil)
            }
            appNavigable.prepareRootViewController(
                currentState: RootViewControllerState.getCurrentState(),
                restoration: false
            )
        }
    }

    public func enableBugTrackerIfAvailable() async {
        if let currentUser = await userProfileStore.getUserProfile(id: currentUserId),
           let token = tokenStore.tokenFor(userId: currentUser.id),
           currentUser.isStaff == true {
            bugTracker.activateOnScreenshot()
            let apiFetcher = getApiFetcher(for: currentUser.id, token: token)
            bugTracker.configure(with: apiFetcher)
        } else {
            bugTracker.stopActivatingOnScreenshot()
        }
    }
}
