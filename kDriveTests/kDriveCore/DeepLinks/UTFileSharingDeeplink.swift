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
import InfomaniakCore
@testable import kDriveCore
import XCTest

final class UTFileSharingDeeplink: XCTestCase {
    private let fileManager = FileManager.default
    private var testRootURL: URL!
    private var sharedContainerURL: URL!
    private var handoffRootURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testRootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        sharedContainerURL = testRootURL.appendingPathComponent("shared", isDirectory: true)
        handoffRootURL = KDriveFileSharing.handoffDirectoryURL(in: sharedContainerURL)
        try fileManager.createDirectory(at: handoffRootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: testRootURL)
        try super.tearDownWithError()
    }

    func testAcceptsRegularFileFromHandoffDirectory() throws {
        let sourceURL = try createSourceFile()

        let deeplinkURL = try makeURL(for: sourceURL)
        let files = DeeplinkParser(sharedContainerURL: sharedContainerURL).filesForSharingDeeplink(deeplinkURL)

        XCTAssertEqual(files?.count, 1)
        XCTAssertEqual(files?.first?.name, sourceURL.lastPathComponent)
        XCTAssertEqual(files?.first?.path, sourceURL)
    }

    func testRejectsWrongRoute() throws {
        let sourceURL = try createSourceFile()
        let parser = DeeplinkParser(sharedContainerURL: sharedContainerURL)

        let wrongSchemeURL = try makeURL(for: sourceURL, scheme: "kdrive")
        let wrongHostURL = try makeURL(for: sourceURL, host: "other")

        XCTAssertNil(parser.filesForSharingDeeplink(wrongSchemeURL))
        XCTAssertNil(parser.filesForSharingDeeplink(wrongHostURL))
    }

    func testRejectsFileOutsideHandoffDirectory() throws {
        let outsideURL = testRootURL.appendingPathComponent("outside.txt")
        try Data().write(to: outsideURL)

        let deeplinkURL = try makeURL(for: outsideURL)
        let files = DeeplinkParser(sharedContainerURL: sharedContainerURL).filesForSharingDeeplink(deeplinkURL)

        XCTAssertNil(files)
    }

    func testRejectsSymlinkEscapingHandoffDirectory() throws {
        let outsideURL = testRootURL.appendingPathComponent("outside.txt")
        try Data().write(to: outsideURL)
        let symlinkURL = try createHandoffDirectory().appendingPathComponent("link.txt")
        try fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideURL)

        let deeplinkURL = try makeURL(for: symlinkURL)
        let files = DeeplinkParser(sharedContainerURL: sharedContainerURL).filesForSharingDeeplink(deeplinkURL)

        XCTAssertNil(files)
    }

    func testRejectsDirectory() throws {
        let directoryURL = try createHandoffDirectory().appendingPathComponent("folder", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: false)

        let deeplinkURL = try makeURL(for: directoryURL)
        let files = DeeplinkParser(sharedContainerURL: sharedContainerURL).filesForSharingDeeplink(deeplinkURL)

        XCTAssertNil(files)
    }

    private func createHandoffDirectory() throws -> URL {
        let directoryURL = handoffRootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        return directoryURL
    }

    private func createSourceFile() throws -> URL {
        let sourceURL = try createHandoffDirectory().appendingPathComponent("file.txt")
        try Data("content".utf8).write(to: sourceURL)
        return sourceURL
    }

    private func makeURL(
        for sourceURL: URL,
        scheme: String = KDriveFileSharing.scheme,
        host: String = KDriveFileSharing.host
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: KDriveFileSharing.urlQueryItemName, value: sourceURL.path)]
        return try XCTUnwrap(components.url)
    }
}
