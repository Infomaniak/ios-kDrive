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

import Foundation
import InfomaniakCore
import InfomaniakLogin
import kDriveCore
import XCTest

@testable import kDrive

class FakeTokenDelegate: RefreshTokenDelegate {
    func didUpdateToken(newToken: ApiToken, oldToken: ApiToken) {}

    func didFailRefreshToken(_ token: ApiToken) {}
}

final class DriveApiTests: XCTestCase {
    static let defaultTimeout = 30.0
    static var driveFileManager: DriveFileManager!
    var currentDrive: Drive {
        return DriveApiTests.driveFileManager.drive
    }

    var currentApiFetcher: DriveApiFetcher {
        return DriveApiTests.driveFileManager.apiFetcher
    }

    override class func setUp() {
        super.setUp()
        let drive = DriveInfosManager.instance.getDrive(id: Env.driveId, userId: Env.userId)!
        driveFileManager = AccountManager.instance.getDriveFileManager(for: drive)
        driveFileManager.apiFetcher.setToken(ApiToken(accessToken: Env.token, expiresIn: Int.max, refreshToken: "", scope: "", tokenType: "", userId: Env.userId, expirationDate: Date(timeIntervalSinceNow: TimeInterval(Int.max))), delegate: FakeTokenDelegate())
    }

    // MARK: - Tests setup

    func setUpTest(testName: String, completion: @escaping (File) -> Void) {
        getRootDirectory { rootFile in
            self.createTestDirectory(name: "UnitTest - \(testName)", parentDirectory: rootFile) { file in
                XCTAssertNotNil(file, "Failed to create UnitTest directory")
                completion(file)
            }
        }
    }

    func tearDownTest(directory: File) {
        currentApiFetcher.deleteFile(file: directory) { response, _ in
            XCTAssertNotNil(response, "Failed to delete directory")
        }
    }

    // MARK: - Helping methods

    func getRootDirectory(completion: @escaping (File) -> Void) {
        currentApiFetcher.getFileListForDirectory(driveId: currentDrive.id, parentId: DriveFileManager.constants.rootID) { response, _ in
            XCTAssertNotNil(response?.data, "Failed to get root directory")
            completion(response!.data!)
        }
    }

    func createTestDirectory(name: String, parentDirectory: File, completion: @escaping (File) -> Void) {
        currentApiFetcher.createDirectory(parentDirectory: parentDirectory, name: "\(name) - \(Date())", onlyForMe: true) { response, error in
            XCTAssertNotNil(response?.data, "Failed to create test directory")
            XCTAssertNil(error, "There should be no error")
            completion(response!.data!)
        }
    }

    func initDropbox(testName: String, completion: @escaping (File, File) -> Void) {
        setUpTest(testName: testName) { rootFile in
            self.createTestDirectory(name: "dropbox-\(Date())", parentDirectory: rootFile) { dir in
                self.currentApiFetcher.setupDropBox(directory: dir, password: "", validUntil: nil, emailWhenFinished: false, limitFileSize: nil) { response, _ in
                    XCTAssertNotNil(response?.data, "Failed to create dropbox")
                    completion(rootFile, dir)
                }
            }
        }
    }

    func initOfficeFile(testName: String, completion: @escaping (File, File) -> Void) {
        setUpTest(testName: testName) { rootFile in
            self.currentApiFetcher.createOfficeFile(driveId: self.currentDrive.id, parentDirectory: rootFile, name: "officeFile-\(Date())", type: "docx") { response, _ in
                XCTAssertNotNil(response?.data, "Failed to create office file")
                completion(rootFile, response!.data!)
            }
        }
    }

    // MARK: - Test methods

