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

@Suite("UTPrivateShareLink")
struct UTPrivateShareLink {
    @Test("Parse driveId and fileId of a deeplink to a private share", arguments: zip(["1634145"], ["234"]))
    func privateShareLink(driveId: String, fileId: String) throws {
        let givenLink = "https://kdrive.infomaniak.com/app/drive/\(driveId)/redirect/\(fileId)"
        guard let url = URL(string: givenLink), let driveIdInt = Int(driveId), let fileIdInt = Int(fileId),
              let parsedResult = PrivateShareLink(privateShareUrl: url) else {
            Issue.record("Failed to parse URL")
            return
        }

        #expect(parsedResult.privateShareUrl == url)
        #expect(parsedResult.driveId == driveIdInt)
        #expect(parsedResult.fileId == fileIdInt)
    }

    @Test(
        "Fail to parse a deeplink to a private share if the URL is invalid",
        arguments: zip(["1D0ZSQ987654321", "1039485", "", "12345"], ["234", "1DKSO2-345", "292", ""])
    )
    func privateShareLinkInvalidURL(_ driveId: String, _ fileId: String) throws {
        let givenLink = "https://kdrive.infomaniak.com/app/drive/\(driveId)/redirect/\(fileId)"
        guard let url = URL(string: givenLink) else {
            Issue.record("Failed to create URL")
            return
        }

        let parsedResult = PrivateShareLink(privateShareUrl: url)
        #expect(parsedResult == nil)
    }
}
