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
import RealmSwift
import XCTest

@testable import kDrive

final class DriveFileManagerTests: XCTestCase {
    static let defaultTimeout = 10.0
    static var driveFileManager: DriveFileManager!

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
        DriveFileManagerTests.driveFileManager.deleteFile(file: directory) { response, _ in
            XCTAssertNotNil(response, "Failed to delete directory")
        }
    }

    // MARK: - Helping methods

    func getRootDirectory(completion: @escaping (File) -> Void) {
        DriveFileManagerTests.driveFileManager.getFile(id: DriveFileManager.constants.rootID) { file, _, _ in
            XCTAssertNotNil(file, "Failed to get root directory")
            completion(file!)
        }
    }

    func createTestDirectory(name: String, parentDirectory: File, completion: @escaping (File) -> Void) {
        DriveFileManagerTests.driveFileManager.createDirectory(parentDirectory: parentDirectory, name: "\(name) - \(Date())", onlyForMe: true) { directory, _ in
            XCTAssertNotNil(directory, "Failed to create test directory")
            completion(directory!)
        }
    }

    func initOfficeFile(testName: String, completion: @escaping (File, File) -> Void) {
        setUpTest(testName: testName) { rootFile in
            DriveFileManagerTests.driveFileManager.createOfficeFile(parentDirectory: rootFile, name: "officeFile-\(Date())", type: "docx") { file, _ in
                XCTAssertNotNil(file, "Failed to create office file")
                completion(rootFile, file!)
            }
        }
    }

    func checkIfFileIsInFavorites(file: File, shouldBePresent: Bool = true, completion: @escaping () -> Void) {
        DriveFileManagerTests.driveFileManager.getFavorites { root, favorites, error in
            XCTAssertNotNil(root, TestsMessages.notNil("root"))
            XCTAssertNotNil(favorites, TestsMessages.notNil("favorites"))
            XCTAssertNil(error, TestsMessages.noError)
            let isInFavoritesFiles = favorites!.contains { $0.id == file.id }
            XCTAssertEqual(isInFavoritesFiles, shouldBePresent, "File should\(shouldBePresent ? "" : ",'t") be in favorites files")

            completion()
        }
    }

    // MARK: - Test methods

    func testGetRootFile() {
        let testName = "Get root file"
        let expectation = XCTestExpectation(description: testName)

        DriveFileManagerTests.driveFileManager.getFile(id: DriveFileManager.constants.rootID) { root, _, error in
            XCTAssertNotNil(root, TestsMessages.notNil("root file"))
            XCTAssertNil(error, TestsMessages.noError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
    }

    func testGetCommonDocuments() {
        let testName = "Get Common documents"
        let expectation = XCTestExpectation(description: testName)

        DriveFileManagerTests.driveFileManager.getFile(id: Env.commonDocumentsId) { file, _, error in
            XCTAssertNotNil(file, TestsMessages.notNil("common documents"))
            XCTAssertNil(error, TestsMessages.noError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
    }

    func testFavorites() {
        let testName = "Get favorites"
        let expectations = [
            (name: "Set favorite", expectation: XCTestExpectation(description: "Get favorite")),
            (name: "Remove favorite", expectation: XCTestExpectation(description: "Remove favorite"))
        ]
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            DriveFileManagerTests.driveFileManager.setFavoriteFile(file: rootFile, favorite: true) { error in
                XCTAssertNil(error, "Failed to set favorite")
                self.checkIfFileIsInFavorites(file: rootFile) {
                    expectations[0].expectation.fulfill()
                    DriveFileManagerTests.driveFileManager.setFavoriteFile(file: rootFile, favorite: false) { error in
                        XCTAssertNil(error, "Failed to remove favorite")
                        self.checkIfFileIsInFavorites(file: rootFile, shouldBePresent: false) {
                            expectations[1].expectation.fulfill()
                        }
                    }
                }
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testShareLink() {
        let testName = "Share link"
        let expectations = [
            (name: "Activate share link", expectation: XCTestExpectation(description: "Activate share link")),
            (name: "Remove share link", expectation: XCTestExpectation(description: "Remove share link"))
        ]
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            DriveFileManagerTests.driveFileManager.activateShareLink(for: rootFile) { shareLink, error in
                XCTAssertNil(error, TestsMessages.noError)
                XCTAssertNotNil(shareLink, TestsMessages.notNil("ShareLink"))
                expectations[0].expectation.fulfill()

                DriveFileManagerTests.driveFileManager.removeShareLink(for: rootFile) { error in
                    XCTAssertNil(error, TestsMessages.noError)
                    expectations[1].expectation.fulfill()
                }
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testSearchFile() {
        let testName = "Search file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, officeFile in
            rootFile = root
            DriveFileManagerTests.driveFileManager.searchFile(query: officeFile.name, categories: [], belongToAllCategories: true, page: 1, sortType: .nameAZ) { root, fileList, _ in
                XCTAssertNotNil(root, TestsMessages.notNil("root"))
                XCTAssertNotNil(fileList, TestsMessages.notNil("files list"))
                let searchedFile = fileList!.contains { $0.id == officeFile.id }
                XCTAssertTrue(searchedFile, TestsMessages.notNil("searched file"))
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testFileAvailableOffline() {
        let testName = "Available offline"
        let expectations = [
            (name: "Set available offline", expectation: XCTestExpectation(description: "Set available offline")),
            (name: "Get available offline", expectation: XCTestExpectation(description: "Get available offline"))
        ]
        var rootFile = File()

        initOfficeFile(testName: testName) { root, officeFile in
            rootFile = root
            DriveFileManagerTests.driveFileManager.setFileAvailableOffline(file: officeFile, available: true) { error in
                XCTAssertNil(error, TestsMessages.noError)
                expectations[0].expectation.fulfill()
                let offlineFiles = DriveFileManagerTests.driveFileManager.getAvailableOfflineFiles()
                let availableOffline = offlineFiles.contains { $0.id == officeFile.id }
                XCTAssertTrue(availableOffline, "New offline file should be in list")
                expectations[1].expectation.fulfill()
            }
        }

        wait(for: expectations.map(\.expectation), timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    // WIP
    func testGetLastModifiedFiles() {
        let testName = "Get last modified files"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            DriveFileManagerTests.driveFileManager.createOfficeFile(parentDirectory: rootFile, name: "test", type: "docx") { officeFile, officeError in
                XCTAssertNil(officeError, TestsMessages.noError)
                XCTAssertNotNil(officeFile, TestsMessages.notNil("Office file created"))

                DriveFileManagerTests.driveFileManager.getLastModifiedFiles(page: 1) { files, error in
                    XCTAssertNil(error, TestsMessages.noError)
                    XCTAssertNotNil(files, TestsMessages.notNil("Last modified files"))
                    let lastModifiedFile = files![0].id
                    XCTAssertEqual(lastModifiedFile, officeFile!.id, "Last modified file should be root file")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout * 2) // DriveFileManagerTests.defaultTimeout is too short
        tearDownTest(directory: rootFile)
    }

    // WIP
    func testCancelAction() {}

    func testDeleteFile() {
        let testName = "Delete file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, officeFile in
            rootFile = root

            let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: officeFile.id)
            XCTAssertNotNil(cached, TestsMessages.notNil("cached file"))

            DriveFileManagerTests.driveFileManager.deleteFile(file: officeFile) { _, error in
                XCTAssertNil(error, TestsMessages.noError)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testMoveFile() {
        let testName = "Move file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, officeFile in
            rootFile = root
            self.createTestDirectory(name: "Destination", parentDirectory: rootFile) { destination in
                XCTAssertNotNil(destination, "Failed to create destination directory")
                DriveFileManagerTests.driveFileManager.moveFile(file: officeFile, newParent: destination) { _, file, error in
                    XCTAssertNotNil(file, TestsMessages.notNil("file"))
                    XCTAssertNil(error, TestsMessages.noError)
                    XCTAssertTrue(file?.parent?.id == destination.id, "New parent should be 'destination' directory")

                    let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: officeFile.id)
                    XCTAssertNotNil(cached, TestsMessages.notNil("cached file"))
                    XCTAssertTrue(cached!.parent?.id == destination.id, "New parent not updated in realm")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testRenameFile() {
        let testName = "Rename file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, officeFile in
            rootFile = root
            DriveFileManagerTests.driveFileManager.renameFile(file: officeFile, newName: testName) { file, error in
                XCTAssertNotNil(file, TestsMessages.notNil("file"))
                XCTAssertNil(error, TestsMessages.noError)
                XCTAssertTrue(file?.name == testName, "File name should have been renamed")

                let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: officeFile.id)
                XCTAssertNotNil(cached, TestsMessages.notNil("cached file"))
                XCTAssertTrue(cached!.name == testName, "New name not updated in realm")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testDuplicateFile() {
        let testName = "Duplicate file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, officeFile in
            rootFile = root
            DriveFileManagerTests.driveFileManager.duplicateFile(file: officeFile, duplicateName: "\(testName) - \(Date())") { file, error in
                XCTAssertNotNil(file, TestsMessages.notNil("duplicated file"))
                XCTAssertNil(error, TestsMessages.noError)

                let cachedRoot = DriveFileManagerTests.driveFileManager.getCachedFile(id: rootFile.id)
                XCTAssertNotNil(cachedRoot, TestsMessages.notNil("cached root"))
                XCTAssertTrue(cachedRoot!.children.count == 2, "Cached root should have 2 children")

                let newFile = cachedRoot?.children.contains { $0.id == file!.id }
                XCTAssertTrue(newFile!, "New file should be in realm")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
        tearDownTest(directory: rootFile)
    }

    func testCreateDirectory() {
        let testName = "Create directory"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            DriveFileManagerTests.driveFileManager.createDirectory(parentDirectory: rootFile, name: "\(testName) - \(Date())", onlyForMe: true) { file, error in
                XCTAssertNotNil(file, TestsMessages.notNil("directory created"))
                XCTAssertNil(error, TestsMessages.noError)

                let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: file!.id)
                XCTAssertNotNil(cached, TestsMessages.notNil("cached root"))
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testCreateCommonDirectory() {
        let testName = "Create common directory"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        DriveFileManagerTests.driveFileManager.createCommonDirectory(name: "\(testName) - \(Date())", forAllUser: false) { file, error in
            XCTAssertNotNil(file, TestsMessages.notNil("created common"))
            XCTAssertNil(error, TestsMessages.noError)
            rootFile = file!

            let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: rootFile.id)
            XCTAssertNotNil(cached, TestsMessages.notNil("cached root"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testCreateDropBox() {
        let testName = "Create dropbox"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            DriveFileManagerTests.driveFileManager.createDropBox(parentDirectory: rootFile, name: "\(testName) - \(Date())", onlyForMe: true, password: "mot de passe", validUntil: nil, emailWhenFinished: true, limitFileSize: nil) { file, dropbox, error in
                XCTAssertNotNil(file, TestsMessages.notNil("created file"))
                XCTAssertNotNil(dropbox, TestsMessages.notNil("dropbox settings"))
                XCTAssertNil(error, TestsMessages.noError)

                let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: file!.id)
                XCTAssertNotNil(cached, TestsMessages.notNil("cached dropbox"))
                XCTAssertTrue(cached!.collaborativeFolder?.count ?? 0 > 0, "Cached dropbox link should be set")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testCreateOfficeFile() {
        let testName = "Create office file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            DriveFileManagerTests.driveFileManager.createOfficeFile(parentDirectory: rootFile, name: "\(testName) - \(Date())", type: "docx") { file, error in
                XCTAssertNotNil(file, TestsMessages.notNil("office file"))
                XCTAssertNil(error, TestsMessages.noError)

                let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: file!.id)
                XCTAssertNotNil(cached, TestsMessages.notNil("office file"))
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    // WIP
    func updateFolderColor() {}
}
