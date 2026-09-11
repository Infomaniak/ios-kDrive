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

import AppIntents
import AppIntentsTesting
import Foundation
import kDriveCore
import kDriveResources
import XCTest

@available(iOS 27.0, *)
extension AppUITest {
    var definitions: IntentDefinitions {
        IntentDefinitions(bundleIdentifier: "com.infomaniak.drive")
    }

    private func uniqueName(prefix: String) -> String {
        let suffix = UUID().uuidString.prefix(8)
        return "\(prefix)-\(suffix)"
    }

    private func waitForEntity(named name: String, timeout: TimeInterval = 10) async throws -> AnyAppEntity {
        let fileEntityDefinition = definitions.entities["KDriveFileEntity"]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let matches = try await fileEntityDefinition.entities(matching: name)
            if let entity = matches.first {
                return entity
            }

            try await Task.sleep(nanoseconds: 300_000_000)
        }

        XCTFail("Entity named \(name) should be resolvable")
        throw NSError(domain: "DriveAppIntentsTest", code: 1)
    }

    @discardableResult
    func createFolder(named name: String, in parent: AnyAppEntity) async throws -> AnyAppEntity {
        let createFolderIntent = definitions.intents["CreateFolderIntent"]
        let result = try await createFolderIntent
            .makeIntent(fileName: name, target: parent)
            .run()
        return try result.value as AnyAppEntity
    }

    @MainActor
    func testAppIntentCreateFolder() async throws {
        launchAppFromScratch()
        let rootName = setUpTest(testName: uniqueName(prefix: "AppIntentCreateRoot"))
        goToMyFolders()

        let rootEntity = try await waitForEntity(named: rootName)
        let folderName = uniqueName(prefix: "CreatedByIntent")

        _ = try await createFolder(named: folderName, in: rootEntity)

        enterInDirectory(named: rootName)
        XCTAssertTrue(
            app.staticTexts[folderName].waitForExistence(timeout: Self.defaultTimeout),
            "Folder created via CreateFolderIntent should be visible"
        )
    }

    @MainActor
    func testAppIntentMoveFolder() async throws {
        launchAppFromScratch()
        let rootName = setUpTest(testName: uniqueName(prefix: "AppIntentMoveRoot"))
        goToMyFolders()

        let rootEntity = try await waitForEntity(named: rootName)
        let sourceName = uniqueName(prefix: "MoveSource")
        let destinationName = uniqueName(prefix: "MoveDestination")

        let sourceEntity = try await createFolder(named: sourceName, in: rootEntity)
        let destinationEntity = try await createFolder(named: destinationName, in: rootEntity)

        let moveFilesIntent = definitions.intents["MoveFilesIntent"]
        _ = try await moveFilesIntent
            .makeIntent(entities: [sourceEntity], destinationFolder: destinationEntity)
            .run()

        enterInDirectory(named: rootName)
        XCTAssertTrue(app.staticTexts[destinationName].waitForExistence(timeout: 5), "Destination folder should remain visible")
        XCTAssertFalse(app.staticTexts[sourceName].waitForExistence(timeout: 3),
                       "Moved source should not stay in source directory")

        app.staticTexts[destinationName].tap()
        XCTAssertTrue(app.staticTexts[sourceName].waitForExistence(timeout: 5), "Moved folder should be visible in destination")
    }

    @MainActor
    func testAppIntentDeleteFolder() async throws {
        launchAppFromScratch()
        let rootName = setUpTest(testName: uniqueName(prefix: "AppIntentDeleteRoot"))
        goToMyFolders()

        let rootEntity = try await waitForEntity(named: rootName)
        let folderName = uniqueName(prefix: "DeleteByIntent")
        let folderEntity = try await createFolder(named: folderName, in: rootEntity)

        let deleteFilesIntent = definitions.intents["DeleteFilesIntent"]
        _ = try await deleteFilesIntent
            .makeIntent(entities: [folderEntity])
            .run()

        enterInDirectory(named: rootName)
        XCTAssertFalse(app.staticTexts[folderName].waitForExistence(timeout: 3), "Deleted folder should disappear from listing")
    }

    @MainActor
    func testAppIntentViewAnnotations() async throws {
        launchAppFromScratch()
        let rootName = setUpTest(testName: uniqueName(prefix: "AppIntentAnnotationsRoot"))
        goToMyFolders()

        let fileEntityDefinition = definitions.entities["KDriveFileEntity"]
        let resolved = try await fileEntityDefinition.entities(matching: rootName)
        XCTAssertFalse(resolved.isEmpty, "Created folder should resolve through Spotlight entity query")

        let annotations = try await fileEntityDefinition.viewAnnotations()
        XCTAssertFalse(annotations.isEmpty, "On-screen annotations should not be empty")
        XCTAssertTrue(
            annotations.contains { $0.entity == resolved[0] },
            "Visible folder should be annotated as on-screen"
        )
    }

    @MainActor
    func testAppIntentSpotlightQueries() async throws {
        launchAppFromScratch()
        let rootName = setUpTest(testName: uniqueName(prefix: "AppIntentQueryRoot"))
        goToMyFolders()

        let queryPrefix = uniqueName(prefix: "SpotlightQuery")
        let rootEntity = try await waitForEntity(named: rootName)
        _ = try await createFolder(named: queryPrefix, in: rootEntity)

        let fileEntityDefinition = definitions.entities["KDriveFileEntity"]
        let matches = try await fileEntityDefinition.entities(matching: queryPrefix)
        XCTAssertFalse(matches.isEmpty, "Spotlight query should return the created folder")

        let criteria = StringSearchCriteria(term: queryPrefix)
        let searchIntent = definitions.intents["SystemSearchInAppIntent"].makeIntent(criteria: criteria)
        _ = try await searchIntent.run()
        XCTAssertTrue(
            app.searchFields.firstMatch.waitForExistence(timeout: Self.defaultTimeout),
            "SystemSearchInAppIntent should open in-app search"
        )

        navigationBars[KDriveResourcesStrings.Localizable.searchTitle].buttons[KDriveResourcesStrings.Localizable.buttonClose]
            .tap()
    }
}
