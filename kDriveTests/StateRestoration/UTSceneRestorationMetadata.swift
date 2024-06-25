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
@testable import InfomaniakDI
import InfomaniakLogin
@testable import kDrive
@testable import kDriveCore
import XCTest

private class FakeTokenDelegate: RefreshTokenDelegate {
    func didUpdateToken(newToken: ApiToken, oldToken: ApiToken) {
        // META: keep SonarCloud happy
    }

    func didFailRefreshToken(_ token: ApiToken) {
        // META: keep SonarCloud happy
    }
}

/// Unit test metadata for each supported screen
final class UTSceneRestorationMetadata: XCTestCase {
    static var driveFileManager: DriveFileManager!

    override class func setUp() {
        super.setUp()

        // prepare mocking solver
        MockingHelper.registerConcreteTypes()

        @InjectService var driveInfosManager: DriveInfosManager
        @InjectService var mckAccountManager: AccountManageable

        let token = ApiToken(accessToken: Env.token,
                             expiresIn: Int.max,
                             refreshToken: "",
                             scope: "",
                             tokenType: "",
                             userId: Env.userId,
                             expirationDate: Date(timeIntervalSinceNow: TimeInterval(Int.max)))

        let apiFetcher = DriveApiFetcher(token: token, delegate: FakeTokenDelegate())
        let drive = Drive()
        drive.userId = Env.userId
        driveFileManager = DriveFileManager(drive: drive, apiFetcher: apiFetcher)

        mckAccountManager.getDriveFileManager(for: Env.driveId, userId: Env.userId)
    }

    override class func tearDown() {
        // clear mocking solver so the next test is stable
        MockingHelper.clearRegisteredTypes()

        super.tearDown()
    }

    @MainActor func testFileListViewModel() {
        // GIVEN
        let mckFile = File(id: 1337, name: "kernel.bin")
        let viewModel = FileListViewModel(configuration: FileListViewModel.Configuration(emptyViewType: .emptyFolder),
                                          driveFileManager: Self.driveFileManager,
                                          currentDirectory: mckFile)
        let fileListViewModel = FileListViewController.instantiate(viewModel: viewModel)

        // WHEN
        let metadata = fileListViewModel.currentSceneMetadata

        // THEN
        XCTAssertFalse(metadata.isEmpty, "Expecting some metadata")
        XCTAssertEqual(metadata["lastViewController"] as? String, "FileListViewController")
        XCTAssertEqual(metadata["driveId"] as? Int, Int(-1))
        XCTAssertEqual(metadata["fileId"] as? Int, Int(1337))
    }

    @MainActor func testPreviewViewController() {
        // GIVEN
        let mckFile = File(id: 1337, name: "kernel.bin")
        let previewViewController = PreviewViewController.instantiate(
            files: [mckFile],
            index: 0,
            driveFileManager: Self.driveFileManager,
            normalFolderHierarchy: true,
            fromActivities: true
        )

        // WHEN
        let metadata = previewViewController.currentSceneMetadata

        // THEN
        XCTAssertFalse(metadata.isEmpty, "Expecting some metadata")
        XCTAssertEqual(metadata["lastViewController"] as? String, "PreviewViewController")
        XCTAssertEqual(metadata["driveId"] as? Int, Int(-1))
        XCTAssertEqual(metadata["filesIds"] as? [Int], [1337])
        XCTAssertEqual(metadata["currentIndex"] as? Int, Int(0))
        XCTAssertEqual(metadata["normalFolderHierarchy"] as? Bool, true)
        XCTAssertEqual(metadata["fromActivities"] as? Bool, true)
    }

    @MainActor func testFileDetailViewController() {
        // GIVEN
        let mckFile = File(id: 1337, name: "kernel.bin")
        let fileDetailViewController = FileDetailViewController.instantiate(
            driveFileManager: Self.driveFileManager,
            file: mckFile
        )

        // WHEN
        let metadata = fileDetailViewController.currentSceneMetadata

        // THEN
        XCTAssertFalse(metadata.isEmpty, "Expecting some metadata")
        XCTAssertEqual(metadata["lastViewController"] as? String, "FileDetailViewController")
        XCTAssertEqual(metadata["driveId"] as? Int, Int(-1))
        XCTAssertEqual(metadata["fileId"] as? Int, Int(1337))
    }

    @MainActor func testStoreViewController() {
        // GIVEN
        let storeViewController = StoreViewController.instantiate(driveFileManager: Self.driveFileManager)

        // WHEN
        let metadata = storeViewController.currentSceneMetadata

        // THEN
        XCTAssertFalse(metadata.isEmpty, "Expecting some metadata")
        XCTAssertEqual(metadata["lastViewController"] as? String, "StoreViewController")
        XCTAssertEqual(metadata["driveId"] as? Int, Int(-1))
    }

    @MainActor func testRootMenuViewController() {
        // GIVEN
        let rootMenuViewController = RootMenuViewController(driveFileManager: Self.driveFileManager)

        // WHEN
        let metadata = rootMenuViewController.currentSceneMetadata

        // THEN
        XCTAssertTrue(metadata.isEmpty, "Expecting empty metadata")
    }

    @MainActor func testHomeViewController() {
        // GIVEN
        let homeViewController = HomeViewController(driveFileManager: Self.driveFileManager)

        // WHEN
        let metadata = homeViewController.currentSceneMetadata

        // THEN
        XCTAssertTrue(metadata.isEmpty, "Expecting empty metadata")
    }

    @MainActor func testPhotoListViewController() {
        // GIVEN
        let mckFile = File(id: 1337, name: "kernel.bin")
        let viewModel = FileListViewModel(configuration: FileListViewModel.Configuration(emptyViewType: .emptyFolder),
                                          driveFileManager: Self.driveFileManager,
                                          currentDirectory: mckFile)
        let photoListViewController = PhotoListViewController.instantiate(viewModel: viewModel)

        // WHEN
        let metadata = photoListViewController.currentSceneMetadata

        // THEN
        XCTAssertTrue(metadata.isEmpty, "Expecting empty metadata")
    }

    @MainActor func testMenuViewController() {
        // GIVEN
        let photoListViewController = MenuViewController(driveFileManager: Self.driveFileManager)

        // WHEN
        let metadata = photoListViewController.currentSceneMetadata

        // THEN
        XCTAssertTrue(metadata.isEmpty, "Expecting empty metadata")
    }
}
