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
@testable import InfomaniakDI
@testable import kDriveCore
import XCTest

final class UTFileSharingDeeplink: XCTestCase {
    private let fileManager = FileManager.default
    private var testRootURL: URL!
    private var handoffRootURL: URL!
    private var stagingRootURL: URL!
    private var router: MCKRouter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        TestTargetAssemblyHelper.clearRegisteredTypes()
        _ = TestTargetAssemblyHelper(configuration: .minimal)

        testRootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        handoffRootURL = testRootURL.appendingPathComponent("shared/Library/Caches/file-sharing", isDirectory: true)
        stagingRootURL = testRootURL.appendingPathComponent("drive/import", isDirectory: true)
        try fileManager.createDirectory(at: handoffRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)

        let importer = FileSharingImporter(
            fileManager: fileManager,
            sharedContainerURL: testRootURL.appendingPathComponent("shared", isDirectory: true),
            stagingRootURL: stagingRootURL,
            limits: FileSharingImporter.Limits(
                maximumFileCount: 3,
                maximumFileSize: 1024,
                maximumAggregateSize: 2048,
                freeSpaceReserve: 0
            )
        )
        SimpleResolver.sharedResolver.store(factory: Factory(type: FileSharingImportable.self) { _, _ in importer })

        router = MCKRouter()
        SimpleResolver.sharedResolver.store(factory: Factory(type: AppNavigable.self) { [router] _, _ in router! })
    }

    override func tearDownWithError() throws {
        TestTargetAssemblyHelper.clearRegisteredTypes()
        try? fileManager.removeItem(at: testRootURL)
        try super.tearDownWithError()
    }

    @MainActor func testExactFileSharingRouteStagesAndNavigates() async throws {
        let sourceURL = try createSourceFile()
        let parser = DeeplinkParser()

        let success = try await parser.parse(url: makeURL(scheme: FileSharingImporter.scheme, sourceURL: sourceURL))

        XCTAssertTrue(success)
        guard case .saveFiles(let files) = router.navigatedRoutes.first else {
            return XCTFail("Expected the save files route")
        }
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].path.deletingLastPathComponent(), stagingRootURL)
        XCTAssertNotEqual(files[0].path, sourceURL)
    }

    @MainActor func testOtherSchemeCannotReachFileImport() async throws {
        let sourceURL = try createSourceFile()
        let parser = DeeplinkParser()

        let success = try await parser.parse(url: makeURL(scheme: "kdrive", sourceURL: sourceURL))

        XCTAssertFalse(success)
        XCTAssertTrue(router.navigatedRoutes.isEmpty)
        XCTAssertTrue(try fileManager.contentsOfDirectory(atPath: stagingRootURL.path).isEmpty)
    }

    private func createSourceFile() throws -> URL {
        let handoffDirectoryURL = handoffRootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: handoffDirectoryURL, withIntermediateDirectories: true)
        let sourceURL = handoffDirectoryURL.appendingPathComponent("file.txt")
        try Data("content".utf8).write(to: sourceURL)
        return sourceURL
    }

    private func makeURL(scheme: String, sourceURL: URL) throws -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = FileSharingImporter.host
        components.queryItems = [URLQueryItem(name: "url", value: sourceURL.path)]
        return try XCTUnwrap(components.url)
    }
}
