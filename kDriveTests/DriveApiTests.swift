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
        Task {
            _ = try await currentApiFetcher.delete(file: directory)
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

    func initDropbox(testName: String) async -> (File, File) {
        let rootFile = await setUpTest(testName: testName)
        let dir = await createTestDirectory(name: "dropbox-\(Date())", parentDirectory: rootFile)
        let dropBox = try? await currentApiFetcher.createDropBox(directory: dir, settings: DropBoxSettings(alias: nil, emailWhenFinished: false, limitFileSize: nil, password: nil, validUntil: nil))
        guard dropBox != nil else {
            fatalError("Failed to create dropbox")
        }
        return (rootFile, dir)
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

    func testCreateDropBox() async throws {
        let settings = DropBoxSettings(alias: nil, emailWhenFinished: false, limitFileSize: nil, password: "password", validUntil: nil)
        let rootFile = await setUpTest(testName: "Create dropbox")
        let dir = await createTestDirectory(name: "Create dropbox", parentDirectory: rootFile)
        let dropBox = try await currentApiFetcher.createDropBox(directory: dir, settings: settings)
        XCTAssertTrue(dropBox.capabilities.hasPassword, "Dropbox should have a password")
        tearDownTest(directory: rootFile)
    }

    func testGetDropBox() async throws {
        let settings = DropBoxSettings(alias: nil, emailWhenFinished: false, limitFileSize: .gigabytes(5), password: "newPassword", validUntil: Date())
        let (rootFile, dropBoxDir) = await initDropbox(testName: "Dropbox settings")
        let response = try await currentApiFetcher.updateDropBox(directory: dropBoxDir, settings: settings)
        XCTAssertTrue(response, "API should return true")
        let dropBox = try await currentApiFetcher.getDropBox(directory: dropBoxDir)
        XCTAssertTrue(dropBox.capabilities.hasPassword, "Dropxbox should have a password")
        XCTAssertTrue(dropBox.capabilities.hasValidity, "Dropbox should have a validity")
        XCTAssertNotNil(dropBox.capabilities.validity.date, "Validity shouldn't be nil")
        XCTAssertTrue(dropBox.capabilities.hasSizeLimit, "Dropbox should have a size limit")
        XCTAssertNotNil(dropBox.capabilities.size.limit, "Size limit shouldn't be nil")
        tearDownTest(directory: rootFile)
    }

    func testDeleteDropBox() async throws {
        let (rootFile, dropBoxDir) = await initDropbox(testName: "Delete dropbox")
        _ = try await currentApiFetcher.getDropBox(directory: dropBoxDir)
        let response = try await currentApiFetcher.deleteDropBox(directory: dropBoxDir)
        XCTAssertTrue(response, "API should return true")
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

    func testCreateShareLink() async throws {
        let rootFile = await setUpTest(testName: "Create share link")
        let shareLink1 = try await currentApiFetcher.createShareLink(for: rootFile)
        let shareLink2 = try await currentApiFetcher.shareLink(for: rootFile)
        XCTAssertEqual(shareLink1.url, shareLink2.url, "Share link url should match")
        tearDownTest(directory: rootFile)
    }

    func testUpdateShareLink() async throws {
        let rootFile = await setUpTest(testName: "Update share link")
        _ = try await currentApiFetcher.createShareLink(for: rootFile)
        let updatedSettings = ShareLinkSettings(canComment: true, canDownload: false, canEdit: true, canSeeInfo: true, canSeeStats: true, password: "password", right: .password, validUntil: nil)
        let response = try await currentApiFetcher.updateShareLink(for: rootFile, settings: updatedSettings)
        XCTAssertTrue(response, "API should return true")
        let updatedShareLink = try await currentApiFetcher.shareLink(for: rootFile)
        XCTAssertTrue(updatedShareLink.capabilities.canComment, "canComment should be true")
        XCTAssertFalse(updatedShareLink.capabilities.canDownload, "canDownload should be false")
        XCTAssertTrue(updatedShareLink.capabilities.canEdit, "canEdit should be true")
        XCTAssertTrue(updatedShareLink.capabilities.canSeeInfo, "canSeeInfo should be true")
        XCTAssertTrue(updatedShareLink.capabilities.canSeeStats, "canSeeStats should be true")
        XCTAssertTrue(updatedShareLink.right == ShareLinkPermission.password.rawValue, "Right should be equal to 'password'")
        XCTAssertNil(updatedShareLink.validUntil, "validUntil should be nil")
        tearDownTest(directory: rootFile)
    }

    func testRemoveShareLink() async throws {
        let rootFile = await setUpTest(testName: "Remove share link")
        _ = try await currentApiFetcher.createShareLink(for: rootFile)
        let response = try await currentApiFetcher.removeShareLink(for: rootFile)
        XCTAssertTrue(response, "API should return true")
        tearDownTest(directory: rootFile)
    }

    func testGetFileAccess() async throws {
        let rootFile = await setUpTest(testName: "Get file access")
        _ = try await currentApiFetcher.access(for: rootFile)
        tearDownTest(directory: rootFile)
    }

    func testCheckAccessChange() async throws {
        let rootFile = await setUpTest(testName: "Check access")
        let settings = FileAccessSettings(right: .write, emails: [Env.inviteMail], userIds: [Env.inviteUserId])
        _ = try await currentApiFetcher.checkAccessChange(to: rootFile, settings: settings)
        tearDownTest(directory: rootFile)
    }

    func testAddAccess() async throws {
        let rootFile = await setUpTest(testName: "Add access")
        let settings = FileAccessSettings(message: "Test access", right: .write, emails: [Env.inviteMail], userIds: [Env.inviteUserId])
        _ = try await currentApiFetcher.addAccess(to: rootFile, settings: settings)
        let fileAccess = try await currentApiFetcher.access(for: rootFile)
        let userAdded = fileAccess.users.first { $0.id == Env.inviteUserId }
        XCTAssertNotNil(userAdded, "Added user should be in share list")
        XCTAssertEqual(userAdded?.right, .write, "Added user right should be equal to 'write'")
        let invitation = fileAccess.invitations.first { $0.email == Env.inviteMail }
        XCTAssertNotNil(invitation, "Invitation should be in share list")
        XCTAssertEqual(invitation?.right, .write, "Invitation right should be equal to 'write'")
        XCTAssertTrue(fileAccess.teams.isEmpty, "There should be no team in share list")
        tearDownTest(directory: rootFile)
    }

    func testUpdateUserAccess() async throws {
        let rootFile = await setUpTest(testName: "Update user access")
        let settings = FileAccessSettings(message: "Test update user access", right: .read, userIds: [Env.inviteUserId])
        let response = try await currentApiFetcher.addAccess(to: rootFile, settings: settings)
        let user = response.users.first { $0.id == Env.inviteUserId }?.access
        XCTAssertNotNil(user, "User shouldn't be nil")
        if let user = user {
            let response = try await currentApiFetcher.updateUserAccess(to: rootFile, user: user, right: .manage)
            XCTAssertTrue(response, "API should return true")
            let fileAccess = try await currentApiFetcher.access(for: rootFile)
            let updatedUser = fileAccess.users.first { $0.id == Env.inviteUserId }
            XCTAssertNotNil(updatedUser, "User shouldn't be nil")
            XCTAssertEqual(updatedUser?.right, .manage, "User permission should be equal to 'manage'")
        }
        tearDownTest(directory: rootFile)
    }

    func testRemoveUserAccess() async throws {
        let rootFile = await setUpTest(testName: "Remove user access")
        let settings = FileAccessSettings(message: "Test remove user access", right: .read, userIds: [Env.inviteUserId])
        let response = try await currentApiFetcher.addAccess(to: rootFile, settings: settings)
        let user = response.users.first { $0.id == Env.inviteUserId }?.access
        XCTAssertNotNil(user, "User shouldn't be nil")
        if let user = user {
            let response = try await currentApiFetcher.removeUserAccess(to: rootFile, user: user)
            XCTAssertTrue(response, "API should return true")
            let fileAccess = try await currentApiFetcher.access(for: rootFile)
            let deletedUser = fileAccess.users.first { $0.id == Env.inviteUserId }
            XCTAssertNil(deletedUser, "Deleted user should be nil")
        }
        tearDownTest(directory: rootFile)
    }

    func testUpdateInvitationAccess() async throws {
        let rootFile = await setUpTest(testName: "Update invitation access")
        let settings = FileAccessSettings(message: "Test update invitation access", right: .read, emails: [Env.inviteMail])
        let response = try await currentApiFetcher.addAccess(to: rootFile, settings: settings)
        let invitation = response.emails.first { $0.id == Env.inviteMail }?.access
        XCTAssertNotNil(invitation, "Invitation shouldn't be nil")
        if let invitation = invitation {
            let response = try await currentApiFetcher.updateInvitationAccess(drive: ProxyDrive(id: Env.driveId), invitation: invitation, right: .write)
            XCTAssertTrue(response, "API should return true")
            let fileAccess = try await currentApiFetcher.access(for: rootFile)
            let updatedInvitation = fileAccess.invitations.first { $0.email == Env.inviteMail }
            XCTAssertNotNil(updatedInvitation, "Invitation shouldn't be nil")
            XCTAssertEqual(updatedInvitation?.right, .write, "Invitation right should be equal to 'write'")
        }
        tearDownTest(directory: rootFile)
    }

    func testDeleteInvitation() async throws {
        let rootFile = await setUpTest(testName: "Delete invitation")
        let settings = FileAccessSettings(message: "Test delete invitation", right: .read, emails: [Env.inviteMail])
        let response = try await currentApiFetcher.addAccess(to: rootFile, settings: settings)
        let invitation = response.emails.first { $0.id == Env.inviteMail }?.access
        XCTAssertNotNil(invitation, "Invitation shouldn't be nil")
        if let invitation = invitation {
            let response = try await currentApiFetcher.deleteInvitation(drive: ProxyDrive(id: Env.driveId), invitation: invitation)
            XCTAssertTrue(response, "API should return true")
            let fileAccess = try await currentApiFetcher.access(for: rootFile)
            let deletedInvitation = fileAccess.invitations.first { $0.email == Env.inviteMail }
            XCTAssertNil(deletedInvitation, "Deleted invitation should be nil")
        }
        tearDownTest(directory: rootFile)
    }

    func createCommonDirectory(testName: String) async throws -> File {
        try await withCheckedThrowingContinuation { continuation in
            currentApiFetcher.createCommonDirectory(driveId: Env.driveId, name: "UnitTest - \(testName)", forAllUser: false) { response, error in
                if let file = response?.data {
                    continuation.resume(returning: file)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
    }

    func testUpdateTeamAccess() async throws {
        let rootFile = try await createCommonDirectory(testName: "Update team access")
        let settings = FileAccessSettings(message: "Test update team access", right: .read, teamIds: [Env.inviteTeam])
        let response = try await currentApiFetcher.addAccess(to: rootFile, settings: settings)
        let team = response.teams.first { $0.id == Env.inviteTeam }?.access
        XCTAssertNotNil(team, "Team shouldn't be nil")
        if let team = team {
            let response = try await currentApiFetcher.updateTeamAccess(to: rootFile, team: team, right: .write)
            XCTAssertTrue(response, "API should return true")
            let fileAccess = try await currentApiFetcher.access(for: rootFile)
            let updatedTeam = fileAccess.teams.first { $0.id == Env.inviteTeam }
            XCTAssertNotNil(updatedTeam, "Team shouldn't be nil")
            XCTAssertEqual(updatedTeam?.right, .write, "Team right should be equal to 'write'")
        }
        tearDownTest(directory: rootFile)
    }

    func testRemoveTeamAccess() async throws {
        let rootFile = try await createCommonDirectory(testName: "Update team access")
        let settings = FileAccessSettings(message: "Test remove team access", right: .read, teamIds: [Env.inviteTeam])
        let response = try await currentApiFetcher.addAccess(to: rootFile, settings: settings)
        let team = response.teams.first { $0.id == Env.inviteTeam }?.access
        XCTAssertNotNil(team, "Invitation shouldn't be nil")
        if let team = team {
            let response = try await currentApiFetcher.removeTeamAccess(to: rootFile, team: team)
            XCTAssertTrue(response, "API should return true")
            let fileAccess = try await currentApiFetcher.access(for: rootFile)
            let deletedTeam = fileAccess.teams.first { $0.id == Env.inviteTeam }
            XCTAssertNil(deletedTeam, "Deleted team should be nil")
        }
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

    func testDeleteFile() async throws {
        let rootFile = await setUpTest(testName: "Delete file")
        let directory = await createTestDirectory(name: "Delete file", parentDirectory: rootFile)
        _ = try await currentApiFetcher.delete(file: directory)
        // Check that file has been deleted
        let fetchedDirectory: File = try await withCheckedThrowingContinuation { continuation in
            self.currentApiFetcher.getFileListForDirectory(driveId: Env.driveId, parentId: rootFile.id) { response, error in
                if let file = response?.data {
                    continuation.resume(returning: file)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
        let deletedFile = fetchedDirectory.children.first { $0.id == directory.id }
        XCTAssertNil(deletedFile, TestsMessages.notNil("deleted file"))
        // Check that file is in trash
        let trashedFiles: [File] = try await withCheckedThrowingContinuation { continuation in
            self.currentApiFetcher.getTrashedFiles(driveId: Env.driveId, sortType: .newerDelete) { response, error in
                if let files = response?.data {
                    continuation.resume(returning: files)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
        let file = trashedFiles.first { $0.id == directory.id }
        XCTAssertNotNil(file, TestsMessages.notNil("deleted file"))
        if let file = file {
            // Delete definitely
            let response = try await currentApiFetcher.deleteDefinitely(file: file)
            XCTAssertTrue(response, "API should return true")
            // Check that file is not in trash anymore
            let trashedFiles: [File] = try await withCheckedThrowingContinuation { continuation in
                self.currentApiFetcher.getTrashedFiles(driveId: Env.driveId, sortType: .newerDelete) { response, error in
                    if let files = response?.data {
                        continuation.resume(returning: files)
                    } else {
                        continuation.resume(throwing: error ?? DriveError.unknownError)
                    }
                }
            }
            let file = trashedFiles.first { $0.id == directory.id }
            XCTAssertNil(file, TestsMessages.notNil("deleted file"))
        }
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

    func testMoveFile() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Move file")
        let destination = await createTestDirectory(name: "destination-\(Date())", parentDirectory: rootFile)
        _ = try await currentApiFetcher.move(file: file, to: destination)
        await checkIfFileIsInDestination(file: file, directory: destination)
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

    func testFavoriteFile() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Favorite file")
        // Favorite
        let favoriteResponse = try await currentApiFetcher.favorite(file: file)
        XCTAssertTrue(favoriteResponse, "API should return true")
        let files: [File] = try await withCheckedThrowingContinuation { continuation in
            self.currentApiFetcher.getFavoriteFiles(driveId: Env.driveId, page: 1, sortType: .newer) { response, error in
                if let files = response?.data {
                    continuation.resume(returning: files)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
        let favoriteFile = files.first { $0.id == file.id }
        XCTAssertNotNil(favoriteFile, "File should be in Favorite files")
        XCTAssertTrue(favoriteFile?.isFavorite == true, "File should be favorite")
        // Unfavorite
        let unfavoriteResponse = try await currentApiFetcher.unfavorite(file: file)
        XCTAssertTrue(unfavoriteResponse, "API should return true")
        let files2: [File] = try await withCheckedThrowingContinuation { continuation in
            self.currentApiFetcher.getFavoriteFiles(driveId: Env.driveId, page: 1, sortType: .newer) { response, error in
                if let files = response?.data {
                    continuation.resume(returning: files)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
        let unfavoriteFile = files2.first { $0.id == file.id }
        XCTAssertNil(unfavoriteFile, "File should be in Favorite files")
        // Check file
        let finalFile: File = try await withCheckedThrowingContinuation { continuation in
            self.currentApiFetcher.getFileListForDirectory(driveId: Env.driveId, parentId: file.id) { response, error in
                if let file = response?.data {
                    continuation.resume(returning: file)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
        XCTAssertFalse(finalFile.isFavorite, "File shouldn't be favorite")
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

    func testGetChildrenTrashedFiles() async throws {
        let (rootFile, _) = await initOfficeFile(testName: "Get children trashed file")
        _ = try await currentApiFetcher.delete(file: rootFile)
        let trashedFile: File = try await withCheckedThrowingContinuation { continuation in
            self.currentApiFetcher.getChildrenTrashedFiles(driveId: Env.driveId, fileId: rootFile.id) { response, error in
                if let file = response?.data {
                    continuation.resume(returning: file)
                } else {
                    continuation.resume(throwing: error ?? DriveError.unknownError)
                }
            }
        }
        XCTAssertEqual(trashedFile.children.count, 1, "Trashed file should have one child")
        tearDownTest(directory: rootFile)
    }

    func testRestoreTrashedFile() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Restore trashed file")
        _ = try await currentApiFetcher.delete(file: file)
        _ = try await currentApiFetcher.restore(file: file)
        await checkIfFileIsInDestination(file: file, directory: rootFile)
        tearDownTest(directory: rootFile)
    }

    func testRestoreTrashedFileInFolder() async throws {
        let (rootFile, file) = await initOfficeFile(testName: "Restore trashed file in folder")
        _ = try await currentApiFetcher.delete(file: file)
        let directory = await createTestDirectory(name: "restore destination - \(Date())", parentDirectory: rootFile)
        _ = try await currentApiFetcher.restore(file: file, in: directory)
        await checkIfFileIsInDestination(file: file, directory: directory)
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
        let moveResponse = try await currentApiFetcher.move(file: file, to: directory)
        try await currentApiFetcher.undoAction(drive: ProxyDrive(id: Env.driveId), cancelId: moveResponse.id)
        await checkIfFileIsInDestination(file: file, directory: rootFile)
        // Delete & cancel
        let deleteResponse = try await currentApiFetcher.delete(file: file)
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
