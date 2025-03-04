/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
@testable import InfomaniakDI
import InfomaniakLogin
@testable import kDrive
@testable import kDriveCore
import RealmSwift
import XCTest

final class ITAppLaunchTest: XCTestCase {
    let loginConfig = InfomaniakLogin.Config(clientId: "9473D73C-C20F-4971-9E10-D957C563FA68", accessType: nil)

    let fakeAccount = Account(apiToken: ApiToken(
        accessToken: "",
        expiresIn: 0,
        refreshToken: "",
        scope: "",
        tokenType: "",
        userId: 0,
        expirationDate: Date()
    ))

    override func setUpWithError() throws {
        SimpleResolver.sharedResolver.removeAll()

        let factoriesWithIdentifier = FactoryService.debugServices + FactoryService.transactionableServices
        SimpleResolver.register(factoriesWithIdentifier)
        let services = [
            Factory(type: KeychainHelper.self) { _, _ in
                KeychainHelper(accessGroup: AccountManager.accessGroup)
            },
            Factory(type: TokenStore.self) { _, _ in
                TokenStore()
            },
            Factory(type: AppContextServiceable.self) { _, _ in
                // We fake the main app context
                return AppContextService(context: .app)
            },
            Factory(type: InfomaniakNetworkLogin.self) { _, _ in
                return InfomaniakNetworkLogin(config: self.loginConfig)
            },
            Factory(type: UploadQueue.self) { _, _ in
                UploadQueue()
            },
            Factory(type: DownloadQueueable.self) { _, _ in
                DownloadQueue()
            },
            Factory(type: UploadQueueable.self) { _, resolver in
                try resolver.resolve(type: UploadQueue.self,
                                     forCustomTypeIdentifier: nil,
                                     factoryParameters: nil,
                                     resolver: resolver)
            },
            Factory(type: InfomaniakNetworkLoginable.self) { _, resolver in
                try resolver.resolve(type: InfomaniakNetworkLogin.self,
                                     forCustomTypeIdentifier: nil,
                                     factoryParameters: nil,
                                     resolver: resolver)
            },
            Factory(type: InfomaniakLoginable.self) { _, _ in
                InfomaniakLogin(config: self.loginConfig)
            },
            Factory(type: AppLockHelper.self) { _, _ in
                AppLockHelper()
            },
            Factory(type: PhotoLibraryUploader.self) { _, _ in
                PhotoLibraryUploader()
            },
            Factory(type: DriveInfosManager.self) { _, _ in
                DriveInfosManager()
            },
            Factory(type: AppNavigable.self) { _, _ in
                AppRouter()
            },
            Factory(type: AppExtensionRoutable.self) { _, _ in
                AppExtensionRouter()
            },
            Factory(type: AvailableOfflineManageable.self) { _, _ in
                MCKAvailableOfflineManager()
            }
        ]
        SimpleResolver.register(services)
    }

    @MainActor func testUnlock() throws {
        // GIVEN applock enabled
        UserDefaults.shared.isAppLockEnabled = true
        let accountManagerFactory = Factory(type: AccountManageable.self) { _, _ in
            let accountManager = MockAccountManager()
            accountManager.accounts.append(self.fakeAccount)
            accountManager.currentAccount = self.fakeAccount
            accountManager.currentUserId = self.fakeAccount.userId
            accountManager.currentDriveFileManager = DriveFileManager(
                drive: Drive(),
                apiFetcher: DriveApiFetcher(token: self.fakeAccount.token, delegate: accountManager)
            )
            return accountManager
        }
        SimpleResolver.sharedResolver.store(factory: accountManagerFactory)

        @InjectService var accountManager: AccountManageable
        XCTAssertNotNil(accountManager.currentAccount, "expecting a user logged in")

        @InjectService var router: AppNavigable
        router.showAppLock()

        let scene = UIApplication.shared.connectedScenes.first
        let sceneDelegate = (scene?.delegate as? SceneDelegate)
        let window = sceneDelegate?.window
        let rootViewController = window?.rootViewController
        XCTAssertNotNil(
            rootViewController as? LockedAppViewController,
            "Should be a LockedAppViewController, got \(rootViewController as UIViewController?)"
        )

        // WHEN
        let lockedAppViewController = LockedAppViewController.instantiate()
        lockedAppViewController.unlockApp()

        // THEN
        guard let rootViewControllerRefresh = window?.rootViewController else {
            XCTFail("Expecting a rootViewController")
            return
        }

        let lockView = rootViewControllerRefresh as? LockedAppViewController
        XCTAssertNil(lockView, "no longer expecting a lock view, got \(lockView as LockedAppViewController?)")
    }
}
