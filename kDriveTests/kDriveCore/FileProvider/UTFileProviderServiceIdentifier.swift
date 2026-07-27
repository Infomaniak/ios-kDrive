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

import FileProvider
import kDriveCore
import XCTest

/// Unit tests for `FileProviderService.identifier(for:domain:)`.
///
/// The storage layout served by the File Provider is `<root>/<itemIdentifier>/<filename>`, so the
/// item identifier is always the first path component right after the storage root, whatever the
/// depth of the requested URL (packages, bundles, nested resources…).
final class UTFileProviderServiceIdentifier: XCTestCase {
    private let fileProviderService = FileProviderService()

    /// The root used by the implementation when no domain is provided.
    private var rootStorageURL: URL {
        NSFileProviderManager.default.documentStorageURL
    }

    func testRootStorageURLResolvesToRootContainer() {
        // GIVEN
        let itemURL = rootStorageURL

        // WHEN
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        // THEN
        XCTAssertEqual(identifier, .rootContainer)
    }

    func testDirectChildFileResolvesToItemIdentifier() {
        // GIVEN
        let itemURL = rootStorageURL
            .appendingPathComponent("42", isDirectory: true)
            .appendingPathComponent("document.pdf", isDirectory: false)

        // WHEN
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        // THEN
        XCTAssertEqual(identifier, NSFileProviderItemIdentifier("42"))
    }

    func testItemFolderItselfResolvesToItemIdentifier() {
        // GIVEN the URL points to the item folder itself, without a trailing filename
        let itemURL = rootStorageURL.appendingPathComponent("42", isDirectory: true)

        // WHEN
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        // THEN
        XCTAssertEqual(identifier, NSFileProviderItemIdentifier("42"))
    }

    func testNestedItemURLResolvesToTopLevelItemIdentifier() {
        // GIVEN a URL nested inside a materialized package/bundle
        let itemURL = rootStorageURL
            .appendingPathComponent("42", isDirectory: true)
            .appendingPathComponent("Keynote.key", isDirectory: true)
            .appendingPathComponent("Index")
            .appendingPathComponent("slide.iwa", isDirectory: false)

        // WHEN
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        // THEN the top-level identifier is returned, not one of the inner components
        XCTAssertEqual(identifier, NSFileProviderItemIdentifier("42"))
    }

    func testURLOutsideStorageRootResolvesToNil() {
        // GIVEN a URL that is not contained in the storage root
        let itemURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("not-in-storage", isDirectory: true)
            .appendingPathComponent("file.txt", isDirectory: false)

        // WHEN
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        // THEN
        XCTAssertNil(identifier)
    }

    func testUnnormalizedURLResolvesToItemIdentifier() {
        // GIVEN a URL containing relative components that resolve back inside the storage root
        let itemURL = rootStorageURL
            .appendingPathComponent("42", isDirectory: true)
            .appendingPathComponent("subfolder", isDirectory: true)
            .appendingPathComponent("..", isDirectory: true)
            .appendingPathComponent("document.pdf", isDirectory: false)

        // WHEN
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        // THEN standardization collapses `subfolder/..`, keeping the top-level identifier
        XCTAssertEqual(identifier, NSFileProviderItemIdentifier("42"))
    }
}
