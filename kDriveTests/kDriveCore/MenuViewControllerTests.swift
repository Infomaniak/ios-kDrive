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

@testable import Alamofire
@testable import InfomaniakCore
@testable import InfomaniakDI
import InfomaniakLogin
@testable import kDrive
@testable import kDriveCore
import XCTest

final class MenuViewControllerTests: XCTestCase {
    override func setUp() {
        MockingHelper.clearRegisteredTypes()
        MockingHelper.registerConcreteTypes(configuration: .minimal)
    }

    // MARK: - Upload observation

    func testObserveUploads() {
        // GIVEN
        let mockFutureDate = Date(timeIntervalSinceNow: 1_234_567)
        let mockToken = ApiToken(accessToken: "123",
                                 expiresIn: 1337,
                                 refreshToken: "refreshToken",
                                 scope: "scope",
                                 tokenType: "tokenType",
                                 userId: 1337, expirationDate: mockFutureDate)
        let mockAccount = Account(apiToken: mockToken)
        let session = Alamofire.Session()
        let accountManagerFactory = Factory(type: AccountManageable.self) { _, _ in
            let manager = AccountManager()
            manager.currentAccount = mockAccount
            return manager
        }
        SimpleResolver.register([accountManagerFactory])

        let driveApiFetcher = DriveApiFetcher()
        driveApiFetcher.authenticatedSession = session
        let drive = Drive()
        let driveFileManager = DriveFileManager(drive: drive, apiFetcher: driveApiFetcher)

        // WHEN
        let menuViewController = MenuViewController(driveFileManager: driveFileManager)

        // THEN
        XCTAssertNotNil(menuViewController.uploadCountManager, "We should be observing the upload queue")
    }
}
