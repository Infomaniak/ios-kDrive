/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import kDriveCore
import XCTest

final class UTSharedWithMeLink: XCTestCase {
    func testSharedWithMeRoot() async {
        // GIVEN
        let driveId = 12345
        let urlString = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/shared-with-me"
        let url = URL(string: urlString)!

        // WHEN
        let sharedWithMeLink = await SharedWithMeLink(sharedWithMeURL: url)

        // THEN
        guard let sharedWithMeLink else {
            XCTFail("Parsing should be successful")
            return
        }

        XCTAssertEqual(url, sharedWithMeLink.sharedWithMeURL)
        XCTAssertEqual(driveId, sharedWithMeLink.driveId)
        XCTAssertNil(sharedWithMeLink.fileId)
        XCTAssertNil(sharedWithMeLink.folderId)
        XCTAssertNil(sharedWithMeLink.sharedDriveId)
    }

    func testSharedWithMeFolder() async {
        // GIVEN
        let driveId = 12345
        let sharedDriveId = 140_946
        let folderId = 98765
        let urlString =
            "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/shared-with-me/\(sharedDriveId)/\(folderId)"
        let url = URL(string: urlString)!

        // WHEN
        let sharedWithMeLink = await SharedWithMeLink(sharedWithMeURL: url)

        // THEN
        guard let sharedWithMeLink else {
            XCTFail("Parsing should be successful")
            return
        }

        XCTAssertEqual(url, sharedWithMeLink.sharedWithMeURL)
        XCTAssertEqual(driveId, sharedWithMeLink.driveId)
        XCTAssertEqual(folderId, sharedWithMeLink.folderId)
        XCTAssertEqual(sharedDriveId, sharedWithMeLink.sharedDriveId)
        XCTAssertNil(sharedWithMeLink.fileId)
    }

    func testSharedWithMeFile() async {
        // GIVEN
        let driveId = 12345
        let sharedDriveId = 140_946
        let folderId = 98765
        let fileId = 54321
        let urlString =
            "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/shared-with-me/\(sharedDriveId)/\(folderId)/preview/email/\(fileId)"
        let url = URL(string: urlString)!

        // WHEN
        let sharedWithMeLink = await SharedWithMeLink(sharedWithMeURL: url)

        // THEN
        guard let sharedWithMeLink else {
            XCTFail("Parsing should be successful")
            return
        }

        XCTAssertEqual(url, sharedWithMeLink.sharedWithMeURL)
        XCTAssertEqual(driveId, sharedWithMeLink.driveId)
        XCTAssertEqual(folderId, sharedWithMeLink.folderId)
        XCTAssertEqual(sharedDriveId, sharedWithMeLink.sharedDriveId)
        XCTAssertEqual(fileId, sharedWithMeLink.fileId)
    }

    func testWrongSharedWithMeURL() async {
        // GIVEN
        let urlString = "https://kdrive.infomaniak.com/app/share/123456/834FAE21-1D5C-4D89-BA6A-1622645451E9"
        let url = URL(string: urlString)!

        // WHEN
        let sharedWithMeLink = await SharedWithMeLink(sharedWithMeURL: url)

        // THEN
        XCTAssertNil(sharedWithMeLink, "Expecting parsing to fail")
    }
}
