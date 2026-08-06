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
import XCTest

final class UTFileSharingImporter: XCTestCase {
    private let fileManager = FileManager.default
    private var testRootURL: URL!
    private var handoffRootURL: URL!
    private var stagingRootURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testRootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        handoffRootURL = testRootURL.appendingPathComponent("shared/Library/Caches/file-sharing", isDirectory: true)
        stagingRootURL = testRootURL.appendingPathComponent("drive/import", isDirectory: true)
        try fileManager.createDirectory(at: handoffRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: testRootURL)
        try super.tearDownWithError()
    }

    func testImportsRegularFileIntoKDriveOwnedStaging() async throws {
        let sourceURL = try createSourceFile(name: "facture été.txt", data: Data("content".utf8))
        let importer = makeImporter { "staged" }

        let files = try await importer.importFiles(from: makeURL(paths: [sourceURL.path]))

        let file = try XCTUnwrap(files.first)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(file.name, "facture été.txt")
        XCTAssertEqual(file.path.deletingLastPathComponent(), stagingRootURL)
        XCTAssertNotEqual(file.path, sourceURL)
        XCTAssertEqual(try Data(contentsOf: file.path), Data("content".utf8))
        XCTAssertTrue(fileManager.fileExists(atPath: sourceURL.path))
    }

    func testPreservesLiteralPercentAndFragmentCharactersInFileName() async throws {
        let sourceURL = try createSourceFile(name: "100%#final.txt")

        let files = try await makeImporter().importFiles(from: makeURL(paths: [sourceURL.path]))

        XCTAssertEqual(files.first?.name, "100%#final.txt")
    }

    func testRejectsWrongRoutes() async throws {
        let sourceURL = try createSourceFile(name: "file.txt")
        let routes = try [
            makeURL(paths: [sourceURL.path], scheme: "kdrive"),
            makeURL(paths: [sourceURL.path], host: "other"),
            makeURL(paths: [sourceURL.path], path: "/unexpected"),
            makeURL(paths: [sourceURL.path], fragment: "fragment")
        ]

        for route in routes {
            await assertImportError(.invalidRoute) {
                try await makeImporter().importFiles(from: route)
            }
        }
    }

    func testRejectsUnexpectedAndMissingQueryValues() async throws {
        var unknownQuery = URLComponents()
        unknownQuery.scheme = FileSharingImporter.scheme
        unknownQuery.host = FileSharingImporter.host
        unknownQuery.queryItems = [URLQueryItem(name: "path", value: "/tmp/file")]

        var missingValue = URLComponents()
        missingValue.scheme = FileSharingImporter.scheme
        missingValue.host = FileSharingImporter.host
        missingValue.queryItems = [URLQueryItem(name: "url", value: nil)]

        await assertImportError(.invalidQuery) {
            try await makeImporter().importFiles(from: XCTUnwrap(unknownQuery.url))
        }
        await assertImportError(.invalidQuery) {
            try await makeImporter().importFiles(from: XCTUnwrap(missingValue.url))
        }
    }

    func testDecodesQueryExactlyOnce() async throws {
        let url = try XCTUnwrap(URL(string: "kdrive-file-sharing://file?url=%252Ftmp%252Fsecret.txt"))

        await assertImportError(.invalidPath) {
            try await makeImporter().importFiles(from: url)
        }
    }

    func testRejectsPathsOutsideRootIncludingCommonPrefixSibling() async throws {
        let outsideURL = testRootURL.appendingPathComponent("outside.txt")
        try Data().write(to: outsideURL)

        let siblingRootURL = URL(fileURLWithPath: handoffRootURL.path + "-other", isDirectory: true)
        try fileManager.createDirectory(at: siblingRootURL, withIntermediateDirectories: true)
        let siblingURL = siblingRootURL.appendingPathComponent("file.txt")
        try Data().write(to: siblingURL)

        for sourceURL in [outsideURL, siblingURL] {
            await assertImportError(.sourceOutsideHandoffRoot) {
                try await makeImporter().importFiles(from: makeURL(paths: [sourceURL.path]))
            }
        }
    }

    func testRejectsInvalidHandoffLayout() async throws {
        let invalidDirectoryURL = handoffRootURL.appendingPathComponent("not-a-uuid", isDirectory: true)
        try fileManager.createDirectory(at: invalidDirectoryURL, withIntermediateDirectories: true)
        let sourceURL = invalidDirectoryURL.appendingPathComponent("file.txt")
        try Data().write(to: sourceURL)

        await assertImportError(.invalidHandoffLayout) {
            try await makeImporter().importFiles(from: makeURL(paths: [sourceURL.path]))
        }
    }

    func testRejectsDirectoryAndSymlink() async throws {
        let handoffDirectoryURL = try createHandoffDirectory()
        let directoryURL = handoffDirectoryURL.appendingPathComponent("folder", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let targetURL = testRootURL.appendingPathComponent("target.txt")
        try Data().write(to: targetURL)
        let symlinkURL = handoffDirectoryURL.appendingPathComponent("link.txt")
        try fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: targetURL)

        for sourceURL in [directoryURL, symlinkURL] {
            await assertImportError(.unsupportedFile) {
                try await makeImporter().importFiles(from: makeURL(paths: [sourceURL.path]))
            }
        }
    }

    func testRejectsSymlinkedHandoffRoot() async throws {
        let actualRootURL = testRootURL.appendingPathComponent("actual-file-sharing", isDirectory: true)
        try fileManager.createDirectory(at: actualRootURL, withIntermediateDirectories: true)
        try fileManager.removeItem(at: handoffRootURL)
        try fileManager.createSymbolicLink(at: handoffRootURL, withDestinationURL: actualRootURL)

        let handoffDirectoryURL = actualRootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: handoffDirectoryURL, withIntermediateDirectories: true)
        let actualSourceURL = handoffDirectoryURL.appendingPathComponent("file.txt")
        try Data().write(to: actualSourceURL)
        let suppliedSourceURL = handoffRootURL
            .appendingPathComponent(handoffDirectoryURL.lastPathComponent, isDirectory: true)
            .appendingPathComponent(actualSourceURL.lastPathComponent)

        await assertImportError(.unsupportedFile) {
            try await makeImporter().importFiles(from: makeURL(paths: [suppliedSourceURL.path]))
        }
    }

    func testRejectsDuplicateCanonicalPaths() async throws {
        let sourceURL = try createSourceFile(name: "file.txt")

        await assertImportError(.duplicateFile) {
            try await makeImporter().importFiles(from: makeURL(paths: [sourceURL.path, sourceURL.path]))
        }
    }

    func testEnforcesFileCountAndSizeLimits() async throws {
        let firstURL = try createSourceFile(name: "first.txt", data: Data(repeating: 0, count: 3))
        let secondURL = try createSourceFile(name: "second.txt", data: Data(repeating: 0, count: 3))

        await assertImportError(.tooManyFiles) {
            let limits = FileSharingImporter.Limits(
                maximumFileCount: 1,
                maximumFileSize: 10,
                maximumAggregateSize: 10,
                freeSpaceReserve: 0
            )
            _ = try await makeImporter(limits: limits).importFiles(from: makeURL(paths: [firstURL.path, secondURL.path]))
        }

        await assertImportError(.fileTooLarge) {
            let limits = FileSharingImporter.Limits(
                maximumFileCount: 2,
                maximumFileSize: 2,
                maximumAggregateSize: 10,
                freeSpaceReserve: 0
            )
            _ = try await makeImporter(limits: limits).importFiles(from: makeURL(paths: [firstURL.path]))
        }

        await assertImportError(.aggregateSizeExceeded) {
            let limits = FileSharingImporter.Limits(
                maximumFileCount: 2,
                maximumFileSize: 3,
                maximumAggregateSize: 5,
                freeSpaceReserve: 0
            )
            _ = try await makeImporter(limits: limits).importFiles(from: makeURL(paths: [firstURL.path, secondURL.path]))
        }
    }

    func testRejectsImportWhenStagingCapacityIsInsufficient() async throws {
        let sourceURL = try createSourceFile(name: "file.txt", data: Data(repeating: 0, count: 3))
        let importer = makeImporter { _ in 2 }

        await assertImportError(.insufficientSpace) {
            try await importer.importFiles(from: makeURL(paths: [sourceURL.path]))
        }
    }

    func testValidatesWholeRequestBeforeStaging() async throws {
        let validURL = try createSourceFile(name: "valid.txt")
        let invalidURL = testRootURL.appendingPathComponent("outside.txt")
        try Data().write(to: invalidURL)

        await assertImportError(.sourceOutsideHandoffRoot) {
            try await makeImporter().importFiles(from: makeURL(paths: [validURL.path, invalidURL.path]))
        }
        XCTAssertTrue(try fileManager.contentsOfDirectory(atPath: stagingRootURL.path).isEmpty)
    }

    func testRollsBackStagingIfACopyFails() async throws {
        let firstURL = try createSourceFile(name: "first.txt")
        let secondURL = try createSourceFile(name: "second.txt")
        let importer = makeImporter { "same-identifier" }

        await assertImportError(.stagingFailed) {
            try await importer.importFiles(from: makeURL(paths: [firstURL.path, secondURL.path]))
        }
        XCTAssertTrue(try fileManager.contentsOfDirectory(atPath: stagingRootURL.path).isEmpty)
        XCTAssertTrue(fileManager.fileExists(atPath: firstURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: secondURL.path))
    }

    private func makeImporter(
        limits: FileSharingImporter.Limits = FileSharingImporter.Limits(
            maximumFileCount: 3,
            maximumFileSize: 1024,
            maximumAggregateSize: 2048,
            freeSpaceReserve: 0
        ),
        makeIdentifier: @escaping () -> String = { UUID().uuidString }
    ) -> FileSharingImporter {
        return FileSharingImporter(
            fileManager: fileManager,
            sharedContainerURL: testRootURL.appendingPathComponent("shared", isDirectory: true),
            stagingRootURL: stagingRootURL,
            limits: limits,
            makeIdentifier: makeIdentifier
        )
    }

    private func makeImporter(
        availableCapacity: @escaping (URL) throws -> UInt64
    ) -> FileSharingImporter {
        return FileSharingImporter(
            fileManager: fileManager,
            sharedContainerURL: testRootURL.appendingPathComponent("shared", isDirectory: true),
            stagingRootURL: stagingRootURL,
            limits: FileSharingImporter.Limits(
                maximumFileCount: 3,
                maximumFileSize: 1024,
                maximumAggregateSize: 2048,
                freeSpaceReserve: 0
            ),
            availableCapacity: availableCapacity
        )
    }

    private func createHandoffDirectory() throws -> URL {
        let directoryURL = handoffRootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func createSourceFile(name: String, data: Data = Data()) throws -> URL {
        let sourceURL = try createHandoffDirectory().appendingPathComponent(name)
        try data.write(to: sourceURL)
        return sourceURL
    }

    private func makeURL(
        paths: [String],
        scheme: String = FileSharingImporter.scheme,
        host: String = FileSharingImporter.host,
        path: String = "",
        fragment: String? = nil
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.fragment = fragment
        components.queryItems = paths.map { URLQueryItem(name: "url", value: $0) }
        return try XCTUnwrap(components.url)
    }

    private func assertImportError<T>(
        _ expectedError: FileSharingImportError,
        operation: () async throws -> T
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected \(expectedError)")
        } catch {
            XCTAssertEqual(error as? FileSharingImportError, expectedError)
        }
    }
}
