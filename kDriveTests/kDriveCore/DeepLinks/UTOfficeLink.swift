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
import Testing

@Suite("UTOfficeLink")
struct UTOfficeLink {
    @Test("Parse the driveId and the fileId of an office deeplink", arguments: [123_456], [1_728_394])
    func parseOfficeLink(driveId: Int, fileId: Int) async throws {
        let givenLink = "https://kdrive.infomaniak.com/app/office/\(driveId)/\(fileId)"

        guard let url = URL(string: givenLink), let parsedResult = OfficeLink(officeURL: url) else {
            Issue.record("Failed to parse the URL")
            return
        }

        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.fileId == fileId)
    }

    @Test(
        "Fail to parse a deeplink to an office file if the URL is invalid",
        arguments: zip(["", "12345", "", "23943"], ["", "", "12345", "12983abcd"])
    )
    func failToParseInvalidLink(driveId: String, fileId: String) async throws {
        let givenLink = "https://kdrive.infomaniak.com/app/office/\(driveId)/\(fileId)"

        guard let url = URL(string: givenLink) else {
            Issue.record("Failed to create the URL")
            return
        }

        let parsedResult = OfficeLink(officeURL: url)
        #expect(parsedResult == nil)
    }
}
