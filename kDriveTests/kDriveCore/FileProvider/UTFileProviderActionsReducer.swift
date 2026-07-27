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

@testable import kDriveCore
import XCTest

/// Unit tests for `FileProviderActionsReducer`, which categorizes the actions returned by the
/// advanced listing endpoint into the files the File Provider must update, delete or remove.
final class UTFileProviderActionsReducer: XCTestCase {
    private let reducer = FileProviderActionsReducer()

    override func setUp() {
        super.setUp()
        TestTargetAssemblyHelper.clearRegisteredTypes()
        _ = TestTargetAssemblyHelper(configuration: .minimal)
    }

    // MARK: - Helpers

    private func makeFile(id: Int) -> File {
        File(id: id, name: "file-\(id)")
    }

    private func makeAction(_ type: FileActivityType, fileId: Int, parentId: Int = 1) -> FileAction {
        FileAction(action: type, fileId: fileId, parentId: parentId)
    }

    private func ids(_ files: Set<File>) -> Set<Int> {
        Set(files.map(\.id))
    }

    // MARK: - Categorization

    func testEmptyInputProducesEmptyOutput() {
        // WHEN
        let output = reducer.reduce(actions: [], actionsFiles: [])

        // THEN
        XCTAssertTrue(output.updated.isEmpty)
        XCTAssertTrue(output.deleted.isEmpty)
        XCTAssertTrue(output.movedOut.isEmpty)
    }

    func testUpdateActionsAreCategorizedAsUpdated() {
        // GIVEN
        let file = makeFile(id: 10)
        let actions = [makeAction(.fileUpdate, fileId: 10)]

        // WHEN
        let output = reducer.reduce(actions: actions, actionsFiles: [file])

        // THEN
        XCTAssertEqual(ids(output.updated), [10])
        XCTAssertTrue(output.deleted.isEmpty)
        XCTAssertTrue(output.movedOut.isEmpty)
    }

    func testDeleteAndTrashActionsAreCategorizedAsDeleted() {
        // GIVEN
        let deletedFile = makeFile(id: 10)
        let trashedFile = makeFile(id: 11)
        let actions = [
            makeAction(.fileDelete, fileId: 10),
            makeAction(.fileTrash, fileId: 11)
        ]

        // WHEN
        let output = reducer.reduce(actions: actions, actionsFiles: [deletedFile, trashedFile])

        // THEN
        XCTAssertEqual(ids(output.deleted), [10, 11])
        XCTAssertTrue(output.updated.isEmpty)
        XCTAssertTrue(output.movedOut.isEmpty)
    }

    func testMoveOutActionIsCategorizedAsMovedOutNotDeleted() {
        // GIVEN
        let file = makeFile(id: 10)
        let actions = [makeAction(.fileMoveOut, fileId: 10)]

        // WHEN
        let output = reducer.reduce(actions: actions, actionsFiles: [file])

        // THEN a moved-out file must be removed from the directory but kept in cache
        XCTAssertEqual(ids(output.movedOut), [10])
        XCTAssertTrue(output.deleted.isEmpty)
        XCTAssertTrue(output.updated.isEmpty)
    }

    func testUnhandledActionsAreIgnored() {
        // GIVEN actions the File Provider does not act upon
        let file = makeFile(id: 10)
        let actions = [
            makeAction(.fileAccess, fileId: 10),
            makeAction(.commentCreate, fileId: 10)
        ]

        // WHEN
        let output = reducer.reduce(actions: actions, actionsFiles: [file])

        // THEN
        XCTAssertTrue(output.updated.isEmpty)
        XCTAssertTrue(output.deleted.isEmpty)
        XCTAssertTrue(output.movedOut.isEmpty)
    }

    func testActionWithoutMatchingFileIsIgnored() {
        // GIVEN an action referencing a file id that is not part of actionsFiles
        let actions = [makeAction(.fileUpdate, fileId: 999)]

        // WHEN
        let output = reducer.reduce(actions: actions, actionsFiles: [makeFile(id: 10)])

        // THEN
        XCTAssertTrue(output.updated.isEmpty)
        XCTAssertTrue(output.deleted.isEmpty)
        XCTAssertTrue(output.movedOut.isEmpty)
    }

    // MARK: - Last action wins

    func testMostRecentActionWinsWhenDeleteFollowsUpdate() {
        // GIVEN actions are ordered chronologically (oldest first): update then delete
        let file = makeFile(id: 10)
        let actions = [
            makeAction(.fileUpdate, fileId: 10),
            makeAction(.fileDelete, fileId: 10)
        ]

        // WHEN
        let output = reducer.reduce(actions: actions, actionsFiles: [file])

        // THEN the most recent action (delete) is the one applied
        XCTAssertEqual(ids(output.deleted), [10])
        XCTAssertTrue(output.updated.isEmpty)
        XCTAssertTrue(output.movedOut.isEmpty)
    }

    func testMostRecentActionWinsWhenUpdateFollowsDelete() {
        // GIVEN the reverse chronological order: delete then update
        let file = makeFile(id: 10)
        let actions = [
            makeAction(.fileDelete, fileId: 10),
            makeAction(.fileUpdate, fileId: 10)
        ]

        // WHEN
        let output = reducer.reduce(actions: actions, actionsFiles: [file])

        // THEN the most recent action (update) is the one applied
        XCTAssertEqual(ids(output.updated), [10])
        XCTAssertTrue(output.deleted.isEmpty)
        XCTAssertTrue(output.movedOut.isEmpty)
    }

    func testOnlyLastActionIsKeptAcrossManyActionsForSameFile() {
        // GIVEN several actions for the same file, the last one being a move-out
        let file = makeFile(id: 10)
        let actions = [
            makeAction(.fileCreate, fileId: 10),
            makeAction(.fileRename, fileId: 10),
            makeAction(.fileUpdate, fileId: 10),
            makeAction(.fileMoveOut, fileId: 10)
        ]

        // WHEN
        let output = reducer.reduce(actions: actions, actionsFiles: [file])

        // THEN
        XCTAssertEqual(ids(output.movedOut), [10])
        XCTAssertTrue(output.updated.isEmpty)
        XCTAssertTrue(output.deleted.isEmpty)
    }

    // MARK: - Multiple files

    func testDistinctFilesAreCategorizedIndependently() {
        // GIVEN one file per category
        let updatedFile = makeFile(id: 10)
        let deletedFile = makeFile(id: 11)
        let movedOutFile = makeFile(id: 12)
        let actions = [
            makeAction(.fileUpdate, fileId: 10),
            makeAction(.fileTrash, fileId: 11),
            makeAction(.fileMoveOut, fileId: 12)
        ]

        // WHEN
        let output = reducer.reduce(
            actions: actions,
            actionsFiles: [updatedFile, deletedFile, movedOutFile]
        )

        // THEN each file lands in exactly one, mutually exclusive, set
        XCTAssertEqual(ids(output.updated), [10])
        XCTAssertEqual(ids(output.deleted), [11])
        XCTAssertEqual(ids(output.movedOut), [12])
    }
}
