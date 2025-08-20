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

@Suite("UTRecentLink")
struct UTRecentLink {
    @Test("Parse the driveId of a link to the recents files", arguments: [192_834])
    func parseRecentLinkRoot(driveId: Int) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/recents"

        guard let url = URL(string: givenLink), let parsedResult = RecentLink(recentURL: url) else {
            Issue.record("Failed to parse the URL")
            return
        }

        #expect(parsedResult.recentURL == url)
        #expect(parsedResult.driveId == driveId)
    }

    @Test("Parse the driveId and the fileId of a link to the recents files", arguments: zip([732_322], [294_394_394]))
    func parseRecentLinkFile(driveId: Int, fileId: Int) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/recents/preview/image/\(fileId)"

        guard let url = URL(string: givenLink), let parsedResult = RecentLink(recentURL: url) else {
            Issue.record("Failed to parse the URL")
            return
        }

        #expect(parsedResult.recentURL == url)
        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.fileId == fileId)
    }

    @Test("Fail to parse a deeplink to the recents files if the URL is invalid", arguments: ["AD49-243DV-3DB"])
    func recentLinkInvalidURL(invalidDriveId: String) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(invalidDriveId)/recents"

        guard let url = URL(string: givenLink) else {
            Issue.record("Failed to create the URL")
            return
        }

        let parsedResult = RecentLink(recentURL: url)
        #expect(parsedResult == nil)
    }
}
