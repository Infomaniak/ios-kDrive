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

@Suite("UTTrashLink")
struct UTTrashLink {
    @Test("Parse the driveId of a deeplink to the trash", arguments: [123_456])
    func trashLinkRoot(driveId: Int) throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/trash"
        guard let url = URL(string: givenLink),
              let parsedResult = TrashLink(trashURL: url) else {
            Issue.record("Failed to parse URL")
            return
        }

        #expect(parsedResult.trashURL == url)
        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.folderId == nil)
    }

    @Test("Parse the driveId and the folderId of a deeplink to the trash", arguments: zip([123_456], [8_763_402]))
    func trashLinkFolder(driveId: Int, folderId: Int) throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/trash/\(folderId)"
        guard let url = URL(string: givenLink), let parsedResult = TrashLink(trashURL: url) else {
            Issue.record("Failed to parse URL")
            return
        }

        #expect(parsedResult.trashURL == url)
        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.folderId == folderId)
    }

    @Test("Fail to parse a deeplink to the trash if the URL is invalid", arguments: ["834FAE21-1D5C"])
    func trashLinkInvalidURL(_ invalidDriveId: String) throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(invalidDriveId)/trash"
        guard let url = URL(string: givenLink) else {
            Issue.record("Failed to create URL")
            return
        }

        #expect(TrashLink(trashURL: url) == nil)
    }
}
