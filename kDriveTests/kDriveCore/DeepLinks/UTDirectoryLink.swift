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

@Suite("UTDirectoryLink")
struct UTDirectoryLink {
    @Test("Parse the driveId and the folderId of a directory deeplink", arguments: [199_230], [52_930_495])
    func parseDirectoryLink(driveId: Int, folderId: Int) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/files/\(folderId)"

        guard let url = URL(string: givenLink), let parsedResult = DirectoryLink(directoryURL: url) else {
            Issue.record("Failed to parse the URL")
            return
        }

        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.folderId == folderId)
    }

    @Test(
        "Fail to parse a deeplink to a directory if the URL is invalid",
        arguments: zip(["", "138202", "", "20934394"], ["", "", "23423499", "238409ab"])
    )
    func failToParseInvalidLink(driveId: String, folderId: String) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/files/\(folderId)"

        guard let url = URL(string: givenLink) else {
            Issue.record("Failed to create the URL")
            return
        }

        let parsedResult = DirectoryLink(directoryURL: url)
        #expect(parsedResult == nil)
    }
}
