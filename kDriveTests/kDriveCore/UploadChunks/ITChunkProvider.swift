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

import kDriveCore
import XCTest

/// Integration Tests of the ChunkProvider
final class ITChunkProvider: XCTestCase {
    override class func setUp() {
        super.setUp()
        MockingHelper.clearRegisteredTypes()
        MockingHelper.registerConcreteTypes(configuration: .minimal)
    }

    /// Image from wikimedia under CC.
    static let file = "Matterhorn_as_seen_from_Zermatt,_Wallis,_Switzerland,_2012_August,Wikimedia_Commons"

    func testAllRanges_image() throws {
        // GIVEN
        let expectedParts = 5
        let bundle = Bundle(for: type(of: self))
        guard let pathURL = bundle.url(forResource: Self.file, withExtension: "jpg") else {
            XCTFail("unexpected")
            return
        }

        do {
            let expectedData = try Data(contentsOf: pathURL)
            let rangeProvider = RangeProvider(fileURL: pathURL)
            let ranges = try rangeProvider.allRanges
            guard let chunkProvider = ChunkProvider(fileURL: pathURL, ranges: ranges) else {
                XCTFail("Unexpected")
                return
            }

            // WHEN
            var chunks: [Data] = []
            while let chunk = chunkProvider.next() {
                chunks.append(chunk)
            }

            // THEN
            XCTAssertEqual(chunks.count, expectedParts)

            // ZIP data and ranges, check consistency
            let zip = zip(ranges, chunks)
            for tuple in zip {
                let range = tuple.0
                let data = tuple.1
                print(range)
                print(data)
                let byteCounts = range.upperBound - range.lowerBound + 1
                XCTAssertEqual(byteCounts, UInt64(data.count))
            }

            // Merge chunks and check file matches the original
            let magic = chunks.reduce(Data()) { partialResult, chunk in
                var partialResult = partialResult
                partialResult.append(chunk)
                return partialResult
            }

            XCTAssertEqual(magic, expectedData, "files are not matching, something is corrupted")

        } catch {
            XCTFail("Unexpected \(error)")
        }
    }
}