    func testGetRootFile() {
        let expectation = XCTestExpectation(description: "Get root file")

        currentApiFetcher.getFileListForDirectory(driveId: currentDrive.id, parentId: DriveFileManager.constants.rootID) { response, error in
            XCTAssertNotNil(response?.data, "Root file shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetCommonDocuments() {
        let expectation = XCTestExpectation(description: "Get 'Common documents' file")

        currentApiFetcher.getFileListForDirectory(driveId: currentDrive.id, parentId: Env.commonDocumentsId) { response, error in
            XCTAssertNotNil(response?.data, "Root file shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testCreateDirectory() {
        let testName = "Create directory"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.createDirectory(parentDirectory: rootFile, name: "\(testName)-\(Date())", onlyForMe: true) { response, error in
                XCTAssertNotNil(response?.data, "Created file shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testCreateCommonDirectory() {
        let testName = "Create common directory"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        currentApiFetcher.createCommonDirectory(driveId: currentDrive.id, name: "\(testName)-\(Date())", forAllUser: true) { response, error in
            XCTAssertNotNil(response?.data, "Created common directory shouldn't be nil")
            rootFile = response!.data!
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testCreateOfficeFile() {
        let testName = "Create office file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.createOfficeFile(driveId: self.currentDrive.id, parentDirectory: rootFile, name: "\(testName)-\(Date())", type: "docx") { response, error in
                XCTAssertNotNil(response?.data, "Created office file shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testSetupDrobBox() {
        let testName = "Setup dropbox"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        let password = "password"
        let validUntil: Date? = nil
        let limitFileSize: Int? = nil

        setUpTest(testName: testName) { root in
            rootFile = root
            self.createTestDirectory(name: testName, parentDirectory: rootFile) { dir in
                self.currentApiFetcher.setupDropBox(directory: dir, password: password, validUntil: validUntil, emailWhenFinished: false, limitFileSize: limitFileSize) { response, error in
                    XCTAssertNotNil(response?.data, "Dropbox shouldn't be nil")
                    XCTAssertNil(error, "There should be no error")
                    let dropbox = response!.data!
                    XCTAssertTrue(dropbox.password, "Dropbox should have a password")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testDropBoxSetting() {
        let testName = "Dropbox settings"
        let expectations = [
            (name: "Get dropbox settings", expectation: XCTestExpectation(description: "Get dropbox settings")),
            (name: "Update dropbox settings", expectation: XCTestExpectation(description: "Update dropbox settings"))
        ]
        var rootFile = File()

        let password = "newPassword"
        let validUntil: Date? = Date()
        let limitFileSize: Int? = 5368709120

        initDropbox(testName: testName) { root, dropbox in
            rootFile = root

            self.currentApiFetcher.updateDropBox(directory: dropbox, password: password, validUntil: validUntil, emailWhenFinished: false, limitFileSize: limitFileSize) { _, error in
                XCTAssertNil(error, "There should be no error")
                self.currentApiFetcher.getDropBoxSettings(directory: dropbox) { dropboxSetting, error in
                    XCTAssertNotNil(dropboxSetting?.data, "Dropbox shouldn't be nil")
                    XCTAssertNil(error, "There should be no error")
                    expectations[0].expectation.fulfill()

                    let dropbox = dropboxSetting!.data!
                    XCTAssertTrue(dropbox.password, "Password should be true")
                    XCTAssertNotNil(dropbox.validUntil, "ValidUntil shouldn't be nil")
                    XCTAssertNotNil(dropbox.limitFileSize, "LimitFileSize shouldn't be nil")
                    expectations[1].expectation.fulfill()
                }
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testDisableDropBox() {
        let testName = "Disable dropbox"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initDropbox(testName: testName) { root, dropbox in
            rootFile = root
            self.currentApiFetcher.getDropBoxSettings(directory: dropbox) { response, error in
                XCTAssertNotNil(response?.data, "Dropbox shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                self.currentApiFetcher.disableDropBox(directory: dropbox) { _, disableError in
                    XCTAssertNil(disableError, "There should be no error")
                    self.currentApiFetcher.getDropBoxSettings(directory: dropbox) { invalidDropbox, invalidError in
                        XCTAssertNil(invalidDropbox?.data, "There should be no dropbox")
                        XCTAssertNil(invalidError, "There should be no error")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testGetFavoriteFiles() {
        let testName = "Get favorite files"
        let expectation = XCTestExpectation(description: testName)

        currentApiFetcher.getFavoriteFiles(driveId: currentDrive.id) { response, error in
            XCTAssertNotNil(response?.data, "Favorite files shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetMyShared() {
        let testName = "Get my shared files"
        let expectation = XCTestExpectation(description: testName)

        currentApiFetcher.getMyShared(driveId: currentDrive.id) { response, error in
            XCTAssertNotNil(response?.data, "My shared files shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetLastModifiedFiles() {
        let testName = "Get last modified files"
        let expectation = XCTestExpectation(description: testName)

        currentApiFetcher.getLastModifiedFiles(driveId: currentDrive.id) { response, error in
            XCTAssertNotNil(response?.data, "Last modified files shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetLastPictures() {
        let testName = "Get last pictures"
        let expectation = XCTestExpectation(description: testName)

        currentApiFetcher.getLastPictures(driveId: currentDrive.id) { response, error in
            XCTAssertNotNil(response?.data, "Last pictures shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetShareListFor() {
        let testName = "Get share list"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.getShareListFor(file: rootFile) { response, error in
                XCTAssertNotNil(response?.data, "Share list shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testActivateShareLinkFor() {
        let testName = "Activate share link"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.activateShareLinkFor(file: rootFile) { response, error in
                XCTAssertNotNil(response?.data, "Share link shouldn't be nil")
                XCTAssertNil(error, "There should be no error")

                self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                    XCTAssertNotNil(shareResponse, "Share response shouldn't be nil")
                    XCTAssertNil(shareError, "There should be no error")
                    let share = shareResponse!.data!
                    XCTAssertNotNil(share.link?.url, "Share link url shouldn't be nil")
                    XCTAssertTrue(response!.data!.url == share.link?.url, "Share link url should match")

                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testUpdateShareLinkWith() {
        let testName = "Update share link"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.activateShareLinkFor(file: rootFile) { _, _ in
                self.currentApiFetcher.updateShareLinkWith(file: rootFile, canEdit: true, permission: "password", password: "password", date: nil, blockDownloads: true, blockComments: false, blockInformation: false, isFree: false) { updateResponse, updateError in
                    XCTAssertNotNil(updateResponse, "Response shouldn't be nil")
                    XCTAssertNil(updateError, "There should be no error")

                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, "Share response shouldn't be nil")
                        XCTAssertNil(shareError, "There should be no error")
                        let share = shareResponse!.data!
                        XCTAssertNotNil(share.link, "Share link shouldn't be nil")
                        print(share.link!)
                        XCTAssertTrue(share.link!.canEdit, "canEdit should be true")
                        XCTAssertTrue(share.link!.permission == "password", "Permission should be equal to 'password'")
                        XCTAssertTrue(share.link!.blockDownloads, "blockDownloads should be true")
                        XCTAssertTrue(!share.link!.blockComments, "blockComments should be false")
                        XCTAssertTrue(!share.link!.blockInformation, "blockInformation should be false")

                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testAddUserRights() {
        let testName = "Add user rights"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.addUserRights(file: rootFile, users: [Env.inviteUserId], teams: [], emails: [], message: "Invitation test", permission: UserPermission.manage.rawValue) { response, error in
                XCTAssertNotNil(response?.data, "Response shouldn't be nil")
                XCTAssertNil(error, "There should be no error")

                self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                    XCTAssertNotNil(shareResponse?.data, "Response shouldn't be nil")
                    XCTAssertNil(shareError, "There should be no error")
                    let share = shareResponse!.data!
                    let userAdded = share.users.first { user -> Bool in
                        if user.id == Env.inviteUserId {
                            XCTAssertTrue(user.permission == .manage, "Added user permission should be equal to 'manage'")
                            return true
                        }
                        return false
                    }
                    XCTAssertNotNil(userAdded, "Added user should be in share list")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testCheckUserRights() {
        let testName = "Check user rights"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.checkUserRights(file: rootFile, users: [Env.inviteUserId], teams: [], emails: [], permission: UserPermission.manage.rawValue) { response, error in
                XCTAssertNotNil(response, "Response shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testUpdateUserRights() {
        let testName = "Update user rights"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.addUserRights(file: rootFile, users: [Env.inviteUserId], teams: [], emails: [], message: "Invitation test", permission: UserPermission.read.rawValue) { response, error in
                XCTAssertNil(error, "There should be no error")
                let user = response?.data?.valid.users?.first { $0.id == Env.inviteUserId }
                XCTAssertNotNil(user, "User shouldn't be nil")
                if let user = user {
                    self.currentApiFetcher.updateUserRights(file: rootFile, user: user, permission: UserPermission.manage.rawValue) { updateResponse, updateError in
                        XCTAssertNotNil(updateResponse, "Response shouldn't be nil")
                        XCTAssertNil(updateError, "There should be no error")

                        self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                            XCTAssertNotNil(shareResponse?.data, "Response shouldn't be nil")
                            XCTAssertNil(shareError, "There should be no error")
                            let share = shareResponse!.data!
                            let updatedUser = share.users.first {
                                $0.id == Env.inviteUserId
                            }
                            XCTAssertNotNil(updatedUser, "User shouldn't be nil")
                            XCTAssertTrue(updatedUser?.permission == .manage, "User permission should be equal to 'manage'")
                            expectation.fulfill()
                        }
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testDeleteUserRights() {
        let testName = "Delete user rights"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.addUserRights(file: rootFile, users: [Env.inviteUserId], teams: [], emails: [], message: "Invitation test", permission: UserPermission.read.rawValue) { response, error in
                XCTAssertNil(error, "There should be no error")
                let user = response?.data?.valid.users?.first { $0.id == Env.inviteUserId }
                XCTAssertNotNil(user, "User shouldn't be nil")
                if let user = user {
                    self.currentApiFetcher.deleteUserRights(file: rootFile, user: user) { deleteResponse, deleteError in
                        XCTAssertNotNil(deleteResponse, "Response shouldn't be nil")
                        XCTAssertNil(deleteError, "There should be no error")

                        self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                            XCTAssertNotNil(shareResponse?.data, "Response shouldn't be nil")
                            XCTAssertNil(shareError, "There should be no error")
                            let deletedUser = shareResponse!.data!.users.first {
                                $0.id == Env.inviteUserId
                            }
                            XCTAssertNil(deletedUser, "Deleted user should be nil")
                            expectation.fulfill()
                        }
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testUpdateInvitationRights() {
        let testName = "Update invitation rights"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.addUserRights(file: rootFile, users: [], teams: [], emails: [Env.inviteMail], message: "Invitation test", permission: UserPermission.read.rawValue) { response, error in
                XCTAssertNil(error, "There should be no error")
                let invitation = response?.data?.valid.invitations?.first { $0.email == Env.inviteMail }
                XCTAssertNotNil(invitation, "Invitation shouldn't be nil")
                self.currentApiFetcher.updateInvitationRights(driveId: self.currentDrive.id, invitation: invitation!, permission: UserPermission.write.rawValue) { updateResponse, updateError in
                    XCTAssertNotNil(updateResponse, "Response shouldn't be nil")
                    XCTAssertNil(updateError, "There should be no error")

                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, "Response shouldn't be nil")
                        XCTAssertNil(shareError, "There should be no error")
                        let share = shareResponse!.data!
                        XCTAssertNotNil(share.invitations, "Invitations shouldn't be nil")
                        let updatedInvitation = share.invitations.first {
                            $0!.email == Env.inviteMail
                        }!
                        XCTAssertNotNil(updatedInvitation, "Invitation shouldn't be nil")
                        XCTAssertTrue(updatedInvitation?.permission == .write, "Invitation permission should be equal to 'write'")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testDeleteInvitationRights() {
        let testName = "Delete invitation rights"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.addUserRights(file: rootFile, users: [], teams: [], emails: [Env.inviteMail], message: "Invitation test", permission: UserPermission.read.rawValue) { response, error in
                XCTAssertNil(error, "There should be no error")
                let invitation = response?.data?.valid.invitations?.first { $0.email == Env.inviteMail }
                XCTAssertNotNil(invitation, "User shouldn't be nil")
                self.currentApiFetcher.deleteInvitationRights(driveId: self.currentDrive.id, invitation: invitation!) { deleteResponse, deleteError in
                    XCTAssertNotNil(deleteResponse, "Response shouldn't be nil")
                    XCTAssertNil(deleteError, "There should be no error")

                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, "Response shouldn't be nil")
                        XCTAssertNil(shareError, "There should be no error")
                        let deletedInvitation = shareResponse?.data?.users.first { $0.id == Env.inviteUserId }
                        XCTAssertNil(deletedInvitation, "Deleted invitation should be nil")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testRemoveShareLinkFor() {
        let testName = "Remove share link"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.activateShareLinkFor(file: rootFile) { _, error in
                XCTAssertNil(error, "There should be no error")
                self.currentApiFetcher.removeShareLinkFor(file: rootFile) { removeResponse, removeError in
                    XCTAssertNotNil(removeResponse, "Response shouldn't be nil")
                    XCTAssertNil(removeError, "There should be no error")

                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, "Share file shouldn't be nil")
                        XCTAssertNil(shareError, "There should be no error")
                        XCTAssertNil(shareResponse?.data?.link, "Share link should be nil")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testGetFileDetail() {
        let testName = "Get file detail"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.getFileDetail(driveId: self.currentDrive.id, fileId: rootFile.id) { response, error in
                XCTAssertNotNil(response?.data, "File detail shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testGetFileDetailActivity() {
        let testName = "Get file detail activity"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.getFileDetailActivity(file: rootFile, page: 1) { response, error in
                XCTAssertNotNil(response, "Response shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testGetFileDetailComment() {
        let testName = "Get file detail comment"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.getFileDetailComment(file: rootFile, page: 1) { response, error in
                XCTAssertNotNil(response, "Response shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testAddCommentTo() {
        let testName = "Add comment"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.addCommentTo(file: file, comment: "Testing comment") { response, error in
                XCTAssertNotNil(response?.data, "Comment shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                let comment = response!.data!
                XCTAssertTrue(comment.body == "Testing comment", "Comment body should be equal to 'Testing comment'")

                self.currentApiFetcher.getFileDetailComment(file: file, page: 1) { commentResponse, commentError in
                    XCTAssertNotNil(commentResponse?.data, "Comments shouldn't be nil")
                    XCTAssertNil(commentError, "There should be no error")
                    let recievedComment = commentResponse!.data!.first {
                        $0.id == comment.id
                    }
                    XCTAssertNotNil(recievedComment, "Comment shouldn't be nil")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testLikeComment() {
        let testName = "Like comment"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.addCommentTo(file: file, comment: "Testing comment") { response, error in
                XCTAssertNotNil(response?.data, "Comment shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                let comment = response!.data!

                self.currentApiFetcher.likeComment(file: file, liked: false, comment: comment) { likeResponse, likeError in
                    XCTAssertNotNil(likeResponse?.data, "Like response shouldn't be nil")
                    XCTAssertNil(likeError, "There should be no error")

                    self.currentApiFetcher.getFileDetailComment(file: file, page: 1) { commentResponse, commentError in
                        XCTAssertNotNil(commentResponse?.data, "Comments shouldn't be nil")
                        XCTAssertNil(commentError, "There should be no error")
                        let recievedComment = commentResponse!.data!.first {
                            $0.id == comment.id
                        }
                        XCTAssertNotNil(recievedComment, "Comment shouldn't be nil")
                        XCTAssertTrue(recievedComment!.liked, "Comment should be liked")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testDeleteComment() {
        let testName = "Delete comment"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.addCommentTo(file: file, comment: "Testing comment") { response, error in
                XCTAssertNotNil(response?.data, "Comment shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                let comment = response!.data!

                self.currentApiFetcher.deleteComment(file: file, comment: response!.data!) { deleteResponse, deleteError in
                    XCTAssertNotNil(deleteResponse, "Comment response shouldn't be nil")
                    XCTAssertNil(deleteError, "There should be no error")

                    self.currentApiFetcher.getFileDetailComment(file: file, page: 1) { commentResponse, commentError in
                        XCTAssertNotNil(commentResponse, "Comments shouldn't be nil")
                        XCTAssertNil(commentError, "There should be no error")
                        let deletedComment = commentResponse!.data?.first {
                            $0.id == comment.id
                        }
                        XCTAssertNil(deletedComment, "Deleted comment should be nil")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testEditComment() {
        let testName = "Edit comment"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.addCommentTo(file: file, comment: "Testing comment") { response, error in
                XCTAssertNotNil(response?.data, "Comment shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                let comment = response!.data!

                self.currentApiFetcher.editComment(file: file, text: testName, comment: response!.data!) { editResponse, editError in
                    XCTAssertNotNil(editResponse, "Comment response shouldn't be nil")
                    XCTAssertNil(editError, "There should be no error")

                    self.currentApiFetcher.getFileDetailComment(file: file, page: 1) { commentResponse, commentError in
                        XCTAssertNotNil(commentResponse?.data, "Comments shouldn't be nil")
                        XCTAssertNil(commentError, "There should be no error")
                        let editedComment = commentResponse!.data?.first {
                            $0.id == comment.id
                        }
                        XCTAssertNotNil(editedComment, "Edited comment shouldn't be nil")
                        XCTAssertTrue(editedComment?.body == testName, "Edited comment body is wrong")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testAnswerComment() {
        let testName = "Answer comment"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.addCommentTo(file: file, comment: "Testing comment") { response, error in
                XCTAssertNotNil(response?.data, "Comment shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                let comment = response!.data!

                self.currentApiFetcher.answerComment(file: file, text: "Answer comment", comment: response!.data!) { answerResponse, answerError in
                    XCTAssertNotNil(answerResponse?.data, "Comment response shouldn't be nil")
                    XCTAssertNil(answerError, "There should be no error")
                    let answer = answerResponse!.data!

                    self.currentApiFetcher.getFileDetailComment(file: file, page: 1) { commentResponse, commentError in
                        XCTAssertNotNil(commentResponse, "Comments shouldn't be nil")
                        XCTAssertNil(commentError, "There should be no error")
                        let firstComment = commentResponse!.data?.first {
                            $0.id == comment.id
                        }
                        XCTAssertNotNil(firstComment, "Comment shouldn't be nil")
                        let firstAnswer = firstComment!.responses?.first {
                            $0.id == answer.id
                        }
                        XCTAssertNotNil(firstAnswer, "Answer shouldn't be nil")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testDeleteFile() {
        let testName = "Delete file"
        let expectations = [
            (name: "Delete file", expectation: XCTestExpectation(description: "Delete file")),
            (name: "Delete file definitely", expectation: XCTestExpectation(description: "Delete file definitely"))
        ]
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.createTestDirectory(name: testName, parentDirectory: rootFile) { directory in
                self.currentApiFetcher.deleteFile(file: directory) { response, error in
                    XCTAssertNotNil(response?.data, "Deleted file response shouldn't be nil")
                    XCTAssertNil(error, "There should be no error")

                    self.currentApiFetcher.getFileListForDirectory(driveId: self.currentDrive.id, parentId: rootFile.id) { rootResponse, rootError in
                        XCTAssertNotNil(rootResponse?.data, "Root file shouldn't be nil")
                        XCTAssertNil(rootError, "There should be no error")
                        let deletedFile = rootResponse?.data?.children.first {
                            $0.id == directory.id
                        }
                        XCTAssertNil(deletedFile, "Deleted file should be nil")

                        self.currentApiFetcher.getTrashedFiles(driveId: self.currentDrive.id, sortType: .newerDelete) { trashResponse, trashError in
                            XCTAssertNotNil(trashResponse, "Trashed files shouldn't be nil")
                            XCTAssertNil(trashError, "There should be no error")
                            let fileInTrash = trashResponse!.data!.first {
                                $0.id == directory.id
                            }
                            XCTAssertNotNil(fileInTrash, "Deleted file shouldn't be nil")
                            expectations[0].expectation.fulfill()
                            guard let file = fileInTrash else { return }
                            self.currentApiFetcher.deleteFileDefinitely(file: file) { definitelyResponse, definitelyError in
                                XCTAssertNotNil(definitelyResponse, "Response shouldn't be nil")
                                XCTAssertNil(definitelyError, "There should be no error")

                                self.currentApiFetcher.getTrashedFiles(driveId: self.currentDrive.id, sortType: .newerDelete) { finalResponse, finalError in
                                    XCTAssertNotNil(finalResponse, "Trashed files shouldn't be nil")
                                    XCTAssertNil(finalError, "There should be no error")
                                    let deletedFile = finalResponse?.data?.first {
                                        $0.id == file.id
                                    }
                                    XCTAssertNil(deletedFile, "Deleted file should be nil")
                                    expectations[1].expectation.fulfill()
                                }
                            }
                        }
                    }
                }
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testRenameFile() {
        let testName = "Rename file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.renameFile(file: file, newName: "renamed office file") { renameResponse, renameError in
                XCTAssertNotNil(renameResponse?.data, "Renamed file shouldn't be nil")
                XCTAssertNil(renameError, "There should be no error")
                XCTAssertTrue(renameResponse!.data!.name == "renamed office file", "File name should have changed")

                self.currentApiFetcher.getFileListForDirectory(driveId: self.currentDrive.id, parentId: file.id) { response, error in
                    XCTAssertNotNil(response?.data, "Renamed file shouldn't be nil")
                    XCTAssertNil(error, "There should be no error")
                    XCTAssertTrue(response!.data!.name == "renamed office file", "File name should have changed")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testDuplicateFile() {
        let testName = "Duplicate file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.duplicateFile(file: file, duplicateName: "duplicate-\(Date())") { duplicateResponse, duplicateError in
                XCTAssertNotNil(duplicateResponse?.data, "Duplicated file shouldn't be nil")
                XCTAssertNil(duplicateError, "There should be no error")

                self.currentApiFetcher.getFileListForDirectory(driveId: self.currentDrive.id, parentId: rootFile.id) { response, error in
                    XCTAssertNotNil(response?.data, "Response shouldn't be nil")
                    XCTAssertNil(error, "There should be no error")
                    XCTAssertTrue(response!.data!.children.count == 2, "Root file should have 2 children")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testMoveFile() {
        let testName = "Move file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.createTestDirectory(name: "destination-\(Date())", parentDirectory: rootFile) { destination in
                self.currentApiFetcher.moveFile(file: file, newParent: destination) { moveResponse, moveError in
                    XCTAssertNotNil(moveResponse, "Response shouldn't be nil")
                    XCTAssertNil(moveError, "There should be no error")

                    self.currentApiFetcher.getFileListForDirectory(driveId: self.currentDrive.id, parentId: destination.id) { response, error in
                        XCTAssertNotNil(response?.data, "Response shouldn't be nil")
                        XCTAssertNil(error, "There should be no error")
                        let movedFile = response!.data!.children.contains { $0.id == file.id }
                        XCTAssertTrue(movedFile, "File should be in destination")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testGetRecentActivity() {
        let testName = "Get recent activity"
        let expectation = XCTestExpectation(description: testName)

        currentApiFetcher.getRecentActivity(driveId: currentDrive.id) { response, error in
            XCTAssertNotNil(response?.data, "Response shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetFileActivitiesFromDate() {
        let testName = "Get file activity from date"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        let earlyDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())
        let time = Int(earlyDate!.timeIntervalSince1970)

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.getFileActivitiesFromDate(file: file, date: time, page: 1) { response, error in
                XCTAssertNotNil(response?.data, "Response shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testPostFavoriteFile() {
        let testName = "Post favorite file"
        let expectations = [
            (name: "Post favorite file", expectation: XCTestExpectation(description: "Post favorite file")),
            (name: "Delete favorite file", expectation: XCTestExpectation(description: "Delete favorite file"))
        ]
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.postFavoriteFile(file: file) { postResponse, postError in
                XCTAssertNotNil(postResponse, "Response shouldn't be nil")
                XCTAssertNil(postError, "There should be no error")

                self.currentApiFetcher.getFavoriteFiles(driveId: self.currentDrive.id, page: 1, sortType: .newer) { favoriteResponse, favoriteError in
                    XCTAssertNotNil(favoriteResponse?.data, "Favorite files shouldn't be nil")
                    XCTAssertNil(favoriteError, "There should be no error")
                    let favoriteFile = favoriteResponse!.data!.first { $0.id == file.id }
                    XCTAssertNotNil(favoriteFile, "File should be in Favorite files")
                    XCTAssertTrue(favoriteFile!.isFavorite, "File should be favorite")
                    expectations[0].expectation.fulfill()

                    self.currentApiFetcher.deleteFavoriteFile(file: file) { deleteResponse, deleteError in
                        XCTAssertNotNil(deleteResponse, "Response shouldn't be nil")
                        XCTAssertNil(deleteError, "There should be no error")

                        self.currentApiFetcher.getFavoriteFiles(driveId: self.currentDrive.id, page: 1, sortType: .newer) { response, error in
                            XCTAssertNotNil(response?.data, "Favorite files shouldn't be nil")
                            XCTAssertNil(error, "There should be no error")
                            let favoriteFile = response!.data!.contains { $0.id == file.id }
                            XCTAssertFalse(favoriteFile, "File shouldn't be in Favorite files")

                            self.currentApiFetcher.getFileListForDirectory(driveId: self.currentDrive.id, parentId: file.id) { finalResponse, finalError in
                                XCTAssertNotNil(finalResponse?.data, "File shouldn't be nil")
                                XCTAssertNil(finalError, "There should be no error")
                                XCTAssertFalse(finalResponse!.data!.isFavorite, "File shouldn't be favorite")
                                expectations[1].expectation.fulfill()
                            }
                        }
                    }
                }
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testPerformAuthenticatedRequest() {}

    func testGetPublicUploadTokenWithToken() {}

    func testGetTrashedFiles() {
        let testName = "Get trashed file"
        let expectation = XCTestExpectation(description: testName)

        currentApiFetcher.getTrashedFiles(driveId: currentDrive.id, sortType: .newerDelete) { response, error in
            XCTAssertNotNil(response, "Response shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetChildrenTrashedFiles() {
        let testName = "Get children trashed file"
        let expectation = XCTestExpectation(description: testName)

        initOfficeFile(testName: testName) { root, _ in
            self.currentApiFetcher.deleteFile(file: root) { response, error in
                XCTAssertNil(error, "There should be no error")
                self.currentApiFetcher.getChildrenTrashedFiles(driveId: self.currentDrive.id, fileId: root.id) { response, error in
                    XCTAssertNotNil(response?.data, "Children trashed file shouldn't be nil")
                    XCTAssertNil(error, "There should be no error")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testRestoreTrashedFile() {
        let testName = "Restore trashed file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.deleteFile(file: file) { _, deleteError in
                XCTAssertNil(deleteError, "There should be no error")
                self.currentApiFetcher.restoreTrashedFile(file: file) { restoreResponse, restoreError in
                    XCTAssertNotNil(restoreResponse, "Response shouldn't be nil")
                    XCTAssertNil(restoreError, "There should be no error")

                    self.currentApiFetcher.getFileListForDirectory(driveId: self.currentDrive.id, parentId: rootFile.id) { response, error in
                        XCTAssertNotNil(response?.data, "Root file shouldn't be nil")
                        XCTAssertNil(error, "There should be no error")
                        let restoreFile = response!.data!.children.contains { $0.id == file.id }
                        XCTAssertTrue(restoreFile, "Restored file should be in root file children")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testRestoreTrashedFileInFolder() {
        let testName = "Restore trashed file in folder"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.deleteFile(file: file) { _, deleteError in
                XCTAssertNil(deleteError, "There should be no error")

                self.createTestDirectory(name: "restore destination - \(Date())", parentDirectory: rootFile) { directory in

                    self.currentApiFetcher.restoreTrashedFile(file: file, in: directory.id) { restoreResponse, restoreError in
                        XCTAssertNotNil(restoreResponse, "Response shouldn't be nil")
                        XCTAssertNil(restoreError, "There should be no error")

                        self.currentApiFetcher.getFileListForDirectory(driveId: self.currentDrive.id, parentId: directory.id) { response, error in
                            XCTAssertNotNil(response?.data, "Root file shouldn't be nil")
                            XCTAssertNil(error, "There should be no error")
                            let restoreFile = response!.data!.children.contains { $0.id == file.id }
                            XCTAssertTrue(restoreFile, "Restored file should be in directory children")
                            expectation.fulfill()
                        }
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testSearchFiles() {
        let testName = "Search file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.searchFiles(driveId: self.currentDrive.id, query: "officeFile") { response, error in
                XCTAssertNotNil(response, "Response shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                let fileFound = response?.data?.first {
                    $0.id == file.id
                }
                XCTAssertNotNil(fileFound, "File created should be in response")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testRequireFileAccess() {}

    func testCancelAction() {}

    // MARK: - Complementary tests

    func testComment() {
        let testName = "Comment tests"
        let expectations = [
            (name: "Add comment", expectation: XCTestExpectation(description: "Add comment")),
            (name: "Like comment", expectation: XCTestExpectation(description: "Like comment")),
            (name: "Edit comment", expectation: XCTestExpectation(description: "Edit comment")),
            (name: "Answer comment", expectation: XCTestExpectation(description: "Answer comment")),
            (name: "All tests", expectation: XCTestExpectation(description: "All tests")),
            (name: "Delete comment", expectation: XCTestExpectation(description: "Delete comment"))
        ]
        var rootFile = File()
        var numberOfComment = 0

        initOfficeFile(testName: testName) { root, officeFile in
            rootFile = root
            self.currentApiFetcher.addCommentTo(file: officeFile, comment: expectations[0].name) { response, error in
                XCTAssertNotNil(response?.data, "Comment shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                let comment = response!.data!
                XCTAssertTrue(comment.body == expectations[0].name, "Comment body is wrong")
                expectations[0].expectation.fulfill()

                self.currentApiFetcher.likeComment(file: officeFile, liked: false, comment: comment) { responseLike, errorLike in
                    XCTAssertNotNil(responseLike, "Response like shouldn't be nil")
                    XCTAssertNil(errorLike, "There should be no error")
                    expectations[1].expectation.fulfill()

                    self.currentApiFetcher.editComment(file: officeFile, text: expectations[2].name, comment: comment) { responseEdit, errorEdit in
                        XCTAssertNotNil(responseEdit, "Response edit shouldn't be nil")
                        XCTAssertNil(errorEdit, "There should be no error")
                        XCTAssertTrue(responseEdit!.data!, "Response edit should be true")
                        expectations[2].expectation.fulfill()

                        self.currentApiFetcher.answerComment(file: officeFile, text: expectations[3].name, comment: comment) { responseAnswer, errorAnswer in
                            XCTAssertNotNil(responseAnswer, "Answer comment shouldn't be nil")
                            XCTAssertNil(errorAnswer, "There should be no error")
                            let answer = responseAnswer!.data!
                            XCTAssertTrue(answer.body == expectations[3].name, "Answer body is wrong")
                            expectations[3].expectation.fulfill()

                            self.currentApiFetcher.getFileDetailComment(file: officeFile, page: 1) { responseAllComment, errorAllComment in
                                XCTAssertNotNil(responseAllComment, "All comment file shouldn't be nil")
                                XCTAssertNil(errorAllComment, "There should be no error")
                                let allComment = responseAllComment!.data!
                                numberOfComment = allComment.count
                                expectations[4].expectation.fulfill()

                                self.currentApiFetcher.deleteComment(file: officeFile, comment: comment) { responseDelete, errorDelete in
                                    XCTAssertNotNil(responseDelete, "Response delete shouldn't be nil")
                                    XCTAssertNil(errorDelete, "There should be no error")
                                    XCTAssertTrue(responseDelete!.data!, "Response delete should be true")

                                    self.currentApiFetcher.getFileDetailComment(file: officeFile, page: 1) { finalResponse, finalError in
                                        XCTAssertNotNil(finalResponse, "All comment file shouldn't be nil")
                                        XCTAssertNil(finalError, "There should be no error")
                                        XCTAssertTrue(numberOfComment - 1 == finalResponse!.data!.count, "Comment not deleted")
                                        expectations[5].expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testShareLink() {
        let testName = "Share link"
        let expectations = [
            (name: "Activate share link", expectation: XCTestExpectation(description: "Activate share link")),
            (name: "Update share link", expectation: XCTestExpectation(description: "Update share link")),
            (name: "Remove share link", expectation: XCTestExpectation(description: "Remove share link"))
        ]
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            self.currentApiFetcher.activateShareLinkFor(file: rootFile) { activateResponse, activateError in
                XCTAssertNotNil(activateResponse?.data, "Share link shouldn't be nil")
                XCTAssertNil(activateError, "There should be no error")
                XCTAssertNotNil(activateResponse!.data!.url, "Share link url shouldn't be nil")
                expectations[0].expectation.fulfill()

                self.currentApiFetcher.updateShareLinkWith(file: rootFile, canEdit: true, permission: "password", password: "password", date: nil, blockDownloads: true, blockComments: false, blockInformation: false, isFree: false) { updateResponse, updateError in
                    XCTAssertNotNil(updateResponse, "Response shouldn't be nil")
                    XCTAssertNil(updateError, "There should be no error")
                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, "Share response shouldn't be nil")
                        XCTAssertNil(shareError, "There should be no error")
                        let share = shareResponse!.data!
                        XCTAssertNotNil(share.link, "Share link shouldn't be nil")
                        print(share.link!)
                        XCTAssertTrue(share.link!.canEdit, "canEdit should be true")
                        XCTAssertTrue(share.link!.permission == "password", "Permission should be equal to 'password'")
                        XCTAssertTrue(share.link!.blockDownloads, "blockDownloads should be true")
                        XCTAssertTrue(!share.link!.blockComments, "blockComments should be false")
                        XCTAssertTrue(!share.link!.blockInformation, "blockInformation should be false")
                        expectations[1].expectation.fulfill()

                        self.currentApiFetcher.removeShareLinkFor(file: rootFile) { removeResponse, removeError in
                            XCTAssertNotNil(removeResponse, "Response shouldn't be nil")
                            XCTAssertNil(removeError, "There should be no error")
                            self.currentApiFetcher.getShareListFor(file: rootFile) { finalResponse, finalError in
                                XCTAssertNotNil(finalResponse?.data, "Share file shouldn't be nil")
                                XCTAssertNil(finalError, "There should be no error")
                                XCTAssertNil(finalResponse?.data?.link, "Share link should be nil")
                                expectations[2].expectation.fulfill()
                            }
                        }
                    }
                }
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testUserRights() {
        let testName = "User rights"
        let expectations = [
            (name: "Check user rights", expectation: XCTestExpectation(description: "Check user rights")),
            (name: "Add user rights", expectation: XCTestExpectation(description: "Add user rights")),
            (name: "Update user rights", expectation: XCTestExpectation(description: "Update user rights")),
            (name: "Delete user rights", expectation: XCTestExpectation(description: "Delete user rights"))
        ]
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root

            self.currentApiFetcher.checkUserRights(file: rootFile, users: [Env.inviteUserId], teams: [], emails: [], permission: UserPermission.manage.rawValue) { checkResponse, checkError in
                XCTAssertNotNil(checkResponse, "Response shouldn't be nil")
                XCTAssertNil(checkError, "There should be no error")
                expectations[0].expectation.fulfill()

                self.currentApiFetcher.addUserRights(file: rootFile, users: [Env.inviteUserId], teams: [], emails: [], message: "Invitation test", permission: UserPermission.manage.rawValue) { addResponse, addError in
                    XCTAssertNotNil(addResponse?.data, "Response shouldn't be nil")
                    XCTAssertNil(addError, "There should be no error")
                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, "Response shouldn't be nil")
                        XCTAssertNil(shareError, "There should be no error")
                        let share = shareResponse!.data!
                        let userAdded = share.users.first { user -> Bool in
                            if user.id == Env.inviteUserId {
                                XCTAssertTrue(user.permission == .manage, "Added user permission should be equal to 'manage'")
                                return true
                            }
                            return false
                        }
                        XCTAssertNotNil(userAdded, "Added user should be in share list")
                        expectations[1].expectation.fulfill()
                        guard let user = userAdded else { return }
                        self.currentApiFetcher.updateUserRights(file: rootFile, user: user, permission: UserPermission.manage.rawValue) { updateResponse, updateError in
                            XCTAssertNotNil(updateResponse, "Response shouldn't be nil")
                            XCTAssertNil(updateError, "There should be no error")
                            self.currentApiFetcher.getShareListFor(file: rootFile) { shareUpdateResponse, shareUpdateError in
                                XCTAssertNotNil(shareUpdateResponse?.data, "Response shouldn't be nil")
                                XCTAssertNil(shareUpdateError, "There should be no error")
                                let share = shareUpdateResponse!.data!
                                let updatedUser = share.users.first {
                                    $0.id == Env.inviteUserId
                                }
                                XCTAssertNotNil(updatedUser, "User shouldn't be nil")
                                XCTAssertTrue(updatedUser?.permission == .manage, "User permission should be equal to 'manage'")
                                expectations[2].expectation.fulfill()

                                guard let user = updatedUser else { return }
                                self.currentApiFetcher.deleteUserRights(file: rootFile, user: user) { deleteResponse, deleteError in
                                    XCTAssertNotNil(deleteResponse, "Response shouldn't be nil")
                                    XCTAssertNil(deleteError, "There should be no error")
                                    self.currentApiFetcher.getShareListFor(file: rootFile) { finalResponse, finalError in
                                        XCTAssertNotNil(finalResponse?.data, "Response shouldn't be nil")
                                        XCTAssertNil(finalError, "There should be no error")
                                        let deletedUser = finalResponse!.data!.users.first {
                                            $0.id == Env.inviteUserId
                                        }
                                        XCTAssertNil(deletedUser, "Deleted user should be nil")
                                        expectations[3].expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testInvitationRights() {
        let testName = "Invitation rights"
        let expectations = [
            (name: "Check invitation rights", expectation: XCTestExpectation(description: "Check invitation rights")),
            (name: "Add invitation rights", expectation: XCTestExpectation(description: "Add invitation rights")),
            (name: "Update invitation rights", expectation: XCTestExpectation(description: "Update invitation rights")),
            (name: "Delete invitation rights", expectation: XCTestExpectation(description: "Delete invitation rights"))
        ]
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root

            self.currentApiFetcher.checkUserRights(file: rootFile, users: [], teams: [], emails: [Env.inviteMail], permission: UserPermission.read.rawValue) { checkResponse, checkError in
                XCTAssertNotNil(checkResponse, "Response shouldn't be nil")
                XCTAssertNil(checkError, "There should be no error")
                expectations[0].expectation.fulfill()

                self.currentApiFetcher.addUserRights(file: rootFile, users: [], teams: [], emails: [Env.inviteMail], message: "Invitation test", permission: UserPermission.read.rawValue) { addResponse, addError in
                    XCTAssertNil(addError, "There should be no error")
                    let invitation = addResponse?.data?.valid.invitations?.first { $0.email == Env.inviteMail }
                    XCTAssertNotNil(invitation, "Invitation shouldn't be nil")
                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, "Response shouldn't be nil")
                        XCTAssertNil(shareError, "There should be no error")
                        let share = shareResponse!.data!
                        let invitationAdded = share.invitations.first { invitation -> Bool in
                            if invitation?.email == Env.inviteMail {
                                XCTAssertTrue(invitation!.permission == .read, "Added invitation permission should be equal to 'read'")
                                return true
                            }
                            return false
                        }!
                        XCTAssertNotNil(invitationAdded, "Added invitation should be in share list")
                        expectations[1].expectation.fulfill()

                        self.currentApiFetcher.updateInvitationRights(driveId: self.currentDrive.id, invitation: invitation!, permission: UserPermission.write.rawValue) { updateResponse, updateError in
                            XCTAssertNotNil(updateResponse, "Response shouldn't be nil")
                            XCTAssertNil(updateError, "There should be no error")
                            self.currentApiFetcher.getShareListFor(file: rootFile) { shareUpdateResponse, shareUpdateError in
                                XCTAssertNotNil(shareUpdateResponse?.data, "Response shouldn't be nil")
                                XCTAssertNil(shareUpdateError, "There should be no error")
                                let share = shareUpdateResponse!.data!
                                XCTAssertNotNil(share.invitations, "Invitations shouldn't be nil")
                                let updatedInvitation = share.invitations.first {
                                    $0!.email == Env.inviteMail
                                }!
                                XCTAssertNotNil(updatedInvitation, "Invitation shouldn't be nil")
                                XCTAssertTrue(updatedInvitation?.permission == .write, "Invitation permission should be equal to 'write'")
                                expectations[2].expectation.fulfill()

                                self.currentApiFetcher.deleteInvitationRights(driveId: self.currentDrive.id, invitation: invitation!) { deleteResponse, deleteError in
                                    XCTAssertNotNil(deleteResponse, "Response shouldn't be nil")
                                    XCTAssertNil(deleteError, "There should be no error")
                                    self.currentApiFetcher.getShareListFor(file: rootFile) { finalResponse, finalError in
                                        XCTAssertNotNil(finalResponse?.data, "Response shouldn't be nil")
                                        XCTAssertNil(finalError, "There should be no error")
                                        let deletedInvitation = finalResponse!.data!.users.first {
                                            $0.id == Env.inviteUserId
                                        }
                                        XCTAssertNil(deletedInvitation, "Deleted invitation should be nil")
                                        expectations[3].expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testTeamRights() {
        let testName = "Team rights"
        let expectations = [
            (name: "Check teams rights", expectation: XCTestExpectation(description: "Check teams rights")),
            (name: "Add teams rights", expectation: XCTestExpectation(description: "Add teams rights")),
            (name: "Update teams rights", expectation: XCTestExpectation(description: "Update teams rights")),
            (name: "Delete teams rights", expectation: XCTestExpectation(description: "Delete teams rights"))
        ]
        var rootFile = File()

        currentApiFetcher.createCommonDirectory(driveId: currentDrive.id, name: "UnitTest - \(testName)", forAllUser: false) { response, _ in
            XCTAssertNotNil(rootFile, "Failed to create UnitTest directory")
            rootFile = response!.data!

            self.currentApiFetcher.checkUserRights(file: rootFile, users: [], teams: [Env.inviteTeam], emails: [], permission: UserPermission.read.rawValue) { checkResponse, checkError in
                XCTAssertNotNil(checkResponse, "Response shouldn't be nil")
                XCTAssertNil(checkError, "There should be no error")
                expectations[0].expectation.fulfill()

                self.currentApiFetcher.addUserRights(file: rootFile, users: [], teams: [Env.inviteTeam], emails: [], message: "Invitation test", permission: UserPermission.read.rawValue) { addResponse, addError in
                    XCTAssertNotNil(addResponse?.data, "Response shouldn't be nil")
                    XCTAssertNil(addError, "There should be no error")
                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, "Response shouldn't be nil")
                        XCTAssertNil(shareError, "There should be no error")
                        let share = shareResponse?.data
                        let teamAdded = share?.teams.first { $0.id == Env.inviteTeam }
                        XCTAssertNotNil(teamAdded, "Added team should be in share list")
                        XCTAssertTrue(teamAdded?.right == .read, "Added team permission should be equal to 'read'")
                        expectations[1].expectation.fulfill()
                        guard let team = teamAdded else { return }
                        self.currentApiFetcher.updateTeamRights(file: rootFile, team: team, permission: UserPermission.write.rawValue) { updateResponse, updateError in
                            XCTAssertNotNil(updateResponse, "Response shouldn't be nil")
                            XCTAssertNil(updateError, "There should be no error")
                            self.currentApiFetcher.getShareListFor(file: rootFile) { shareUpdateResponse, shareUpdateError in
                                XCTAssertNotNil(shareUpdateResponse?.data, "Response shouldn't be nil")
                                XCTAssertNil(shareUpdateError, "There should be no error")
                                let share = shareUpdateResponse?.data
                                XCTAssertNotNil(share?.teams, "Teams shouldn't be nil")
                                let updatedTeam = share?.teams.first { $0.id == Env.inviteTeam }
                                XCTAssertNotNil(updatedTeam, "Team shouldn't be nil")
                                XCTAssertTrue(updatedTeam?.right == .write, "Team permission should be equal to 'write'")
                                expectations[2].expectation.fulfill()
                                guard let team = updatedTeam else { return }
                                self.currentApiFetcher.deleteTeamRights(file: rootFile, team: team) { deleteResponse, deleteError in
                                    XCTAssertNotNil(deleteResponse, "Response shouldn't be nil")
                                    XCTAssertNil(deleteError, "There should be no error")
                                    self.currentApiFetcher.getShareListFor(file: rootFile) { finalResponse, finalError in
                                        XCTAssertNotNil(finalResponse?.data, "Response shouldn't be nil")
                                        XCTAssertNil(finalError, "There should be no error")
                                        let deletedTeam = finalResponse?.data?.teams.first { $0.id == Env.inviteTeam }
                                        XCTAssertNil(deletedTeam, "Deleted team should be nil")
                                        expectations[3].expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }
}
