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
import Foundation
import kDriveCore
import Testing

/// Unit tests for `FileProviderService.identifier(for:domain:)`.
///
/// The storage layout served by the File Provider is `<root>/<itemIdentifier>/<filename>`, so the
/// item identifier is always the first path component right after the storage root, whatever the
/// depth of the requested URL (packages, bundles, nested resources…).
@Suite(.serialized)
struct UTFileProviderServiceIdentifier {
    private let fileProviderService = FileProviderService()

    /// The root used by the implementation when no domain is provided.
    private var rootStorageURL: URL {
        NSFileProviderManager.default.documentStorageURL
    }

    @Test("Root storage URL resolves to the root container identifier")
    func rootStorageURLResolvesToRootContainer() {
        let identifier = fileProviderService.identifier(
            for: rootStorageURL,
            domain: nil
        )

        #expect(identifier == .rootContainer)
    }

    @Test("Direct child file resolves to the top-level item identifier")
    func directChildFileResolvesToItemIdentifier() {
        let itemURL = rootStorageURL
            .appendingPathComponent("42", isDirectory: true)
            .appendingPathComponent("document.pdf", isDirectory: false)
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        #expect(identifier == NSFileProviderItemIdentifier("42"))
    }

    @Test("Direct child folder resolves to the top-level item identifier")
    func itemFolderItselfResolvesToItemIdentifier() {
        let itemURL = rootStorageURL.appendingPathComponent("42", isDirectory: true)
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        #expect(identifier == NSFileProviderItemIdentifier("42"))
    }

    @Test("Nested file inside a package resolves to the top-level item identifier")
    func nestedItemURLResolvesToTopLevelItemIdentifier() {
        let itemURL = rootStorageURL
            .appendingPathComponent("42", isDirectory: true)
            .appendingPathComponent("Keynote.key", isDirectory: true)
            .appendingPathComponent("Index")
            .appendingPathComponent("slide.iwa", isDirectory: false)
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        #expect(identifier == NSFileProviderItemIdentifier("42"))
    }

    @Test("URL outside the storage root resolves to nil")
    func uRLOutsideStorageRootResolvesToNil() {
        let itemURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("not-in-storage", isDirectory: true)
            .appendingPathComponent("file.txt", isDirectory: false)
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        #expect(identifier == nil)
    }

    @Test("Unnormalized URL with relative components resolves to the top-level item identifier")
    func unnormalizedURLResolvesToItemIdentifier() {
        let itemURL = rootStorageURL
            .appendingPathComponent("42", isDirectory: true)
            .appendingPathComponent("subfolder", isDirectory: true)
            .appendingPathComponent("..", isDirectory: true)
            .appendingPathComponent("document.pdf", isDirectory: false)
        let identifier = fileProviderService.identifier(for: itemURL, domain: nil)

        #expect(identifier == NSFileProviderItemIdentifier("42"))
    }

    @Test("URL traversing a symbolic link pointing outside the storage root resolves to nil")
    func uRLTraversingSymlinkOutsideStorageReturnsNil() throws {
        let fileManager = FileManager.default
        let itemIdentifier = UUID().uuidString

        let itemDirectoryURL = rootStorageURL
            .appendingPathComponent(itemIdentifier, isDirectory: true)

        let outsideDirectoryURL = rootStorageURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                "outside-\(UUID().uuidString)",
                isDirectory: true
            )

        defer {
            try? fileManager.removeItem(at: itemDirectoryURL)
            try? fileManager.removeItem(at: outsideDirectoryURL)
        }

        try fileManager.createDirectory(
            at: itemDirectoryURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: outsideDirectoryURL,
            withIntermediateDirectories: true
        )

        let outsideFileURL = outsideDirectoryURL
            .appendingPathComponent("private-file.txt", isDirectory: false)

        let outsideContent = Data("Content outside provider storage".utf8)
        try outsideContent.write(to: outsideFileURL)

        // A symbolic link inside the item directory pointing outside storage
        let linkURL = itemDirectoryURL
            .appendingPathComponent("link", isDirectory: false)

        try fileManager.createSymbolicLink(
            at: linkURL,
            withDestinationURL: outsideDirectoryURL
        )

        let itemURL = linkURL
            .appendingPathComponent("private-file.txt", isDirectory: false)

        // Verify that reading through the link reaches the external file
        let linkedContent = try Data(contentsOf: itemURL)
        #expect(linkedContent == outsideContent)

        let identifier = fileProviderService.identifier(
            for: itemURL,
            domain: nil
        )

        #expect(identifier == nil)
    }
}
