/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

/// Unit Tests of the RangeProvider
final class UTRangeProvider: XCTestCase {
    override class func setUp() {
        super.setUp()
        MockingHelper.clearRegisteredTypes()
        MockingHelper.registerConcreteTypes()
    }

    func testAllRanges_zeroes() throws {
        // GIVEN
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        var rangeProvider = RangeProvider(fileURL: stubURL)
        let mckGuts = MCKRangeProviderGutsable( /* all zeroes by default */ )

        rangeProvider.guts = mckGuts

        // WHEN
        do {
            _ = try rangeProvider.allRanges

            // THEN
        } catch {
            XCTFail("Unexpected")
        }
    }

    func testAllRanges_FileTooLarge() throws {
        // GIVEN
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        var rangeProvider = RangeProvider(fileURL: stubURL)
        let mckGuts = MCKRangeProviderGutsable()
        mckGuts.readFileByteSizeReturnValue = RangeProvider.APIConstants.fileMaxSizeClient + 1
        rangeProvider.guts = mckGuts

        // WHEN
        do {
            _ = try rangeProvider.allRanges

            // THEN
            XCTFail("Unexpected")
        } catch {
            // Expecting a .FileTooLarge error
            guard case .FileTooLarge = error as? RangeProvider.ErrorDomain else {
                XCTFail("Unexpected")
                return
            }

            // success
        }
    }

    func testAllRanges_Success() throws {
        // GIVEN
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        var rangeProvider = RangeProvider(fileURL: stubURL)
        let mckGuts = MCKRangeProviderGutsable()
        mckGuts.readFileByteSizeReturnValue = RangeProvider.APIConstants.chunkMinSize + 1
        mckGuts.preferredChunkSizeReturnValue = 1 * 1024 * 1024

        rangeProvider.guts = mckGuts

        // WHEN
        do {
            let ranges = try rangeProvider.allRanges

            // THEN
            XCTAssertNotNil(ranges)
            XCTAssertEqual(ranges.count, 0)

            XCTAssertTrue(mckGuts.buildRangesCalled)
            XCTAssertTrue(mckGuts.preferredChunkSizeCalled)
            XCTAssertTrue(mckGuts.readFileByteSizeCalled)
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }
}
