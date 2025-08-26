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

@Suite("UTPublicShareLink")
struct UTPublicShareLink {
    @Test("Parse driveId and fileUid from a publicShare link", arguments: [129_842], ["133b2ea4-e41b-4e4f-a41e-d466e41b133b"])
    func parsePublicShareLink(driveId: Int, fileUid: String) async throws {
        let givenLink = "https://kdrive.infomaniak.com/app/share/\(driveId)/\(fileUid)"

        guard let url = URL(string: givenLink), let parsedResult = PublicShareLink(publicShareURL: url) else {
            Issue.record("Failed to parse the URL")
            return
        }

        #expect(parsedResult.publicShareURL == url)
        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.shareLinkUid == fileUid)
    }

    @Test("Fail to parse a publicShareLink if the URL is invalid", arguments: zip(
        ["", "2894230", "foo", "2393dz-212957-34de2-a29v-d293824"],
        ["1293ad-eo342-4321-a321-e321e321e321", "", "24239824", "2324ac3-a48v-43d3-a243-d234e23"]

    ))
    func publicShareLinkInvalidURL(driveId: String, fileUid: String) async throws {
        let givenLink = "https://kdrive.infomaniak.com/app/share/\(driveId)/\(fileUid)"

        guard let url = URL(string: givenLink) else {
            Issue.record("Failed to create URL")
            return
        }

        let parsedResult = PublicShareLink(publicShareURL: url)
        #expect(parsedResult == nil)
    }
}
