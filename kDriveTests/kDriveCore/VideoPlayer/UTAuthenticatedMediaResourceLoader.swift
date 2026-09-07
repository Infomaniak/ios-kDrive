/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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
@testable import kDriveCore
import Testing

@Suite("Authenticated media resource loader")
struct UTAuthenticatedMediaResourceLoader {
    @Test("Wrap and unwrap an HTTPS media endpoint")
    func wrapAndUnwrapURL() throws {
        let sourceURL = try #require(URL(string: "https://api.kdrive.infomaniak.com/2/drive/1/files/2/download"))
        let wrappedURL = try #require(AuthenticatedMediaResourceLoader.wrap(sourceURL))

        #expect(wrappedURL.scheme == "kdrive-authenticated-media")
        #expect(AuthenticatedMediaResourceLoader.unwrap(wrappedURL) == sourceURL)
    }

    @Test("Accept kDrive download hosts", arguments: [
        "https://1-6-v3-11.download.kdrive.infomaniakusercontent.com/file",
        "https://storage.download.kdrive.infomaniakusercontent.com:443/file"
    ])
    func acceptDownloadHost(rawURL: String) throws {
        let url = try #require(URL(string: rawURL))

        #expect(AuthenticatedMediaResourceLoader.isAllowed(url))
    }

    @Test("Reject untrusted download URLs", arguments: [
        "http://1-6-v3-11.download.kdrive.infomaniakusercontent.com/file",
        "https://download.kdrive.infomaniakusercontent.com/file",
        "https://evildownload.kdrive.infomaniakusercontent.com/file",
        "https://1-6-v3-11.download.kdrive.infomaniakusercontent.com.attacker.example/file",
        "https://1-6-v3-11.download.kdrive.infomaniakusercontent.com:8443/file",
        "https://user@1-6-v3-11.download.kdrive.infomaniakusercontent.com/file",
        "https://1-6-v3-11.download.kdrive.infomaniakusercontent.com./file"
    ])
    func rejectUntrustedURL(rawURL: String) throws {
        let url = try #require(URL(string: rawURL))

        #expect(!AuthenticatedMediaResourceLoader.isAllowed(url))
    }
}
