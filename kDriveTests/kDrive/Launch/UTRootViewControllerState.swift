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
import InfomaniakCoreUIKit
@testable import InfomaniakDI
import InfomaniakLogin
@testable import kDrive
@testable import kDriveCore
import RealmSwift
import XCTest

final class UTRootViewControllerState: XCTestCase {
    let loginConfig = InfomaniakLogin.Config(clientId: "9473D73C-C20F-4971-9E10-D957C563FA68", accessType: nil)

    let fakeAccount = Account(apiToken: ApiToken(
        accessToken: "",
        expiresIn: 0,
        refreshToken: "",
        scope: "",
        tokenType: "",
        userId: 1234,
        expirationDate: Date()
    ))

    override func setUp() {
        super.setUp()
        MockingHelper.clearRegisteredTypes()
        MockingHelper.registerConcreteTypes(configuration: .minimal)

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
                InfomaniakNetworkLogin(config: self.loginConfig)
            },
            Factory(type: UploadQueue.self) { _, _ in
                UploadQueue()
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
            Factory(type: InfomaniakTokenable.self) { _, resolver in
                try resolver.resolve(type: InfomaniakLoginable.self,
                                     forCustomTypeIdentifier: nil,
                                     factoryParameters: nil,
                                     resolver: resolver)
            },
            Factory(type: InfomaniakLoginable.self) { _, _ in
                InfomaniakLogin(config: self.loginConfig)
            },
            Factory(type: AppLockHelper.self) { _, _ in
                AppLockHelper()
            }
        ]

        for service in services {
            SimpleResolver.sharedResolver.store(factory: service)
        }
    }

    func testFirstLaunchState() throws {
        // GIVEN empty accounts
        UserDefaults.shared.isAppLockEnabled = false
        UserDefaults.shared.legacyIsFirstLaunch = true

        let emptyAccountManagerFactory = Factory(type: AccountManageable.self) { _, _ in
            let accountManager = MockAccountManager()
            return accountManager
        }
        SimpleResolver.sharedResolver.store(factory: emptyAccountManagerFactory)

        // WHEN
        let currentState = RootViewControllerState.getCurrentState()

        // THEN
        XCTAssertEqual(currentState, .onboarding, "State should be onboarding")
    }

    func testOnboardingState() throws {
        // GIVEN empty accounts
        UserDefaults.shared.isAppLockEnabled = false
        UserDefaults.shared.legacyIsFirstLaunch = false

        let emptyAccountManagerFactory = Factory(type: AccountManageable.self) { _, _ in
            let accountManager = MockAccountManager()
            return accountManager
        }
        SimpleResolver.sharedResolver.store(factory: emptyAccountManagerFactory)

        // WHEN
        let currentState = RootViewControllerState.getCurrentState()

        // THEN
        XCTAssertEqual(currentState, .onboarding, "State should be onboarding")
    }

    func testOnboardingWithAppLockState() throws {
        // GIVEN empty accounts BUT AppLock enabled
        UserDefaults.shared.isAppLockEnabled = true
        UserDefaults.shared.legacyIsFirstLaunch = false

        let emptyAccountManagerFactory = Factory(type: AccountManageable.self) { _, _ in
            let accountManager = MockAccountManager()
            return accountManager
        }
        SimpleResolver.sharedResolver.store(factory: emptyAccountManagerFactory)

        // WHEN
        let currentState = RootViewControllerState.getCurrentState()

        // THEN
        XCTAssertEqual(currentState, .onboarding, "State should be onboarding")
    }

    func testAppLockState() throws {
        // GIVEN
        UserDefaults.shared.isAppLockEnabled = true
        UserDefaults.shared.legacyIsFirstLaunch = false

        let emptyAccountManagerFactory = Factory(type: AccountManageable.self) { _, _ in
            let accountManager = MockAccountManager()
            accountManager.accounts.append(self.fakeAccount)
            accountManager.currentAccount = self.fakeAccount
            accountManager.currentUserId = self.fakeAccount.userId
            return accountManager
        }
        SimpleResolver.sharedResolver.store(factory: emptyAccountManagerFactory)

        // WHEN
        let currentState = RootViewControllerState.getCurrentState()

        // THEN
        XCTAssertEqual(currentState, .appLock, "State should be applock, got \(currentState)")
    }

    func testNoDriveFileManagerState() throws {
        // GIVEN
        UserDefaults.shared.isAppLockEnabled = false
        UserDefaults.shared.legacyIsFirstLaunch = false

        let emptyAccountManagerFactory = Factory(type: AccountManageable.self) { _, _ in
            let accountManager = MockAccountManager()
            accountManager.accounts.append(self.fakeAccount)
            return accountManager
        }
        SimpleResolver.sharedResolver.store(factory: emptyAccountManagerFactory)

        // WHEN
        let currentState = RootViewControllerState.getCurrentState()

        // THEN
        XCTAssertEqual(currentState, .onboarding, "State should be onboarding")
    }

    func testMainViewControllerState() throws {
        // GIVEN
        UserDefaults.shared.isAppLockEnabled = false
        UserDefaults.shared.legacyIsFirstLaunch = false

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

        // WHEN
        let currentState = RootViewControllerState.getCurrentState()

        // THEN
        switch currentState {
        case .preloading(let account):
            XCTAssertEqual(account.id, fakeAccount.userId)
        default:
            XCTFail("Should be preloading \(fakeAccount), got \(currentState)")
        }
    }
}

extension RootViewControllerState: Equatable {
    public static func == (lhs: RootViewControllerState, rhs: RootViewControllerState) -> Bool {
        switch (lhs, rhs) {
        case (.appLock, .appLock):
            return true
        case (.onboarding, .onboarding):
            return true
        case (.mainViewController(let lhsMailboxManager), .mainViewController(let rhsMailboxManager)):
            return lhsMailboxManager.drive.objectId == rhsMailboxManager.drive.objectId
        default:
            return false
        }
    }
}
