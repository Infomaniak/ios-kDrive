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

import Foundation
@testable import kDriveCore
import XCTest

/// Unit Tests of the ChunkProvider
final class UTChunkProvider: XCTestCase {
    override class func setUp() {
        super.setUp()
        MockingHelper.clearRegisteredTypes()
        MockingHelper.registerConcreteTypes(configuration: .minimal)
    }

    // MARK: - next

    func testNext_emptyRanges() throws {
        // GIVEN
        let ranges = [DataRange]()
        let mckFileHandle = MCKFileHandlable()

        let chunkProvider = ChunkProvider(mockedHandlable: mckFileHandle, ranges: ranges)

        // WHEN
        let chunk = chunkProvider.next()

        // THEN
        XCTAssertEqual(mckFileHandle.seekToOffsetCallCount, 0)
        XCTAssertEqual(mckFileHandle.readUpToCountCallCount, 0)
        XCTAssertNil(chunk)
    }

    func testNext_hasOneRange() throws {
        // GIVEN
        let ranges: [DataRange] = [
            0 ... 1024
        ]
        let mckFileHandle = MCKFileHandlable()
        mckFileHandle.readUpToCountClosure = { _ in Data() }

        let chunkProvider = ChunkProvider(mockedHandlable: mckFileHandle, ranges: ranges)

        // WHEN
        let chunk = chunkProvider.next()

        // THEN
        XCTAssertEqual(mckFileHandle.seekToOffsetCallCount, 1)
        XCTAssertEqual(mckFileHandle.readUpToCountCallCount, 1)
        XCTAssertNotNil(chunk)
    }

    func testNext_hasRanges() throws {
        // GIVEN
        let ranges: [DataRange] = [
            0 ... 1,
            1 ... 2,
            2 ... 4
        ]
        let mckFileHandle = MCKFileHandlable()
        mckFileHandle.readUpToCountClosure = { _ in Data() }

        let chunkProvider = ChunkProvider(mockedHandlable: mckFileHandle, ranges: ranges)

        // WHEN
        let chunk = chunkProvider.next()

        // THEN
        XCTAssertEqual(mckFileHandle.seekToOffsetCallCount, 1)
        XCTAssertEqual(mckFileHandle.readUpToCountCallCount, 1)
        XCTAssertNotNil(chunk)
    }

    func testNext_enumarateAll() throws {
        // GIVEN
        let ranges: [DataRange] = [
            0 ... 1,
            1 ... 2,
            2 ... 4
        ]

        let expectedRangesCount = ranges.count
        let mckFileHandle = MCKFileHandlable()
        mckFileHandle.readUpToCountClosure = { _ in Data() }

        let chunkProvider = ChunkProvider(mockedHandlable: mckFileHandle, ranges: ranges)

        // WHEN
        var chunks: [Data] = []
        while let chunk = chunkProvider.next() {
            chunks.append(chunk)
        }

        // THEN
        XCTAssertEqual(mckFileHandle.seekToOffsetCallCount, expectedRangesCount)
        XCTAssertEqual(mckFileHandle.readUpToCountCallCount, expectedRangesCount)
        XCTAssertEqual(chunks.count, expectedRangesCount)
    }

    // MARK: - readChunk(range:)

    func testReadChunk_validChunk() throws {
        // GIVEN
        let range: DataRange = 0 ... 1
        let mckFileHandle = MCKFileHandlable()
        mckFileHandle.readUpToCountClosure = { _ in Data() }
        mckFileHandle.seekToOffsetClosure = { index in
            XCTAssertEqual(index, range.lowerBound)
        }

        let chunkProvider = ChunkProvider(mockedHandlable: mckFileHandle, ranges: [])

        // WHEN
        do {
            let chunk = try chunkProvider.readChunk(range: range)
            XCTAssertNotNil(chunk)
        } catch {
            XCTFail("Unexpected :\(error)")
            return
        }

        // THEN
        XCTAssertEqual(mckFileHandle.seekToOffsetCallCount, 1)
        XCTAssertEqual(mckFileHandle.readUpToCountCallCount, 1)
    }

    func testReadChunk_throwErrorOnSeek() throws {
        // GIVEN
        let range: DataRange = 0 ... 1
        let mckFileHandle = MCKFileHandlable()
        mckFileHandle.readUpToCountClosure = { _ in Data() }
        mckFileHandle.seekToOffsetError = NSError(domain: "k", code: 1337)

        let chunkProvider = ChunkProvider(mockedHandlable: mckFileHandle, ranges: [])

        // WHEN
        do {
            _ = try chunkProvider.readChunk(range: range)
            XCTFail("Unexpected")
            return
        } catch {
            guard (error as NSError).code == 1337 else {
                XCTFail("Unexpected")
                return
            }
            // all good
        }

        // THEN
        XCTAssertEqual(mckFileHandle.seekToOffsetCallCount, 1)
        XCTAssertEqual(mckFileHandle.readUpToCountCallCount, 0)
    }

    func testReadChunk_throwErrorOnRead() throws {
        // GIVEN
        let range: DataRange = 0 ... 1
        let mckFileHandle = MCKFileHandlable()
        mckFileHandle.readUpToCountClosure = { _ in Data() }
        mckFileHandle.readUpToCountError = NSError(domain: "k", code: 1337)

        let chunkProvider = ChunkProvider(mockedHandlable: mckFileHandle, ranges: [])

        // WHEN
        do {
            _ = try chunkProvider.readChunk(range: range)
            XCTFail("Unexpected")
            return
        } catch {
            guard (error as NSError).code == 1337 else {
                XCTFail("Unexpected")
                return
            }
            // all good
        }

        // THEN
        XCTAssertEqual(mckFileHandle.seekToOffsetCallCount, 1)
        XCTAssertEqual(mckFileHandle.readUpToCountCallCount, 1)
    }
}
