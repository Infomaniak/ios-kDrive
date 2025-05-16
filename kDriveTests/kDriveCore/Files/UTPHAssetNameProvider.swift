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

@testable import kDriveCore
import Photos
import XCTest

/// Unit tests of image asset name generation
final class UTPHAssetNameProvider: XCTestCase {
    override func setUp() {
        MockingHelper.clearRegisteredTypes()
        MockingHelper.registerConcreteTypes(configuration: .minimal)
    }

    // MARK: - Fallback Name

    func testDefaultName() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let now = Date()
        let formattedNowDate = URL.defaultFileName(date: now)
        let defaultPrefix = "No-name-"
        let fileExtension = "exe"

        let expectedFormat = "\(defaultPrefix)\(formattedNowDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: nil,
                                            creationDate: nil,
                                            modificationDate: nil,
                                            burstCount: nil,
                                            burstIdentifier: nil,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testEmptyOriginalFilename() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let defaultPrefix = "No-name-"
        let emptyFileName = ""
        let fileExtension = "exe"
        let now = Date()
        let formattedNowDate = URL.defaultFileName(date: now)

        let expectedFormat = "\(defaultPrefix)\(formattedNowDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: emptyFileName,
                                            creationDate: nil,
                                            modificationDate: nil,
                                            burstCount: nil,
                                            burstIdentifier: nil,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testDefaultNameWithNonZeroBursts() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let defaultPrefix = "No-name-"
        let fileExtension = "exe"
        let burstCount = 1337
        let burstIdentifier = "cafebabe"
        let now = Date()
        let formattedNowDate = URL.defaultFileName(date: now)

        let expectedFormat = "\(defaultPrefix)\(formattedNowDate)_\(burstCount).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: nil,
                                            creationDate: nil,
                                            modificationDate: nil,
                                            burstCount: burstCount,
                                            burstIdentifier: burstIdentifier,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testDefaultNameWithZeroBursts() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let defaultPrefix = "No-name-"
        let fileExtension = "exe"
        let burstCount = 0
        let burstIdentifier = "cafebabe"
        let now = Date()
        let formattedNowDate = URL.defaultFileName(date: now)

        let expectedFormat = "\(defaultPrefix)\(formattedNowDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: nil,
                                            creationDate: nil,
                                            modificationDate: nil,
                                            burstCount: burstCount,
                                            burstIdentifier: burstIdentifier,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testDefaultNameWithNonZeroBurstsEmptyBurstIdentifier() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let defaultPrefix = "No-name-"
        let fileExtension = "exe"
        let burstCount = 1337
        let now = Date()
        let formattedNowDate = URL.defaultFileName(date: now)

        let expectedFormat = "\(defaultPrefix)\(formattedNowDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: nil,
                                            creationDate: nil,
                                            modificationDate: nil,
                                            burstCount: burstCount,
                                            burstIdentifier: nil,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testDefaultNameWithNonZeroBurstsNilBurstIdentifier() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let defaultPrefix = "No-name-"
        let fileExtension = "exe"
        let burstCount = 1337
        let burstIdentifier = ""
        let now = Date()
        let formattedNowDate = URL.defaultFileName(date: now)

        let expectedFormat = "\(defaultPrefix)\(formattedNowDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: nil,
                                            creationDate: nil,
                                            modificationDate: nil,
                                            burstCount: burstCount,
                                            burstIdentifier: burstIdentifier,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testModifiedPictureNoCreationDate() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let defaultPrefix = "No-name-"
        let fileWithModificationsFilename = "FullSizeRender"
        let fileExtension = "exe"
        let now = Date()
        let formattedNowDate = PHAssetNameProvider.fileNameDateFormatter.string(from: now)

        let expectedFormat = "\(defaultPrefix)\(formattedNowDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileWithModificationsFilename,
                                            creationDate: nil,
                                            modificationDate: nil,
                                            burstCount: nil,
                                            burstIdentifier: nil,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testModifiedPictureNoCreationDateModificationDate() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let defaultPrefix = "No-name-"
        let fileExtension = "exe"
        let fileWithModificationsFilename = "FullSizeRender"
        let now = Date()
        let modificationDate = Date(timeIntervalSince1970: 1337)
        let formattedModificationDate = PHAssetNameProvider.fileNameDateFormatter.string(from: modificationDate)

