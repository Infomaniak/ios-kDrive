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

@Suite("UTBasicLink")
struct UTBasicLink {
    @Test(
        "Parse the driveId of a link to a basic tab",
        arguments: zip(
            [192_834, 2_932_094, 392_842, 298_232],
            ["recents", "trash", "favorites", "my-shares"]
        )
    )
    func parseBasicLinkRoot(driveId: Int, destination: String) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/\(destination)"

        guard let url = URL(string: givenLink), let parsedResult = BasicLink(basicURL: url) else {
            Issue.record("Failed to parse the URL")
            return
        }

        #expect(parsedResult.basicURL == url)
        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.destination.rawValue == destination)
    }

    @Test("Parse the driveId and the fileId of a link to a basic tab", arguments: [
        (732_322, "trash", 294_394_394),
        (293_823, "my-shares", 9_033_242)
    ])
    func parseBasicLinkFile(driveId: Int, destination: String, fileId: Int) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(driveId)/\(destination)/preview/image/\(fileId)"

        guard let url = URL(string: givenLink), let parsedResult = BasicLink(basicURL: url) else {
            Issue.record("Failed to parse the URL")
            return
        }

        #expect(parsedResult.basicURL == url)
        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.destination.rawValue == destination)
        #expect(parsedResult.fileId == fileId)
    }

    @Test("Fail to parse a deeplink to a basic tab if the URL is invalid", arguments: ["AD49-243DV-3DB"])
    func basicLinkInvalidURL(invalidDriveId: String) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/\(invalidDriveId)/recents"

        guard let url = URL(string: givenLink) else {
            Issue.record("Failed to create the URL")
            return
        }

        let parsedResult = BasicLink(basicURL: url)
        #expect(parsedResult == nil)
    }

    @Test("Fail to parse a deeplink to a basic tab if the destination is invalid", arguments: ["home", "publicShares"])
    func invalidDestinationURL(invalidDestination: String) async throws {
        let givenLink = "https://ksuite.infomaniak.com/all/kdrive/app/drive/192834/\(invalidDestination)"

        guard let url = URL(string: givenLink) else {
            Issue.record("Failed to create the URL")
            return
        }

        let parsedResult = BasicLink(basicURL: url)
        #expect(parsedResult == nil)
    }
}
