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

@testable import InfomaniakDI
@testable import kDriveCore
import XCTest

/// Unit tests of the RangeProviderGuts
final class UTRangeProviderGuts: XCTestCase {
    override static func setUp() {
        super.setUp()
        MockingHelper.clearRegisteredTypes()
        MockingHelper.registerConcreteTypes(configuration: .minimal)
    }

    // MARK: - readFileByteSize

    // covered by IT

    // MARK: - buildRanges(fileSize: totalChunksCount: chunkSize:)

    // MARK: zero

    func testBuildRanges_0ChunkSize() {
        // GIVEN
        let fileBytes = UInt64(4_865_229)
        let fileChunks = UInt64(4)
        let chunksSize = UInt64(0)

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            _ = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTFail("Expected to throw")
        } catch {
            guard case .IncorrectChunkSize = error as? RangeProvider.ErrorDomain else {
                XCTFail("Unexpected")
                return
            }
        }
    }

    func testBuildRanges_0FileLength() {
        // GIVEN
        let fileBytes = UInt64(0)
        let fileChunks = UInt64(4)
        let chunksSize = UInt64(10 * 1024 * 1024)

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            let ranges = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTAssertEqual(ranges.count, 0, "An empty file has no range")
            try Self.checkContinuity(ranges: ranges)
        } catch {
            XCTFail("Chunks not continuous: \(error)")
        }
    }

    func testBuildRanges_0Chunk() {
        // GIVEN
        let fileBytes = UInt64(4_865_229)
        let fileChunks = UInt64(0)
        let chunksSize = UInt64(10 * 1024 * 1024)

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            _ = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTFail("Expected to throw")
        } catch {
            guard case .IncorrectTotalChunksCount = error as? RangeProvider.ErrorDomain else {
                XCTFail("Unexpected \(error)")
                return
            }
        }
    }

    // MARK: one byte

    func testBuildRanges_1ChunkSize() {
        // GIVEN
        let fileBytes = UInt64(4_865_229)
        let fileChunks = UInt64(4)
        let chunksSize = UInt64(1)

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            let ranges = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTAssertEqual(ranges.count, 5)

            try Self.checkContinuity(ranges: ranges)
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    func testBuildRanges_1FileLength_valid() {
        // GIVEN
        let fileBytes = UInt64(1)
        let fileChunks = UInt64(1)
        let chunksSize = UInt64(1)
        // read as: The first Byte goes from index O to O
        let firstByteRange: DataRange = 0 ... 0

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            let ranges = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTAssertEqual(ranges.count, 1)
            XCTAssertEqual(ranges.first, firstByteRange)

            try Self.checkContinuity(ranges: ranges)
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    func testBuildRanges_1FileLength_invalid() {
        // GIVEN
        let fileBytes = UInt64(1)
        let fileChunks = UInt64(4)
        let chunksSize = UInt64(10 * 1024 * 1024)

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            _ = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTFail("Expected to throw")
        } catch {
            guard case .ChunkedSizeLargerThanSourceFile = error as? RangeProvider.ErrorDomain else {
                XCTFail("Unexpected")
                return
            }
        }
    }

    func testBuildRanges_1Chunk() {
        // GIVEN
        let fileBytes = UInt64(4_865_229)
        let fileChunks = UInt64(1)
        let chunksSize = UInt64(1 * 1024 * 1024)
        let expectedChunks = 2 // One plus remainer

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            let ranges = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTAssertEqual(ranges.count, expectedChunks)

            try Self.checkContinuity(ranges: ranges)
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    func testBuildRanges_1ChunkBiggerThanFile() {
        // GIVEN
        let fileBytes = UInt64(4_865_229)
        let fileChunks = UInt64(1)
        let chunksSize = UInt64(10 * 1024 * 1024)

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            _ = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTFail("Expected to throw")
        } catch {
            guard case .ChunkedSizeLargerThanSourceFile = error as? RangeProvider.ErrorDomain else {
                XCTFail("Unexpected")
                return
            }
        }
    }

    // MARK: pseudo arbitrary sizes

    func testBuildRanges_ChunkBiggerThanFile() {
        // GIVEN
        // Asking for 4 chunks of 10Mi is larger than the file, should exit
        let fileBytes = UInt64(4_865_229)
        let fileChunks = UInt64(4)
        let chunksSize = UInt64(10 * 1024 * 1024)

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            _ = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTFail("Expected to throw")
        } catch {
            guard case .ChunkedSizeLargerThanSourceFile = error as? RangeProvider.ErrorDomain else {
                XCTFail("Unexpected")
                return
            }
        }
    }

    func testBuildRanges_ChunksWithoutRemainder() {
        // GIVEN
        // Asking for exactly 4 chunks of 1Mi
        let fileBytes = UInt64(4 * 1024 * 1024)
        let fileChunks = UInt64(4)
        let chunksSize = UInt64(1 * 1024 * 1024)

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            let ranges = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTAssertEqual(ranges.count, 4)

            try Self.checkContinuity(ranges: ranges)
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    func testBuildRanges_ChunksWithRemainder() {
        // GIVEN
        // Asking for 4 chunks of 1Mi + some extra chunk with the remainder
        let fileBytes = UInt64(4_865_229)
        let fileChunks = UInt64(4)
        let chunksSize = UInt64(1 * 1024 * 1024)

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        do {
            let ranges = try guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)

            // THEN
            XCTAssertEqual(ranges.count, 5)

            try Self.checkContinuity(ranges: ranges)
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    // MARK: - preferredChunkSize(for fileSize:)

    /// This is just testing the android heuristic, the min size in enforced at a higher level
    func testPreferredChunkSize_smallerThanMinChunk() {
        // GIVEN
        let fileBytes = UInt64(769)
        let chunkMinSize = RangeProvider.APIConstants.chunkMinSize
        XCTAssertTrue(chunkMinSize > fileBytes, "this precondition should be true")

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        let preferredChunkSize = guts.preferredChunkSize(for: fileBytes)

        // THEN
        XCTAssertEqual(preferredChunkSize, fileBytes)
    }

    func testPreferredChunkSize_equalsMinChunk() {
        // GIVEN
        let chunkMinSize = RangeProvider.APIConstants.chunkMinSize
        let fileBytes = chunkMinSize

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        let preferredChunkSize = guts.preferredChunkSize(for: fileBytes)

        // THEN
        XCTAssertEqual(preferredChunkSize, chunkMinSize)
    }

    func testPreferredChunkSize_betweensMinAndMax() {
        // GIVEN
        let fileBytes = UInt64(5 * 1025 * 1024)
        XCTAssertGreaterThanOrEqual(fileBytes, RangeProvider.APIConstants.chunkMinSize)
        XCTAssertLessThanOrEqual(fileBytes, RangeProvider.APIConstants.chunkMaxSizeClient)

        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        let preferredChunkSize = guts.preferredChunkSize(for: fileBytes)

        // THEN
        XCTAssertGreaterThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMinSize)
        XCTAssertLessThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMaxSizeClient)
    }

    func testPreferredChunkSize_EqualMax() {
        // GIVEN
        let fileBytes = RangeProvider.APIConstants.chunkMaxSizeClient
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        let preferredChunkSize = guts.preferredChunkSize(for: fileBytes)

        // THEN
        XCTAssertGreaterThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMinSize)
        XCTAssertLessThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMaxSizeClient)
    }

    func testPreferredChunkSize_10Times() {
        // GIVEN
        let fileBytes = UInt64(10 * RangeProvider.APIConstants.chunkMaxSizeClient)
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        let preferredChunkSize = guts.preferredChunkSize(for: fileBytes)

        // THEN
        XCTAssertGreaterThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMinSize)
        XCTAssertLessThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMaxSizeClient)
    }

    func testPreferredChunkSize_10KTimes() {
        // GIVEN
        let fileBytes = UInt64(10000 * RangeProvider.APIConstants.chunkMaxSizeClient)
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        let preferredChunkSize = guts.preferredChunkSize(for: fileBytes)

        // THEN
        XCTAssertGreaterThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMinSize)
        XCTAssertLessThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMaxSizeClient)
    }

    func testPreferredChunkSize_100KTimes() {
        // GIVEN
        let fileBytes = UInt64(100_000 * RangeProvider.APIConstants.chunkMaxSizeClient)
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        let preferredChunkSize = guts.preferredChunkSize(for: fileBytes)

        // THEN
        XCTAssertGreaterThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMinSize)
        XCTAssertLessThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMaxSizeClient)
    }

    func testPreferredChunkSize_100MTimes() {
        // GIVEN
        let fileBytes = UInt64(100_000_000 * RangeProvider.APIConstants.chunkMaxSizeClient)
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)

        // WHEN
        let preferredChunkSize = guts.preferredChunkSize(for: fileBytes)

        // THEN
        XCTAssertGreaterThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMinSize)
        XCTAssertLessThanOrEqual(preferredChunkSize, RangeProvider.APIConstants.chunkMaxSizeClient)
    }

    // MARK: - Helpers

    /// Yo dawg you tested the test helper function ?
    func testContinuityHelper_continuous() {
        // GIVEN
        let rangeA = DataRange(uncheckedBounds: (lower: 0, upper: 1337))
        let rangeB = DataRange(uncheckedBounds: (lower: 1338, upper: 2047))
        let continuousRanges = [rangeA, rangeB]

        // WHEN
        do {
            try Self.checkContinuity(ranges: continuousRanges)

            // THEN
            // no exception, all good
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    func testContinuityHelper_notContinuous() {
        // GIVEN
        let rangeA = DataRange(uncheckedBounds: (lower: 0, upper: 1337))
        let rangeB = DataRange(uncheckedBounds: (lower: 1339, upper: 2047))
        let notContinuousRanges = [rangeA, rangeB]

        // WHEN
        do {
            try Self.checkContinuity(ranges: notContinuousRanges)

            // THEN
            XCTFail("Unexpected")
        } catch {
            guard error is UTRangeProviderGuts.DomainError else {
                XCTFail("Unexpected")
                return
            }

            // an exception, all good
        }
    }

    func testContinuityHelper_empty() {
        // GIVEN
        // note: Is ø formally continuous? No, but easier this way.
        let emptyRanges: [DataRange] = []

        // WHEN
        do {
            try Self.checkContinuity(ranges: emptyRanges)

            // THEN
            // no exception, all good
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    enum DomainError: Error {
        case gap(leftUpper: UInt64, rightLower: UInt64)
        case nonZeroStarted
    }

    /// Check that the chunks provided are continuously describing chunks without gaps.
    static func checkContinuity(ranges: [DataRange]) throws {
        /// Create an offseted sequence
        let offsetedRanges = ranges.dropFirst()

        /// Create a zip to check continuity
        let zip = zip(ranges, offsetedRanges)
        for tuple in zip {
            let leftUpperBound = tuple.0.upperBound
            let rightLowerBound = tuple.1.lowerBound

            // print("range [leftUpperBound: \(leftUpperBound), rightLowerBound: \(rightLowerBound)]")

            guard leftUpperBound + 1 == rightLowerBound else {
                throw DomainError.gap(leftUpper: leftUpperBound, rightLower: rightLowerBound)
            }
        }
    }
}