        let expectedFormat = "\(defaultPrefix)\(formattedModificationDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileWithModificationsFilename,
                                            creationDate: nil,
                                            modificationDate: modificationDate,
                                            burstCount: nil,
                                            burstIdentifier: nil,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    // MARK: - Modified assets

    func testModifiedPicture() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let fileExtension = "exe"
        let fileWithModificationsFilename = "FullSizeRender"
        let now = Date()
        let creationDate = Date(timeIntervalSince1970: 69)
        let formattedCreationDate = PHAssetNameProvider.fileNameDateFormatter.string(from: creationDate)
        let modificationDate = Date(timeIntervalSince1970: 420)
        let formattedModificationDate = PHAssetNameProvider.fileNameDateFormatter.string(from: modificationDate)

        let expectedFormat = "\(formattedCreationDate)-\(formattedModificationDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileWithModificationsFilename,
                                            creationDate: creationDate,
                                            modificationDate: modificationDate,
                                            burstCount: nil,
                                            burstIdentifier: nil,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testModifiedPictureWithNonZeroBursts() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let fileExtension = "exe"
        let fileWithModificationsFilename = "FullSizeRender"
        let burstCount = 1337
        let burstIdentifier = "cafebabe"

        let now = Date()
        let creationDate = Date(timeIntervalSince1970: 69)
        let modificationDate = Date(timeIntervalSince1970: 420)

        let expectedFormat =
            "\(PHAssetNameProvider.fileNameDateFormatter.string(from: creationDate))-\(PHAssetNameProvider.fileNameDateFormatter.string(from: modificationDate))_\(burstCount).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileWithModificationsFilename,
                                            creationDate: creationDate,
                                            modificationDate: modificationDate,
                                            burstCount: burstCount,
                                            burstIdentifier: burstIdentifier,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testModifiedPictureWithZeroBursts() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let fileExtension = "exe"
        let fileWithModificationsFilename = "FullSizeRender"
        let burstCount = 0
        let burstIdentifier = "cafebabe"

        let now = Date()
        let creationDate = Date(timeIntervalSince1970: 69)
        let modificationDate = Date(timeIntervalSince1970: 420)

        let expectedFormat =
            "\(PHAssetNameProvider.fileNameDateFormatter.string(from: creationDate))-\(PHAssetNameProvider.fileNameDateFormatter.string(from: modificationDate)).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileWithModificationsFilename,
                                            creationDate: creationDate,
                                            modificationDate: modificationDate,
                                            burstCount: burstCount,
                                            burstIdentifier: burstIdentifier,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testModifiedPictureWithNonZeroBurstsEmptyBurstIdentifier() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let fileExtension = "exe"
        let fileWithModificationsFilename = "FullSizeRender"
        let burstCount = 1337
        let burstIdentifier = ""

        let now = Date()
        let creationDate = Date(timeIntervalSince1970: 69)
        let modificationDate = Date(timeIntervalSince1970: 420)

        let expectedFormat =
            "\(PHAssetNameProvider.fileNameDateFormatter.string(from: creationDate))-\(PHAssetNameProvider.fileNameDateFormatter.string(from: modificationDate)).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileWithModificationsFilename,
                                            creationDate: creationDate,
                                            modificationDate: modificationDate,
                                            burstCount: burstCount,
                                            burstIdentifier: burstIdentifier,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testModifiedPictureWithNonZeroBurstsNilBurstIdentifier() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let fileExtension = "exe"
        let fileWithModificationsFilename = "FullSizeRender"
        let burstCount = 1337

        let now = Date()
        let creationDate = Date(timeIntervalSince1970: 69)
        let modificationDate = Date(timeIntervalSince1970: 420)

        let expectedFormat =
            "\(PHAssetNameProvider.fileNameDateFormatter.string(from: creationDate))-\(PHAssetNameProvider.fileNameDateFormatter.string(from: modificationDate)).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileWithModificationsFilename,
                                            creationDate: creationDate,
                                            modificationDate: modificationDate,
                                            burstCount: burstCount,
                                            burstIdentifier: nil,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    // MARK: - Asset no modification

