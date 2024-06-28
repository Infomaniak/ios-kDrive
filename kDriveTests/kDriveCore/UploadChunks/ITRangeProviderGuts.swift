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

/// Integration Tests of the RangeProviderGuts
final class ITRangeProviderGuts: XCTestCase {
    override class func setUp() {
        super.setUp()
        MockingHelper.clearRegisteredTypes()
        MockingHelper.registerConcreteTypes(configuration: .minimal)
    }

    // MARK: - readFileByteSize

    let file = "Matterhorn_as_seen_from_Zermatt,_Wallis,_Switzerland,_2012_August,Wikimedia_Commons"

    func testReadFileByteSize() {
        // GIVEN
        let expectedFileBytes = UInt64(4_865_229)
        let bundle = Bundle(for: type(of: self))
        let pathURL = bundle.url(forResource: file, withExtension: "jpg")!
        let guts = RangeProviderGuts(fileURL: pathURL)

        // WHEN
        do {
            let size = try guts.readFileByteSize()

            // THEN
            XCTAssertEqual(size, expectedFileBytes)
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    func testReadFileByteSize_FileDoesNotExists() {
        // GIVEN
        let notThereFileURL = URL(string: "file:///Arcalod_2117.jpg")!
        let rangeProvider = RangeProviderGuts(fileURL: notThereFileURL)

        // WHEN
        do {
            _ = try rangeProvider.readFileByteSize()

            // THEN
            XCTFail("Unexpected")
        } catch {
            // THEN
            // "No such file or directory"
            XCTAssertEqual((error as NSError).domain, "NSCocoaErrorDomain")
            XCTAssertEqual((error as NSError).code, 260)
        }
    }

    // MARK: - buildRanges(fileSize: totalChunksCount: chunkSize:)

    func testBuildRanges_fromImage() {
        // GIVEN
        let bundle = Bundle(for: type(of: self))
        let pathURL = bundle.url(forResource: file, withExtension: "jpg")!
        let guts = RangeProviderGuts(fileURL: pathURL)
        let fileChunks = UInt64(4)
        let expectedChunks = 5
        let chunksSize = UInt64(1 * 1024 * 1024)

        // WHEN
        do {
            let size = try guts.readFileByteSize()
            let chunks = try guts.buildRanges(fileSize: size, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            try UTRangeProviderGuts.checkContinuity(ranges: chunks)
            XCTAssertEqual(chunks.count, expectedChunks)

            // Check that last range is the end of the file
            let lastChunk = chunks[expectedChunks - 1]
            // The last offset is size -1
            let endOfFileOffset = size - 1
            guard lastChunk.upperBound == endOfFileOffset else {
                XCTFail("EOF not reached")
                return
            }

        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    func testBuildRanges_fromEmptyFile() {
        // GIVEN
        let guts = RangeProviderGuts(fileURL: URL(string: "http://infomaniak.ch")!)
        let emptyFileSize = UInt64(0)
        let fileChunks = UInt64(1)
        let chunksSize = UInt64(1)
        let expectedChunks = 0

        // WHEN
        do {
            let chunks = try guts.buildRanges(fileSize: emptyFileSize, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTAssertEqual(chunks.count, expectedChunks)
            try UTRangeProviderGuts.checkContinuity(ranges: chunks)
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    // MARK: - preferredChunkSize(for fileSize:)

    func testPreferredChunkSize_fromImage() {
        // GIVEN
        let bundle = Bundle(for: type(of: self))
        let pathURL = bundle.url(forResource: file, withExtension: "jpg")!
        let guts = RangeProviderGuts(fileURL: pathURL)

        // WHEN
        do {
            let size = try guts.readFileByteSize()
            let preferredChunkSize = guts.preferredChunkSize(for: size)

            // THEN
            XCTAssertTrue(preferredChunkSize > 0)
            XCTAssertTrue(preferredChunkSize <= size)

            // this should not be strictly imposed but I can quickly check behaviour here
            // XCTAssertTrue(preferredChunkSize >= RangeProvider.APIConstants.chunkMinSize)
            // XCTAssertTrue(preferredChunkSize <= RangeProvider.APIConstants.chunkMaxSize)
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    func testPreferredChunkSize_0() {
        // GIVEN
        let guts = RangeProviderGuts(fileURL: URL(string: "http://infomaniak.ch")!)

        // WHEN
        let preferredChunkSize = guts.preferredChunkSize(for: 0)

        // THEN
        XCTAssertTrue(preferredChunkSize == 0)
    }

    func testPreferredChunkSize_notLargerThanFileSize() {
        // GIVEN
        let guts = RangeProviderGuts(fileURL: URL(string: "http://infomaniak.ch")!)
        let superSmallFileSize: UInt64 = 10

        // WHEN
        let preferredChunkSize = guts.preferredChunkSize(for: superSmallFileSize)

        // THEN
        XCTAssertEqual(preferredChunkSize,
                       superSmallFileSize,
                       "we expect the chunk size to be capped at the file size for small files")
    }
}
