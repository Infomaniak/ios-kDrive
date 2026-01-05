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

import Foundation
import InfomaniakCore
import InfomaniakLogin
import kDriveCore
import RealmSwift

class MockAccountManager: AccountManageable, RefreshTokenDelegate {
    var accountIds = [Int]()

    var delegate: AccountManagerDelegate?

    var currentAccount: ApiToken?

    var accounts: [ApiToken] = []
    var currentUserId = 0

    var currentDriveId = 0

    var drives: [Drive] = []

    var currentDriveFileManager: DriveFileManager?

    var userProfileStore = UserProfileStore()

    var mqService: MQService { fatalError("Not implemented") }

    var refreshTokenLockedQueue = DispatchQueue(label: "com.infomaniak.drive.refreshtoken")

    func getCurrentUser() async -> InfomaniakCore.UserProfile? {
        return nil
    }

    func getDriveFileManager(for driveId: Int, userId: Int) -> DriveFileManager? {
        return currentDriveFileManager
    }

    func getMatchingDriveFileManagerOrSwitchAccount(deeplink: any LinkDriveProvider) async -> DriveFileManager? {
        return currentDriveFileManager
    }

    func updateAccountsInfos() async throws {}

    func getFirstAvailableDriveFileManager(for userId: Int) throws -> DriveFileManager {
        fatalError("Not implemented")
    }

    func getFirstMatchingDriveFileManager(for userId: Int, driveId: Int) throws -> DriveFileManager? {
        return currentDriveFileManager
    }

    func getInMemoryDriveFileManager(for publicShareId: String, driveId: Int,
                                     metadata: PublicShareMetadata) -> DriveFileManager? {
        return currentDriveFileManager
    }

    func getApiFetcher(for userId: Int, token: ApiToken) -> DriveApiFetcher { fatalError("Not implemented") }

    func getTokenForUserId(_ id: Int) -> ApiToken? { return nil }

    func didUpdateToken(newToken: ApiToken, oldToken: ApiToken) {}

    func didFailRefreshToken(_ token: ApiToken) {}

    func createAndSetCurrentAccount(code: String, codeVerifier: String) async throws -> ApiToken { fatalError("Not implemented") }

    func createAndSetCurrentAccount(token: ApiToken) async throws -> ApiToken { fatalError("Not implemented") }

    func updateUser(for account: ApiToken, registerToken: Bool) async throws -> ApiToken { fatalError("Not implemented") }

    func switchAccount(newAccount: ApiToken) {}

    func switchToNextAvailableAccount() {}

    func setCurrentDriveForCurrentAccount(for driveId: Int, userId: Int) {}

    func addAccount(token: ApiToken) async throws {}

    func removeAccountFor(userId: Int) {}

    func removeTokenAndAccountFor(userId: Int) {}

    func removeCachedProperties() {}

    func account(for token: ApiToken) -> ApiToken? { return nil }

    func account(for userId: Int) -> ApiToken? { return nil }

    func logoutCurrentAccountAndSwitchToNextIfPossible() {}
}