    func testNotModifiedPicture() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let fileExtension = "exe"
        let fileOriginalFilename = "DSC-30032"
        let now = Date()
        let creationDate = Date(timeIntervalSince1970: 69)
        let formattedCreationDate = PHAssetNameProvider.fileNameDateFormatter.string(from: creationDate)

        let expectedFormat = "\(formattedCreationDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileOriginalFilename,
                                            creationDate: creationDate,
                                            modificationDate: nil,
                                            burstCount: nil,
                                            burstIdentifier: nil,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testNotModifiedPictureWithNonZeroBursts() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let fileExtension = "exe"
        let fileOriginalFilename = "DSC-30032"
        let burstCount = 1337
        let burstIdentifier = "cafebabe"
        let now = Date()
        let creationDate = Date(timeIntervalSince1970: 69)
        let formattedCreationDate = PHAssetNameProvider.fileNameDateFormatter.string(from: creationDate)

        let expectedFormat = "\(formattedCreationDate)_\(burstCount).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileOriginalFilename,
                                            creationDate: creationDate,
                                            modificationDate: nil,
                                            burstCount: burstCount,
                                            burstIdentifier: burstIdentifier,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testNotModifiedPictureWithNonZeroBurstsEmptyBurstIdentifier() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let fileExtension = "exe"
        let fileOriginalFilename = "DSC-30032"
        let burstCount = 1337
        let burstIdentifier = ""
        let now = Date()
        let creationDate = Date(timeIntervalSince1970: 69)
        let formattedCreationDate = PHAssetNameProvider.fileNameDateFormatter.string(from: creationDate)

        let expectedFormat = "\(formattedCreationDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileOriginalFilename,
                                            creationDate: creationDate,
                                            modificationDate: nil,
                                            burstCount: burstCount,
                                            burstIdentifier: burstIdentifier,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testNotModifiedPictureWithNonZeroBurstsNilBurstIdentifier() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let fileExtension = "exe"
        let fileOriginalFilename = "DSC-30032"
        let burstCount = 1337
        let now = Date()
        let creationDate = Date(timeIntervalSince1970: 69)
        let formattedCreationDate = PHAssetNameProvider.fileNameDateFormatter.string(from: creationDate)

        let expectedFormat = "\(formattedCreationDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileOriginalFilename,
                                            creationDate: creationDate,
                                            modificationDate: nil,
                                            burstCount: burstCount,
                                            burstIdentifier: nil,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    func testNotModifiedPictureWithZeroBursts() {
        // GIVEN
        let nameProvider = PHAssetNameProvider()
        let fileExtension = "exe"
        let fileOriginalFilename = "DSC-30032"
        let burstCount = 0
        let burstIdentifier = "cafebabe"
        let now = Date()
        let creationDate = Date(timeIntervalSince1970: 69)
        let formattedCreationDate = PHAssetNameProvider.fileNameDateFormatter.string(from: creationDate)

        let expectedFormat = "\(formattedCreationDate).\(fileExtension)"

        // WHEN
        let name = nameProvider.getFilename(fileExtension: fileExtension,
                                            originalFilename: fileOriginalFilename,
                                            creationDate: creationDate,
                                            modificationDate: nil,
                                            burstCount: burstCount,
                                            burstIdentifier: burstIdentifier,
                                            now: now)

        // THEN
        XCTAssertEqual(name, expectedFormat)
    }

    // MARK: - Date formatter checks

    func testFileNameDateFormatter() {
        // GIVEN
        let primaryDate = Date(timeIntervalSince1970: 2_357_111_317)

        // WHEN
        let formattedDate = PHAssetNameProvider.fileNameDateFormatter.string(from: primaryDate)

        // THEN
        XCTAssertEqual(formattedDate, "20440910_110837_0000")
    }

    func testURLFileNameDateFormatter() {
        // GIVEN
        let primaryDate = Date(timeIntervalSince1970: 2_357_111_317)

        // WHEN
        let formattedDate = URL.defaultFileName(date: primaryDate)

        // THEN
        XCTAssertEqual(formattedDate, "20440910_11083700")
    }
}
