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

@Suite("UTFilePreviewLink")
struct UTFilePreviewLink {
    @Test("Parse driveId, folderId and fileId from a filePreview link", arguments: [(1_982_302, 6_437_290, 293_980_483)])
    func parseFilePreviewLink(driveId: Int, folderId: Int, fileId: Int) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/files/\(folderId)/preview/image/\(fileId)"

        guard let url = URL(string: givenLink), let parsedResult = FilePreviewLink(filePreviewURL: url) else {
            Issue.record("Failed to parse the URL")
            return
        }

        #expect(parsedResult.filePreviewURL == url)
        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.folderId == folderId)
        #expect(parsedResult.fileId == fileId)
    }

    @Test("Fail to parse a deeplink to a file filePreview if the URL is invalid", arguments: [
        ("", "29823", "32342"),
        ("43908", "", "62042"),
        ("39424", "221290", ""),
        ("foo", "", "bar"),
        ("13292", "2329429", "10931ab")

    ])
    func filePreviewLinkInvalidURL(driveId: String, folderId: String, fileId: String) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/files/\(folderId)/preview/image/\(fileId)"

        guard let url = URL(string: givenLink) else {
            Issue.record("Failed to create URL")
            return
        }

        let parsedResult = FilePreviewLink(filePreviewURL: url)
        #expect(parsedResult == nil)
    }
}
