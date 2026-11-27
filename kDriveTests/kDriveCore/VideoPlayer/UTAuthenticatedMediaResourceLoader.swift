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
        "https://1-6-v3-11.download.kdrive.infomaniakusercontent.com./file"
    ])
    func rejectUntrustedURL(rawURL: String) throws {
        let url = try #require(URL(string: rawURL))

        #expect(!AuthenticatedMediaResourceLoader.isAllowed(url))
    }

    @Test("Accept the expected source URL", arguments: [
        "https://api.kdrive.infomaniak.com/2/drive/1/files/2/download",
        "https://API.kDrive.Infomaniak.com/2/drive/1/files/2/download"
    ])
    func acceptExpectedSource(rawURL: String) throws {
        let expectedURL = try #require(URL(string: "https://api.kdrive.infomaniak.com/2/drive/1/files/2/download"))
        let url = try #require(URL(string: rawURL))

        #expect(AuthenticatedMediaResourceLoader.isSameResource(url, as: expectedURL))
    }

    @Test("Reject sources other than the expected URL", arguments: [
        "https://attacker.example/2/drive/1/files/2/download",
        "https://api.kdrive.infomaniak.com.attacker.example/2/drive/1/files/2/download",
        "https://api.kdrive.infomaniak.com:8443/2/drive/1/files/2/download",
        "http://api.kdrive.infomaniak.com/2/drive/1/files/2/download",
        "https://api.kdrive.infomaniak.com/2/drive/1/files/3/download",
        "https://api.kdrive.infomaniak.com/2/drive/1/files/2/download?redirect=https://attacker.example"
    ])
    func rejectUnexpectedSource(rawURL: String) throws {
        let expectedURL = try #require(URL(string: "https://api.kdrive.infomaniak.com/2/drive/1/files/2/download"))
        let url = try #require(URL(string: rawURL))

        #expect(!AuthenticatedMediaResourceLoader.isSameResource(url, as: expectedURL))
    }

    @Test("Reject a playlist entry using the custom scheme to reach another host")
    func rejectCustomSchemePlaylistEntry() throws {
        let expectedURL = try #require(URL(string: "https://api.kdrive.infomaniak.com/2/drive/1/files/2/download"))
        let playlistEntry = try #require(URL(string: "kdrive-authenticated-media://attacker.example/segment.ts"))
        let unwrappedURL = try #require(AuthenticatedMediaResourceLoader.unwrap(playlistEntry))

        #expect(!AuthenticatedMediaResourceLoader.isSameResource(unwrappedURL, as: expectedURL))
    }

    @Test("Accept the wrapped expected source after unwrapping")
    func acceptWrappedExpectedSource() throws {
        let expectedURL = try #require(URL(string: "https://api.kdrive.infomaniak.com/2/drive/1/files/2/download"))
        let wrappedURL = try #require(AuthenticatedMediaResourceLoader.wrap(expectedURL))
        let unwrappedURL = try #require(AuthenticatedMediaResourceLoader.unwrap(wrappedURL))

        #expect(AuthenticatedMediaResourceLoader.isSameResource(unwrappedURL, as: expectedURL))
    }
}
