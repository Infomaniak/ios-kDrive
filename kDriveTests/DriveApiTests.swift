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

    var currentApiFetcher: DriveApiFetcher = {
        let token = ApiToken(accessToken: Env.token,
                             expiresIn: Int.max,
                             refreshToken: "",
                             scope: "",
                             tokenType: "",
                             userId: Env.userId,
                             expirationDate: Date(timeIntervalSinceNow: TimeInterval(Int.max)))
        return DriveApiFetcher(token: token, delegate: FakeTokenDelegate())
    }()

    // MARK: - Tests setup

    func setUpTest(testName: String, completion: @escaping (File) -> Void) {
        getRootDirectory { rootFile in
            self.createTestDirectory(name: "UnitTest - \(testName)", parentDirectory: rootFile) { file in
                XCTAssertNotNil(file, TestsMessages.failedToCreate("UnitTest directory"))
                completion(file)
            }
        }
    }

    func setUpTest(testName: String) async -> File {
        await withCheckedContinuation { continuation in
            setUpTest(testName: testName) { file in
                continuation.resume(returning: file)
            }
        }
    }

    func tearDownTest(directory: File) {
        currentApiFetcher.deleteFile(file: directory) { response, _ in
            XCTAssertNotNil(response, TestsMessages.failedToDelete("directory"))
        }
    }

    // MARK: - Helping methods

    func getRootDirectory(completion: @escaping (File) -> Void) {
        currentApiFetcher.getFileListForDirectory(driveId: Env.driveId, parentId: DriveFileManager.constants.rootID) { response, _ in
            XCTAssertNotNil(response?.data, "Failed to get root directory")
            completion(response!.data!)
        }
    }

    func createTestDirectory(name: String, parentDirectory: File, completion: @escaping (File) -> Void) {
        currentApiFetcher.createDirectory(parentDirectory: parentDirectory, name: "\(name) - \(Date())", onlyForMe: true) { response, error in
            XCTAssertNotNil(response?.data, TestsMessages.failedToCreate("test directory"))
            XCTAssertNil(error, TestsMessages.noError)
            completion(response!.data!)
        }
    }

    func createTestDirectory(name: String, parentDirectory: File) async -> File {
        return await withCheckedContinuation { continuation in
            createTestDirectory(name: name, parentDirectory: parentDirectory) { result in
                continuation.resume(returning: result)
            }
        }
    }

    func initDropbox(testName: String, completion: @escaping (File, File) -> Void) {
        setUpTest(testName: testName) { rootFile in
            self.createTestDirectory(name: "dropbox-\(Date())", parentDirectory: rootFile) { dir in
                self.currentApiFetcher.setupDropBox(directory: dir, password: "", validUntil: nil, emailWhenFinished: false, limitFileSize: nil) { response, _ in
                    XCTAssertNotNil(response?.data, TestsMessages.failedToCreate("dropbox"))
                    completion(rootFile, dir)
                }
            }
        }
    }

    func initOfficeFile(testName: String, completion: @escaping (File, File) -> Void) {
        setUpTest(testName: testName) { rootFile in
            self.currentApiFetcher.createOfficeFile(driveId: Env.driveId, parentDirectory: rootFile, name: "officeFile-\(Date())", type: "docx") { response, _ in
                XCTAssertNotNil(response?.data, TestsMessages.failedToCreate("office file"))
                completion(rootFile, response!.data!)
            }
        }
    }

    func initOfficeFile(testName: String) async -> (File, File) {
        return await withCheckedContinuation { continuation in
            initOfficeFile(testName: testName) { result1, result2 in
                continuation.resume(returning: (result1, result2))
            }
        }
    }

    func checkIfFileIsInDestination(file: File, directory: File, completion: @escaping () -> Void) {
        currentApiFetcher.getFileListForDirectory(driveId: file.driveId, parentId: directory.id) { fileListResponse, fileListError in
            XCTAssertNil(fileListError, TestsMessages.noError)
            XCTAssertNotNil(fileListResponse?.data, TestsMessages.notNil("cancel response"))
            let movedFile = fileListResponse!.data!.children.contains { $0.id == file.id }
            XCTAssertTrue(movedFile, "File should be in destination")

            completion()
        }
    }

    func checkIfFileIsInDestination(file: File, directory: File) async {
        return await withCheckedContinuation { continuation in
            checkIfFileIsInDestination(file: file, directory: directory) {
                continuation.resume(returning: ())
            }
        }
    }

    // MARK: - Test methods

    func testGetRootFile() {
        let expectation = XCTestExpectation(description: "Get root file")

        currentApiFetcher.getFileListForDirectory(driveId: Env.driveId, parentId: DriveFileManager.constants.rootID) { response, error in
            XCTAssertNotNil(response?.data, TestsMessages.notNil("root file"))
            XCTAssertNil(error, TestsMessages.noError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetCommonDocuments() {
        let expectation = XCTestExpectation(description: "Get 'Common documents' file")

        currentApiFetcher.getFileListForDirectory(driveId: Env.driveId, parentId: Env.commonDocumentsId) { response, error in
            XCTAssertNotNil(response?.data, TestsMessages.notNil("root file"))
            XCTAssertNil(error, TestsMessages.noError)
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
                XCTAssertNotNil(response?.data, TestsMessages.notNil("created file"))
                XCTAssertNil(error, TestsMessages.noError)
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

        currentApiFetcher.createCommonDirectory(driveId: Env.driveId, name: "\(testName)-\(Date())", forAllUser: true) { response, error in
            XCTAssertNotNil(response?.data, TestsMessages.notNil("created common directory"))
            rootFile = response!.data!
            XCTAssertNil(error, TestsMessages.noError)
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
            self.currentApiFetcher.createOfficeFile(driveId: Env.driveId, parentDirectory: rootFile, name: "\(testName)-\(Date())", type: "docx") { response, error in
                XCTAssertNotNil(response?.data, TestsMessages.notNil("created office file"))
                XCTAssertNil(error, TestsMessages.noError)
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
                    XCTAssertNotNil(response?.data, TestsMessages.notNil("dropbox"))
                    XCTAssertNil(error, TestsMessages.noError)
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
        let limitFileSize: Int? = 5_368_709_120

        initDropbox(testName: testName) { root, dropbox in
            rootFile = root

            self.currentApiFetcher.updateDropBox(directory: dropbox, password: password, validUntil: validUntil, emailWhenFinished: false, limitFileSize: limitFileSize) { _, error in
                XCTAssertNil(error, TestsMessages.noError)
                self.currentApiFetcher.getDropBoxSettings(directory: dropbox) { dropboxSetting, error in
                    XCTAssertNotNil(dropboxSetting?.data, TestsMessages.notNil("dropbox"))
                    XCTAssertNil(error, TestsMessages.noError)
                    expectations[0].expectation.fulfill()

                    let dropbox = dropboxSetting!.data!
                    XCTAssertTrue(dropbox.password, "Password should be true")
                    XCTAssertNotNil(dropbox.validUntil, TestsMessages.notNil("ValidUntil"))
                    XCTAssertNotNil(dropbox.limitFileSize, TestsMessages.notNil("LimitFileSize"))
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
                XCTAssertNotNil(response?.data, TestsMessages.notNil("dropbox"))
                XCTAssertNil(error, TestsMessages.noError)
                self.currentApiFetcher.disableDropBox(directory: dropbox) { _, disableError in
                    XCTAssertNil(disableError, TestsMessages.noError)
                    self.currentApiFetcher.getDropBoxSettings(directory: dropbox) { invalidDropbox, invalidError in
                        XCTAssertNil(invalidDropbox?.data, "There should be no dropbox")
                        XCTAssertNil(invalidError, TestsMessages.noError)
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

        currentApiFetcher.getFavoriteFiles(driveId: Env.driveId) { response, error in
            XCTAssertNotNil(response?.data, TestsMessages.notNil("favorite files"))
            XCTAssertNil(error, TestsMessages.noError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetMyShared() {
        let testName = "Get my shared files"
        let expectation = XCTestExpectation(description: testName)

        currentApiFetcher.getMyShared(driveId: Env.driveId) { response, error in
            XCTAssertNotNil(response?.data, TestsMessages.notNil("My shared"))
            XCTAssertNil(error, TestsMessages.noError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetLastModifiedFiles() {
        let testName = "Get last modified files"
        let expectation = XCTestExpectation(description: testName)

        currentApiFetcher.getLastModifiedFiles(driveId: Env.driveId) { response, error in
            XCTAssertNotNil(response?.data, TestsMessages.notNil("last modified files"))
            XCTAssertNil(error, TestsMessages.noError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetLastPictures() {
        let testName = "Get last pictures"
        let expectation = XCTestExpectation(description: testName)

        currentApiFetcher.getLastPictures(driveId: Env.driveId) { response, error in
            XCTAssertNotNil(response?.data, TestsMessages.notNil("last pictures"))
            XCTAssertNil(error, TestsMessages.noError)
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
                XCTAssertNotNil(response?.data, TestsMessages.notNil("share list"))
                XCTAssertNil(error, TestsMessages.noError)
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
                XCTAssertNotNil(response?.data, TestsMessages.notNil("share link"))
                XCTAssertNil(error, TestsMessages.noError)

                self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                    XCTAssertNotNil(shareResponse, TestsMessages.notNil("share response"))
                    XCTAssertNil(shareError, TestsMessages.noError)
                    let share = shareResponse!.data!
                    XCTAssertNotNil(share.link?.url, TestsMessages.notNil("share link url"))
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
                self.currentApiFetcher.updateShareLinkWith(file: rootFile, canEdit: true, permission: ShareLinkPermission.password.rawValue, password: "password", date: nil, blockDownloads: true, blockComments: false, isFree: false) { updateResponse, updateError in
                    XCTAssertNotNil(updateResponse, TestsMessages.notNil("reponse"))
                    XCTAssertNil(updateError, TestsMessages.noError)

                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("share response"))
                        XCTAssertNil(shareError, TestsMessages.noError)
                        let share = shareResponse!.data!
                        XCTAssertNotNil(share.link, TestsMessages.notNil("share link"))
                        XCTAssertTrue(share.link!.canEdit, TestsMessages.notNil("canEdit"))
                        XCTAssertTrue(share.link!.permission == ShareLinkPermission.password.rawValue, "Permission should be equal to 'password'")
                        XCTAssertTrue(share.link!.blockDownloads, "blockDownloads should be true")
                        XCTAssertTrue(!share.link!.blockComments, "blockComments should be false")

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
                XCTAssertNotNil(response?.data, TestsMessages.notNil("reponse"))
                XCTAssertNil(error, TestsMessages.noError)

                self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                    XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("response"))
                    XCTAssertNil(shareError, TestsMessages.noError)
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
                XCTAssertNotNil(response, TestsMessages.notNil("response"))
                XCTAssertNil(error, TestsMessages.noError)
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
                XCTAssertNil(error, TestsMessages.noError)
                let user = response?.data?.valid.users?.first { $0.id == Env.inviteUserId }
                XCTAssertNotNil(user, TestsMessages.notNil("user"))
                if let user = user {
                    self.currentApiFetcher.updateUserRights(file: rootFile, user: user, permission: UserPermission.manage.rawValue) { updateResponse, updateError in
                        XCTAssertNotNil(updateResponse, TestsMessages.notNil("response"))
                        XCTAssertNil(updateError, TestsMessages.noError)

                        self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                            XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("response"))
                            XCTAssertNil(shareError, TestsMessages.noError)
                            let share = shareResponse!.data!
                            let updatedUser = share.users.first {
                                $0.id == Env.inviteUserId
                            }
                            XCTAssertNotNil(updatedUser, TestsMessages.notNil("user"))
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
                XCTAssertNil(error, TestsMessages.noError)
                let user = response?.data?.valid.users?.first { $0.id == Env.inviteUserId }
                XCTAssertNotNil(user, TestsMessages.notNil("user"))
                if let user = user {
                    self.currentApiFetcher.deleteUserRights(file: rootFile, user: user) { deleteResponse, deleteError in
                        XCTAssertNotNil(deleteResponse, TestsMessages.notNil("response"))
                        XCTAssertNil(deleteError, TestsMessages.noError)

                        self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                            XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("response"))
                            XCTAssertNil(shareError, TestsMessages.noError)
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
                XCTAssertNil(error, TestsMessages.noError)
                let invitation = response?.data?.valid.invitations?.first { $0.email == Env.inviteMail }
                XCTAssertNotNil(invitation, TestsMessages.notNil("invitation"))
                guard let invitation = invitation else { return }
                self.currentApiFetcher.updateInvitationRights(driveId: Env.driveId, invitation: invitation, permission: UserPermission.write.rawValue) { updateResponse, updateError in
                    XCTAssertNotNil(updateResponse, TestsMessages.notNil("response"))
                    XCTAssertNil(updateError, TestsMessages.noError)

                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("response"))
                        XCTAssertNil(shareError, TestsMessages.noError)
                        let share = shareResponse!.data!
                        XCTAssertNotNil(share.invitations, TestsMessages.notNil("invitations"))
                        let updatedInvitation = share.invitations.first {
                            $0!.email == Env.inviteMail
                        }!
                        XCTAssertNotNil(updatedInvitation, TestsMessages.notNil("invitation"))
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
                XCTAssertNil(error, TestsMessages.noError)
                let invitation = response?.data?.valid.invitations?.first { $0.email == Env.inviteMail }
                XCTAssertNotNil(invitation, TestsMessages.notNil("user"))
                guard let invitation = invitation else { return }
                self.currentApiFetcher.deleteInvitationRights(driveId: Env.driveId, invitation: invitation) { deleteResponse, deleteError in
                    XCTAssertNotNil(deleteResponse, TestsMessages.notNil("response"))
                    XCTAssertNil(deleteError, TestsMessages.noError)

                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("response"))
                        XCTAssertNil(shareError, TestsMessages.noError)
                        let deletedInvitation = shareResponse?.data?.users.first { $0.id == Env.inviteUserId }
                        XCTAssertNil(deletedInvitation, TestsMessages.notNil("deleted invitation"))
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
                XCTAssertNil(error, TestsMessages.noError)
                self.currentApiFetcher.removeShareLinkFor(file: rootFile) { removeResponse, removeError in
                    XCTAssertNotNil(removeResponse, TestsMessages.notNil("response"))
                    XCTAssertNil(removeError, TestsMessages.noError)

                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("share file"))
                        XCTAssertNil(shareError, TestsMessages.noError)
                        XCTAssertNil(shareResponse?.data?.link, TestsMessages.notNil("share link"))
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
            self.currentApiFetcher.getFileDetail(driveId: Env.driveId, fileId: rootFile.id) { response, error in
                XCTAssertNotNil(response?.data, TestsMessages.notNil("file detail"))
                XCTAssertNil(error, TestsMessages.noError)
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
                XCTAssertNotNil(response, TestsMessages.notNil("response"))
                XCTAssertNil(error, TestsMessages.noError)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testGetComments() async throws {
        let rootFile = await setUpTest(testName: "Get comments")
        _ = try await currentApiFetcher.comments(file: rootFile, page: 1)
        tearDownTest(directory: rootFile)
    }

    func testAddComment() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Add comment")
        let comment = try await currentApiFetcher.addComment(to: file, body: "Testing comment")
        XCTAssertEqual(comment.body, "Testing comment", "Comment body should be equal to 'Testing comment'")
        let comments = try await currentApiFetcher.comments(file: file, page: 1)
        XCTAssertNotNil(comments.first { $0.id == comment.id }, "Comment should exist")
        tearDownTest(directory: rootFile)
    }

    func testLikeComment() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Like comment")
        let comment = try await currentApiFetcher.addComment(to: file, body: "Testing comment")
        let response = try await currentApiFetcher.likeComment(file: file, liked: false, comment: comment)
        XCTAssertTrue(response, "API should return true")
        let comments = try await currentApiFetcher.comments(file: file, page: 1)
        guard let fetchedComment = comments.first(where: { $0.id == comment.id }) else {
            XCTFail("Comment should exist")
            tearDownTest(directory: rootFile)
            return
        }
        XCTAssertTrue(fetchedComment.liked, "Comment should be liked")
        tearDownTest(directory: rootFile)
    }

    func testDeleteComment() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Delete comment")
        let comment = try await currentApiFetcher.addComment(to: file, body: "Testing comment")
        let response = try await currentApiFetcher.deleteComment(file: file, comment: comment)
        XCTAssertTrue(response, "API should return true")
        let comments = try await currentApiFetcher.comments(file: file, page: 1)
        XCTAssertNil(comments.first { $0.id == comment.id }, "Comment should be deleted")
        tearDownTest(directory: rootFile)
    }

    func testEditComment() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Edit comment")
        let comment = try await currentApiFetcher.addComment(to: file, body: "Testing comment")
        let editedBody = "Edited comment"
        let response = try await currentApiFetcher.editComment(file: file, body: editedBody, comment: comment)
        XCTAssertTrue(response, "API should return true")
        let comments = try await currentApiFetcher.comments(file: file, page: 1)
        guard let editedComment = comments.first(where: { $0.id == comment.id }) else {
            XCTFail("Edited comment should exist")
            tearDownTest(directory: rootFile)
            return
        }
        XCTAssertEqual(editedComment.body, editedBody, "Edited comment body is wrong")
        tearDownTest(directory: rootFile)
    }

    func testAnswerComment() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Answer comment")
        let comment = try await currentApiFetcher.addComment(to: file, body: "Testing comment")
        let answer = try await currentApiFetcher.answerComment(file: file, body: "Answer comment", comment: comment)
        let comments = try await currentApiFetcher.comments(file: file, page: 1)
        guard let fetchedComment = comments.first(where: { $0.id == comment.id }) else {
            XCTFail("Comment should exist")
            tearDownTest(directory: rootFile)
            return
        }
        XCTAssertNotNil(fetchedComment.responses?.first { $0.id == answer.id }, "Answer should exist")
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
                    XCTAssertNotNil(response?.data, TestsMessages.notNil("deleted file response"))
                    XCTAssertNil(error, TestsMessages.noError)

                    self.currentApiFetcher.getFileListForDirectory(driveId: Env.driveId, parentId: rootFile.id) { rootResponse, rootError in
                        XCTAssertNotNil(rootResponse?.data, TestsMessages.notNil("root file"))
                        XCTAssertNil(rootError, TestsMessages.noError)
                        let deletedFile = rootResponse?.data?.children.first {
                            $0.id == directory.id
                        }
                        XCTAssertNil(deletedFile, TestsMessages.notNil("deleted file"))

                        self.currentApiFetcher.getTrashedFiles(driveId: Env.driveId, sortType: .newerDelete) { trashResponse, trashError in
                            XCTAssertNotNil(trashResponse, TestsMessages.notNil("trashed files"))
                            XCTAssertNil(trashError, TestsMessages.noError)
                            let fileInTrash = trashResponse!.data!.first {
                                $0.id == directory.id
                            }
                            XCTAssertNotNil(fileInTrash, TestsMessages.notNil("deleted file"))
                            expectations[0].expectation.fulfill()
                            guard let file = fileInTrash else { return }
                            self.currentApiFetcher.deleteFileDefinitely(file: file) { definitelyResponse, definitelyError in
                                XCTAssertNotNil(definitelyResponse, TestsMessages.notNil("response"))
                                XCTAssertNil(definitelyError, TestsMessages.noError)

                                self.currentApiFetcher.getTrashedFiles(driveId: Env.driveId, sortType: .newerDelete) { finalResponse, finalError in
                                    XCTAssertNotNil(finalResponse, TestsMessages.notNil("trashed files"))
                                    XCTAssertNil(finalError, TestsMessages.noError)
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
            let newName = "renamed office file"
            self.currentApiFetcher.renameFile(file: file, newName: newName) { renameResponse, renameError in
                XCTAssertNotNil(renameResponse?.data, TestsMessages.notNil("renamed file"))
                XCTAssertNil(renameError, TestsMessages.noError)
                XCTAssertTrue(renameResponse!.data!.name == newName, "File name should have changed")

                self.checkIfFileIsInDestination(file: renameResponse!.data!, directory: rootFile) {
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
                XCTAssertNotNil(duplicateResponse?.data, TestsMessages.notNil("duplicated file"))
                XCTAssertNil(duplicateError, TestsMessages.noError)

                self.currentApiFetcher.getFileListForDirectory(driveId: Env.driveId, parentId: rootFile.id) { response, error in
                    XCTAssertNotNil(response?.data, TestsMessages.notNil("response"))
                    XCTAssertNil(error, TestsMessages.noError)
                    XCTAssertTrue(response!.data!.children.count == 2, "Root file should have 2 children")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testCopyFile() {
        let testName = "Copy file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root
            self.currentApiFetcher.copyFile(file: file, newParent: rootFile) { copyResponse, copyError in
                XCTAssertNotNil(copyResponse, TestsMessages.notNil("response"))
                XCTAssertNil(copyError, TestsMessages.noError)
                self.checkIfFileIsInDestination(file: copyResponse!.data!, directory: rootFile) {
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
                    XCTAssertNotNil(moveResponse, TestsMessages.notNil("response"))
                    XCTAssertNil(moveError, TestsMessages.noError)
                    self.checkIfFileIsInDestination(file: file, directory: destination) {
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

        currentApiFetcher.getRecentActivity(driveId: Env.driveId) { response, error in
            XCTAssertNotNil(response?.data, TestsMessages.notNil("response"))
            XCTAssertNil(error, TestsMessages.noError)
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
                XCTAssertNotNil(response?.data, TestsMessages.notNil("response"))
                XCTAssertNil(error, TestsMessages.noError)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testGetFilesActivities() {
        let testName = "Get files activities"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, file in
            rootFile = root

            self.currentApiFetcher.createOfficeFile(driveId: Env.driveId, parentDirectory: rootFile, name: "\(testName)-\(Date())", type: "docx") { officeFileResponse, officeFileError in
                XCTAssertNil(officeFileError, TestsMessages.noError)
                XCTAssertNotNil(officeFileResponse, TestsMessages.notNil("office response"))

                let secondFile = officeFileResponse!.data!
                self.currentApiFetcher.getFilesActivities(driveId: Env.driveId, files: [file, secondFile], from: rootFile.id) { filesActivitiesResponse, filesActivitiesError in
                    XCTAssertNil(filesActivitiesError, TestsMessages.noError)
                    XCTAssertNotNil(filesActivitiesResponse?.data, TestsMessages.notNil("files activities response"))
                    print(filesActivitiesResponse!.data!.activities)

                    let activities = filesActivitiesResponse!.data!.activities
                    XCTAssertEqual(activities.count, 2, "Array should contain two activities")
                    for activity in activities {
                        XCTAssertNotNil(activity, TestsMessages.notNil("file activity"))
                    }
                    expectation.fulfill()
                }
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
                XCTAssertNotNil(postResponse, TestsMessages.notNil("response"))
                XCTAssertNil(postError, TestsMessages.noError)

                self.currentApiFetcher.getFavoriteFiles(driveId: Env.driveId, page: 1, sortType: .newer) { favoriteResponse, favoriteError in
                    XCTAssertNotNil(favoriteResponse?.data, TestsMessages.notNil("favorite files"))
                    XCTAssertNil(favoriteError, TestsMessages.noError)
                    let favoriteFile = favoriteResponse!.data!.first { $0.id == file.id }
                    XCTAssertNotNil(favoriteFile, "File should be in Favorite files")
                    XCTAssertTrue(favoriteFile!.isFavorite, "File should be favorite")
                    expectations[0].expectation.fulfill()

                    self.currentApiFetcher.deleteFavoriteFile(file: file) { deleteResponse, deleteError in
                        XCTAssertNotNil(deleteResponse, TestsMessages.notNil("response"))
                        XCTAssertNil(deleteError, TestsMessages.noError)

                        self.currentApiFetcher.getFavoriteFiles(driveId: Env.driveId, page: 1, sortType: .newer) { response, error in
                            XCTAssertNotNil(response?.data, TestsMessages.notNil("favorite files"))
                            XCTAssertNil(error, TestsMessages.noError)
                            let favoriteFile = response!.data!.contains { $0.id == file.id }
                            XCTAssertFalse(favoriteFile, "File shouldn't be in Favorite files")

                            self.currentApiFetcher.getFileListForDirectory(driveId: Env.driveId, parentId: file.id) { finalResponse, finalError in
                                XCTAssertNotNil(finalResponse?.data, TestsMessages.notNil("file"))
                                XCTAssertNil(finalError, TestsMessages.noError)
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

    func testPerformAuthenticatedRequest() {
        let testName = "Perform authenticated request"
        let expectation = XCTestExpectation(description: testName)

        let token = currentApiFetcher.currentToken!
        currentApiFetcher.performAuthenticatedRequest(token: token) { apiToken, error in
            XCTAssertNil(error, TestsMessages.noError)
            XCTAssertNotNil(apiToken, TestsMessages.notNil("API Token"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetPublicUploadTokenWithToken() {
        let testName = "Get public upload token with token"
        let expectation = XCTestExpectation(description: testName)

        let token = currentApiFetcher.currentToken!
        currentApiFetcher.getPublicUploadTokenWithToken(token, driveId: Env.driveId) { apiResponse, error in
            XCTAssertNil(error, TestsMessages.noError)
            XCTAssertNotNil(apiResponse?.data, TestsMessages.notNil("API Response"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetTrashedFiles() {
        let testName = "Get trashed file"
        let expectation = XCTestExpectation(description: testName)

        currentApiFetcher.getTrashedFiles(driveId: Env.driveId, sortType: .newerDelete) { response, error in
            XCTAssertNotNil(response, TestsMessages.notNil("response"))
            XCTAssertNil(error, TestsMessages.noError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetChildrenTrashedFiles() {
        let testName = "Get children trashed file"
        let expectation = XCTestExpectation(description: testName)

        initOfficeFile(testName: testName) { root, _ in
            self.currentApiFetcher.deleteFile(file: root) { response, error in
                XCTAssertNil(error, TestsMessages.noError)
                self.currentApiFetcher.getChildrenTrashedFiles(driveId: Env.driveId, fileId: root.id) { response, error in
                    XCTAssertNotNil(response?.data, TestsMessages.notNil("children trashed file"))
                    XCTAssertNil(error, TestsMessages.noError)
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
                XCTAssertNil(deleteError, TestsMessages.noError)
                self.currentApiFetcher.restoreTrashedFile(file: file) { restoreResponse, restoreError in
                    XCTAssertNotNil(restoreResponse, TestsMessages.notNil("response"))
                    XCTAssertNil(restoreError, TestsMessages.noError)

                    self.checkIfFileIsInDestination(file: file, directory: rootFile) {
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
                XCTAssertNil(deleteError, TestsMessages.noError)

                self.createTestDirectory(name: "restore destination - \(Date())", parentDirectory: rootFile) { directory in

                    self.currentApiFetcher.restoreTrashedFile(file: file, in: directory.id) { restoreResponse, restoreError in
                        XCTAssertNotNil(restoreResponse, TestsMessages.notNil("response"))
                        XCTAssertNil(restoreError, TestsMessages.noError)

                        self.checkIfFileIsInDestination(file: file, directory: directory) {
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
            self.currentApiFetcher.searchFiles(driveId: Env.driveId, query: "officeFile", categories: [], belongToAllCategories: true) { response, error in
                XCTAssertNotNil(response, TestsMessages.notNil("response"))
                XCTAssertNil(error, TestsMessages.noError)
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

    func testUndoAction() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Undo action")
        let directory = await createTestDirectory(name: "test", parentDirectory: rootFile)
        // Move & cancel
        let moveResponse: CancelableResponse = try await withCheckedThrowingContinuation { continuation in
            currentApiFetcher.moveFile(file: file, newParent: directory) { response, error in
                if let response = response?.data {
                    continuation.resume(returning: response)
                } else if let error = response?.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
        try await currentApiFetcher.undoAction(drive: ProxyDrive(id: Env.driveId), cancelId: moveResponse.id)
        await checkIfFileIsInDestination(file: file, directory: rootFile)
        // Delete & cancel
        let deleteResponse: CancelableResponse = try await withCheckedThrowingContinuation { continuation in
            currentApiFetcher.deleteFile(file: file) { response, error in
                if let response = response?.data {
                    continuation.resume(returning: response)
                } else if let error = response?.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
        try await currentApiFetcher.undoAction(drive: ProxyDrive(id: Env.driveId), cancelId: deleteResponse.id)
        await checkIfFileIsInDestination(file: file, directory: rootFile)
        tearDownTest(directory: rootFile)
    }

    func testGetFileCount() {
        let testName = "Get file count"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, _ in
            rootFile = root
            self.currentApiFetcher.createOfficeFile(driveId: Env.driveId, parentDirectory: rootFile, name: "secondFile-\(Date())", type: "docx") { secondFileResponse, secondFileError in
                XCTAssertNil(secondFileError, TestsMessages.noError)
                XCTAssertNotNil(secondFileResponse, TestsMessages.notNil("second office file"))
                self.currentApiFetcher.createDirectory(parentDirectory: rootFile, name: "directory-\(Date())", onlyForMe: true) { directoryResponse, directoryError in
                    XCTAssertNil(directoryError, TestsMessages.noError)
                    XCTAssertNotNil(directoryResponse, TestsMessages.notNil("directory response"))
                    self.currentApiFetcher.getFileCount(driveId: Env.driveId, fileId: rootFile.id) { countResponse, countError in
                        XCTAssertNil(countError, TestsMessages.noError)
                        XCTAssertNotNil(countResponse, TestsMessages.notNil("count response"))
                        XCTAssertEqual(countResponse!.data!.count, 3, "Root file should contain 3 elements")
                        XCTAssertEqual(countResponse!.data!.files, 2, "Root file should contain 2 files")
                        XCTAssertEqual(countResponse!.data!.folders, 1, "Root file should contain 1 folder")
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testBuildArchive() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Build archive")
        _ = try await currentApiFetcher.buildArchive(drive: ProxyDrive(id: Env.driveId), for: [file])
        tearDownTest(directory: rootFile)
    }

    // MARK: - Complementary tests

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
                XCTAssertNotNil(activateResponse?.data, TestsMessages.notNil("share link"))
                XCTAssertNil(activateError, TestsMessages.noError)
                XCTAssertNotNil(activateResponse!.data!.url, TestsMessages.notNil("share link url"))
                expectations[0].expectation.fulfill()

                self.currentApiFetcher.updateShareLinkWith(file: rootFile, canEdit: true, permission: ShareLinkPermission.password.rawValue, password: "password", date: nil, blockDownloads: true, blockComments: false, isFree: false) { updateResponse, updateError in
                    XCTAssertNotNil(updateResponse, TestsMessages.notNil("response"))
                    XCTAssertNil(updateError, TestsMessages.noError)
                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("share response"))
                        XCTAssertNil(shareError, TestsMessages.noError)
                        let share = shareResponse!.data!
                        XCTAssertNotNil(share.link, TestsMessages.notNil("share link"))
                        XCTAssertTrue(share.link!.canEdit, "canEdit should be true")
                        XCTAssertTrue(share.link!.permission == ShareLinkPermission.password.rawValue, "Permission should be equal to 'password'")
                        XCTAssertTrue(share.link!.blockDownloads, "blockDownloads should be true")
                        XCTAssertTrue(!share.link!.blockComments, "blockComments should be false")
                        expectations[1].expectation.fulfill()

                        self.currentApiFetcher.removeShareLinkFor(file: rootFile) { removeResponse, removeError in
                            XCTAssertNotNil(removeResponse, TestsMessages.notNil("response"))
                            XCTAssertNil(removeError, TestsMessages.noError)
                            self.currentApiFetcher.getShareListFor(file: rootFile) { finalResponse, finalError in
                                XCTAssertNotNil(finalResponse?.data, TestsMessages.notNil("share file"))
                                XCTAssertNil(finalError, TestsMessages.noError)
                                XCTAssertNil(finalResponse?.data?.link, TestsMessages.notNil("share link"))
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
                XCTAssertNotNil(checkResponse, TestsMessages.notNil("response"))
                XCTAssertNil(checkError, TestsMessages.noError)
                expectations[0].expectation.fulfill()

                self.currentApiFetcher.addUserRights(file: rootFile, users: [Env.inviteUserId], teams: [], emails: [], message: "Invitation test", permission: UserPermission.manage.rawValue) { addResponse, addError in
                    XCTAssertNotNil(addResponse?.data, TestsMessages.notNil("response"))
                    XCTAssertNil(addError, TestsMessages.noError)
                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("response"))
                        XCTAssertNil(shareError, TestsMessages.noError)
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
                            XCTAssertNotNil(updateResponse, TestsMessages.notNil("response"))
                            XCTAssertNil(updateError, TestsMessages.noError)
                            self.currentApiFetcher.getShareListFor(file: rootFile) { shareUpdateResponse, shareUpdateError in
                                XCTAssertNotNil(shareUpdateResponse?.data, TestsMessages.notNil("response"))
                                XCTAssertNil(shareUpdateError, TestsMessages.noError)
                                let share = shareUpdateResponse!.data!
                                let updatedUser = share.users.first {
                                    $0.id == Env.inviteUserId
                                }
                                XCTAssertNotNil(updatedUser, TestsMessages.notNil("user"))
                                XCTAssertTrue(updatedUser?.permission == .manage, "User permission should be equal to 'manage'")
                                expectations[2].expectation.fulfill()

                                guard let user = updatedUser else { return }
                                self.currentApiFetcher.deleteUserRights(file: rootFile, user: user) { deleteResponse, deleteError in
                                    XCTAssertNotNil(deleteResponse, TestsMessages.notNil("response"))
                                    XCTAssertNil(deleteError, TestsMessages.noError)
                                    self.currentApiFetcher.getShareListFor(file: rootFile) { finalResponse, finalError in
                                        XCTAssertNotNil(finalResponse?.data, TestsMessages.notNil("response"))
                                        XCTAssertNil(finalError, TestsMessages.noError)
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
                XCTAssertNotNil(checkResponse, TestsMessages.notNil("response"))
                XCTAssertNil(checkError, TestsMessages.noError)
                expectations[0].expectation.fulfill()

                self.currentApiFetcher.addUserRights(file: rootFile, users: [], teams: [], emails: [Env.inviteMail], message: "Invitation test", permission: UserPermission.read.rawValue) { addResponse, addError in
                    XCTAssertNil(addError, TestsMessages.noError)
                    let invitation = addResponse?.data?.valid.invitations?.first { $0.email == Env.inviteMail }
                    XCTAssertNotNil(invitation, TestsMessages.notNil("invitation"))
                    guard let invitation = invitation else { return }
                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("response"))
                        XCTAssertNil(shareError, TestsMessages.noError)
                        let invitationAdded = shareResponse?.data?.invitations.compactMap { $0 }.first { $0?.email == Env.inviteMail }
                        XCTAssertNotNil(invitationAdded, "Added invitation should be in share list")
                        guard let invitationAdded = invitationAdded else { return }
                        expectations[1].expectation.fulfill()

                        self.currentApiFetcher.updateInvitationRights(driveId: Env.driveId, invitation: invitation, permission: UserPermission.write.rawValue) { updateResponse, updateError in
                            XCTAssertNotNil(updateResponse, TestsMessages.notNil("response"))
                            XCTAssertNil(updateError, TestsMessages.noError)
                            self.currentApiFetcher.getShareListFor(file: rootFile) { shareUpdateResponse, shareUpdateError in
                                XCTAssertNotNil(shareUpdateResponse?.data, TestsMessages.notNil("response"))
                                XCTAssertNil(shareUpdateError, TestsMessages.noError)
                                let share = shareUpdateResponse!.data!
                                XCTAssertNotNil(share.invitations, TestsMessages.notNil("invitations"))
                                let updatedInvitation = share.invitations.first {
                                    $0!.email == Env.inviteMail
                                }!
                                XCTAssertNotNil(updatedInvitation, TestsMessages.notNil("invitation"))
                                XCTAssertTrue(updatedInvitation?.permission == .write, "Invitation permission should be equal to 'write'")
                                expectations[2].expectation.fulfill()

                                self.currentApiFetcher.deleteInvitationRights(driveId: Env.driveId, invitation: invitation) { deleteResponse, deleteError in
                                    XCTAssertNotNil(deleteResponse, TestsMessages.notNil("response"))
                                    XCTAssertNil(deleteError, TestsMessages.noError)
                                    self.currentApiFetcher.getShareListFor(file: rootFile) { finalResponse, finalError in
                                        XCTAssertNotNil(finalResponse?.data, TestsMessages.notNil("response"))
                                        XCTAssertNil(finalError, TestsMessages.noError)
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

        currentApiFetcher.createCommonDirectory(driveId: Env.driveId, name: "UnitTest - \(testName)", forAllUser: false) { response, _ in
            XCTAssertNotNil(rootFile, "Failed to create UnitTest directory")
            rootFile = response!.data!

            self.currentApiFetcher.checkUserRights(file: rootFile, users: [], teams: [Env.inviteTeam], emails: [], permission: UserPermission.read.rawValue) { checkResponse, checkError in
                XCTAssertNotNil(checkResponse, TestsMessages.notNil("response"))
                XCTAssertNil(checkError, TestsMessages.noError)
                expectations[0].expectation.fulfill()

                self.currentApiFetcher.addUserRights(file: rootFile, users: [], teams: [Env.inviteTeam], emails: [], message: "Invitation test", permission: UserPermission.read.rawValue) { addResponse, addError in
                    XCTAssertNotNil(addResponse?.data, TestsMessages.notNil("response"))
                    XCTAssertNil(addError, TestsMessages.noError)
                    self.currentApiFetcher.getShareListFor(file: rootFile) { shareResponse, shareError in
                        XCTAssertNotNil(shareResponse?.data, TestsMessages.notNil("response"))
                        XCTAssertNil(shareError, TestsMessages.noError)
                        let share = shareResponse?.data
                        let teamAdded = share?.teams.first { $0.id == Env.inviteTeam }
                        XCTAssertNotNil(teamAdded, "Added team should be in share list")
                        XCTAssertTrue(teamAdded?.right == .read, "Added team permission should be equal to 'read'")
                        expectations[1].expectation.fulfill()
                        guard let team = teamAdded else { return }
                        self.currentApiFetcher.updateTeamRights(file: rootFile, team: team, permission: UserPermission.write.rawValue) { updateResponse, updateError in
                            XCTAssertNotNil(updateResponse, TestsMessages.notNil("response"))
                            XCTAssertNil(updateError, TestsMessages.noError)
                            self.currentApiFetcher.getShareListFor(file: rootFile) { shareUpdateResponse, shareUpdateError in
                                XCTAssertNotNil(shareUpdateResponse?.data, TestsMessages.notNil("response"))
                                XCTAssertNil(shareUpdateError, TestsMessages.noError)
                                let share = shareUpdateResponse?.data
                                XCTAssertNotNil(share?.teams, TestsMessages.notNil("teams"))
                                let updatedTeam = share?.teams.first { $0.id == Env.inviteTeam }
                                XCTAssertNotNil(updatedTeam, TestsMessages.notNil("team"))
                                XCTAssertTrue(updatedTeam?.right == .write, "Team permission should be equal to 'write'")
                                expectations[2].expectation.fulfill()
                                guard let team = updatedTeam else { return }
                                self.currentApiFetcher.deleteTeamRights(file: rootFile, team: team) { deleteResponse, deleteError in
                                    XCTAssertNotNil(deleteResponse, TestsMessages.notNil("response"))
                                    XCTAssertNil(deleteError, TestsMessages.noError)
                                    self.currentApiFetcher.getShareListFor(file: rootFile) { finalResponse, finalError in
                                        XCTAssertNotNil(finalResponse?.data, TestsMessages.notNil("response"))
                                        XCTAssertNil(finalError, TestsMessages.noError)
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

    func testCategory() async throws {
        let folder = await setUpTest(testName: "Categories")
        // 1. Create category
        let category = try await currentApiFetcher.createCategory(drive: ProxyDrive(id: Env.driveId), name: "UnitTest-\(Date())", color: "#1abc9c")
        // 2. Add category to folder
        let addResponse = try await currentApiFetcher.add(category: category, to: folder)
        XCTAssertTrue(addResponse, "API should return true")
        // 3. Remove category from folder
        let removeResponse = try await currentApiFetcher.remove(category: category, from: folder)
        XCTAssertTrue(removeResponse, "API should return true")
        // 4. Delete category
        let deleteResponse = try await currentApiFetcher.deleteCategory(drive: ProxyDrive(id: Env.driveId), category: category)
        XCTAssertTrue(deleteResponse, "API should return true")
        tearDownTest(directory: folder)
    }

    func testDirectoryColor() async {
        let directory = await setUpTest(testName: "DirectoryColor")
        do {
            let result = try await currentApiFetcher.updateColor(directory: directory, color: "#E91E63")
            XCTAssertTrue(result, "API should return true")
        } catch {
            XCTFail("There should be no error on changing directory color")
        }
        tearDownTest(directory: directory)
    }
}
