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
import kDriveCore
import RealmSwift

class MockAccountManager: AccountManageable, RefreshTokenDelegate {
    var currentAccount: Account! {
        return accounts.first!
    }

    var accounts: [Account] = []

    var tokens: [ApiToken] = []

    var currentUserId = 0

    var currentDriveId = 0

    var drives: [Drive] = []

    var currentDriveFileManager: DriveFileManager?

    var mqService: MQService { fatalError("Not implemented") }

    var refreshTokenLockedQueue = DispatchQueue(label: "com.infomaniak.drive.refreshtoken")

    func forceReload() {}

    func reloadTokensAndAccounts() {}

    func getDriveFileManager(for drive: Drive) -> DriveFileManager? { currentDriveFileManager }

    func getDriveFileManager(for driveId: Int, userId: Int) -> DriveFileManager? { currentDriveFileManager }

    func getFirstAvailableDriveFileManager(for userId: Int) throws -> DriveFileManager { fatalError("Not implemented") }

    func getApiFetcher(for userId: Int, token: ApiToken) -> DriveApiFetcher { fatalError("Not implemented") }

    func getDrive(for accountId: Int, driveId: Int, using realm: Realm?) -> Drive? { nil }

    func getTokenForUserId(_ id: Int) -> ApiToken? { nil }

    func didUpdateToken(newToken: ApiToken, oldToken: ApiToken) {}

    func didFailRefreshToken(_ token: ApiToken) {}

    func createAndSetCurrentAccount(code: String, codeVerifier: String) async throws -> Account { fatalError("Not implemented") }

    func createAndSetCurrentAccount(token: ApiToken) async throws -> Account { fatalError("Not implemented") }

    func updateUser(for account: Account, registerToken: Bool) async throws -> Account { fatalError("Not implemented") }

    func loadAccounts() -> [Account] { fatalError("Not implemented") }

    func saveAccounts() {}

    func switchAccount(newAccount: Account) {}

    func setCurrentDriveForCurrentAccount(drive: Drive) {}

    func addAccount(account: Account) {}

    func removeAccount(toDeleteAccount: Account) {}

    func removeTokenAndAccount(token: ApiToken) {}

    func account(for token: ApiToken) -> Account? { fatalError("Not implemented") }

    func account(for userId: Int) -> Account? { fatalError("Not implemented") }

    func updateToken(newToken: ApiToken, oldToken: ApiToken) {}
}
