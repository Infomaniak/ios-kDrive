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
import XCTest
import InfomaniakLogin
import InfomaniakCore
import kDriveCore
import RealmSwift

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

// MARK: - Test methods

    func testGetRootFile() {
        let testName = "Get root file"
        let expectation = XCTestExpectation(description: testName)

        DriveFileManagerTests.driveFileManager.getFile(id: DriveFileManager.constants.rootID) { root, _, error in
            XCTAssertNotNil(root, "Root file shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
    }

    func testGetCommonDocuments() {
        let testName = "Get Common documents"
        let expectation = XCTestExpectation(description: testName)

        DriveFileManagerTests.driveFileManager.getFile(id: Env.commonDocumentsId) { file, _, error in
            XCTAssertNotNil(file, "Common documents shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
    }

    func testGetFavorites() {
        let testName = "Get favorites"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            DriveFileManagerTests.driveFileManager.setFavoriteFile(file: rootFile, favorite: true) { error in
                XCTAssertNil(error, "Failed to set favorite")
                DriveFileManagerTests.driveFileManager.getFavorites { root, favorites, error in
                    XCTAssertNotNil(root, "Root shouldn't be nil")
                    XCTAssertNotNil(favorites, "Favorites shouldn't be nil")
                    XCTAssertNil(error, "There should be no error")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testSearchFile() {
        let testName = "Search file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, officeFile in
            rootFile = root
            DriveFileManagerTests.driveFileManager.searchFile(query: officeFile.name, fileType: nil, page: 1, sortType: .nameAZ) { root, fileList, _ in
                XCTAssertNotNil(root, "Root shouldn't be nil")
                XCTAssertNotNil(fileList, "Files list shouldn't be nil")
                let searchedFile = fileList!.contains { $0.id == officeFile.id }
                XCTAssertTrue(searchedFile, "Searched file shouldn't be nil")
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
                XCTAssertNil(error, "There should be no error")
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

    func testSetFavoriteFile() {
        let testName = "Set favorite file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, officeFile in
            rootFile = root
            DriveFileManagerTests.driveFileManager.setFavoriteFile(file: officeFile, favorite: true) { error in
                XCTAssertNil(error, "There should be no error")

                let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: officeFile.id)
                XCTAssertNotNil(cached, "File shouldn't be nil")
                XCTAssertTrue(cached!.isFavorite, "Cached file should be favorite")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

    func testDeleteFile() {
        let testName = "Delete file"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        initOfficeFile(testName: testName) { root, officeFile in
            rootFile = root

            let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: officeFile.id)
            XCTAssertNotNil(cached, "Cached file shouldn't be nil")

            DriveFileManagerTests.driveFileManager.deleteFile(file: officeFile) { _, error in
                XCTAssertNil(error, "There should be no error")
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
                    XCTAssertNotNil(file, "File shouldn't be nil")
                    XCTAssertNil(error, "There should be no error")
                    XCTAssertTrue(file?.parent?.id == destination.id, "New parent should be 'destination' directory")

                    let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: officeFile.id)
                    XCTAssertNotNil(cached, "Cached file shouldn't be nil")
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
                XCTAssertNotNil(file, "File shouldn't be nil")
                XCTAssertNil(error, "There should be no error")
                XCTAssertTrue(file?.name == testName, "File name should have been renamed")

                let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: officeFile.id)
                XCTAssertNotNil(cached, "Cached file shouldn't be nil")
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
                XCTAssertNotNil(file, "Duplicated file shouldn't be nil")
                XCTAssertNil(error, "There should be no error")

                let cachedRoot = DriveFileManagerTests.driveFileManager.getCachedFile(id: rootFile.id)
                XCTAssertNotNil(cachedRoot, "Cached root shouldn't be nil")
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
                XCTAssertNotNil(file, "Directory created shouldn't be nil")
                XCTAssertNil(error, "There should be no error")

                let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: file!.id)
                XCTAssertNotNil(cached, "Cached root shouldn't be nil")
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
            XCTAssertNotNil(file, "Created common directory shouldn't be nil")
            XCTAssertNil(error, "There should be no error")
            rootFile = file!

            let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: rootFile.id)
            XCTAssertNotNil(cached, "Cached root shouldn't be nil")
            expectation.fulfill()

        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        self.tearDownTest(directory: rootFile)
    }

    func testCreateDropBox() {
        let testName = "Create dropbox"
        let expectation = XCTestExpectation(description: testName)
        var rootFile = File()

        setUpTest(testName: testName) { root in
            rootFile = root
            DriveFileManagerTests.driveFileManager.createDropBox(parentDirectory: rootFile, name: "\(testName) - \(Date())", onlyForMe: true, password: "mot de passe", validUntil: nil, emailWhenFinished: true, limitFileSize: nil) { file, dropbox, error in
                XCTAssertNotNil(file, "Created file shouldn't be nil")
                XCTAssertNotNil(dropbox, "Dropbox settings shouldn't be nil")
                XCTAssertNil(error, "There should be no error")

                let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: file!.id)
                XCTAssertNotNil(cached, "Cached dropbox shouldn't be nil")
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
                XCTAssertNotNil(file, "Office file shouldn't be nil")
                XCTAssertNil(error, "There should be no error")

                let cached = DriveFileManagerTests.driveFileManager.getCachedFile(id: file!.id)
                XCTAssertNotNil(cached, "Office file shouldn't be nil")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: DriveFileManagerTests.defaultTimeout)
        tearDownTest(directory: rootFile)
    }

}
