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

@Suite("UTFavoritePreviewLink")
struct UTFavoritePreviewLink {
    @Test("Parse a fav link with a preview", arguments: [
        (1234, 5678, "https://ksuite.infomaniak.com/all/kdrive/app/drive/1234/favorites/preview/pdf/5678"),
        (1234, 5678, "https://ksuite.infomaniak.com/all/kdrive/app/drive/1234/favorites/preview/image/5678")
    ])
    func parseFavoritePreview(driveId: Int, fileId: Int, deeplink: String) async throws {
        // WHEN
        guard let url = URL(string: deeplink),
              let parsedResult = FavoritePreviewLink(inputUrl: url) else {
            Issue.record("Failed to parse the URL")
            return
        }

        // THEN
        #expect(parsedResult.filePreviewURL == url)
        #expect(parsedResult.driveId == driveId)
        #expect(parsedResult.fileId == fileId)
    }

    @Test("Fail to parse a non favorite preview link", arguments: [
        "https://ksuite.infomaniak.com/all/kdrive/app/drive/1234/favorites/preview/noop",
        "https://ksuite.infomaniak.com/all/kdrive/app/drive/123/files/456/preview/pdf/789",
        "https://ksuite.infomaniak.com/all/kdrive/app/drive/123/files/456/preview/image/789",
        "https://ksuite.infomaniak.com/all/kdrive/app/drive/123/favorites",
        "https://ksuite.infomaniak.com/all/kdrive/app/drive/123/files/456",
        "https://kdrive.infomaniak.com/app/office/123/456",
        "https://kdrive.infomaniak.com/app/drive/123/redirect/456"
    ])
    func parseFilePreviewFail(deeplink: String) async throws {
        // WHEN
        guard let url = URL(string: deeplink),
              let parsedResult = FavoritePreviewLink(inputUrl: url) else {
            // THEN
            // success
            return
        }

        Issue.record("This should fail to parse the URL")
    }
}
