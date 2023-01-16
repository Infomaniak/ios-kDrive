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

import XCTest
@testable import kDriveCore

/// Unit tests of the RangeProviderGuts
final class UTRangeProviderGuts: XCTestCase {

    // MARK: - readFileByteSize
    
    // covered by IT
    
    // MARK: - buildRanges(fileSize: totalChunksCount: chunkSize:)

    func testBuildRanges_ChunkBiggerThanFile() {
        // GIVEN
        // Asking for 4 chunks of 10Mi is larger than the file, should exit
        let fileBytes = UInt64(4_865_229)
        let fileChunks = UInt64(4)
        let chunksSize = UInt64(10*1024*1024)
        
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)
        
        // WHEN
        let ranges = guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)
        
        // THEN
        XCTAssertEqual(ranges.count, 0)
        do {
            try checkContinuity(ranges: ranges)
        } catch {
            XCTFail("Chunks not continuous: \(error)")
        }
    }
    
    func testBuildRanges_ChunksWithoutRemainder() {
        // GIVEN
        // Asking for exactly 4 chunks of 1Mi
        let fileBytes = UInt64(4*1024*1024)
        let fileChunks = UInt64(4)
        let chunksSize = UInt64(1*1024*1024)
        
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)
        
        // WHEN
        let ranges = guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)
        
        // THEN
        XCTAssertEqual(ranges.count, 4)
        do {
            try checkContinuity(ranges: ranges)
        } catch {
            XCTFail("Chunks not continuous: \(error)")
        }
    }
    
    func testBuildRanges_ChunksWithRemainder() {
        // GIVEN
        // Asking for 4 chunks of 1Mi + some extra chunk with the remainder
        let fileBytes = UInt64(4_865_229)
        let fileChunks = UInt64(4)
        let chunksSize = UInt64(1*1024*1024)
        
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        let guts = RangeProviderGuts(fileURL: stubURL)
        
        // WHEN
        let ranges = guts.buildRanges(fileSize: fileBytes, totalChunksCount: fileChunks, chunkSize: chunksSize)
        
        // THEN
        XCTAssertEqual(ranges.count, 5)
        do {
            try checkContinuity(ranges: ranges)
        } catch {
            XCTFail("Chunks not continuous: \(error)")
        }
    }
    
    // Helpers
    
    /// Yo dawg you tested the test helper function ?
    func testContinuityHelper_continuous() {
        // GIVEN
        let rangeA = DataRange(uncheckedBounds: (lower: 0, upper: 1337))
        let rangeB = DataRange(uncheckedBounds: (lower: 1338, upper: 2047))
        let continuousRanges = [rangeA, rangeB]
        
        // WHEN
        do {
            try self.checkContinuity(ranges: continuousRanges)
            
            // THEN
            // no exception, all good
        } catch {
            XCTFail("Unexpected")
        }
    }
    
    func testContinuityHelper_notContinuous() {
        // GIVEN
        let rangeA = DataRange(uncheckedBounds: (lower: 0, upper: 1337))
        let rangeB = DataRange(uncheckedBounds: (lower: 1339, upper: 2047))
        let notContinuousRanges = [rangeA, rangeB]
        
        // WHEN
        do {
            try self.checkContinuity(ranges: notContinuousRanges)
            
            // THEN
            XCTFail("Unexpected")
        } catch {
            guard let error = error as? UTRangeProviderGuts.DomainError else {
                XCTFail("Unexpected")
                return
            }
            
            // an exception, all good
        }
    }
    
    
    func testContinuityHelper_empty() {
        // GIVEN
        // note: Is ø formally continuous? Yolo I declare yes for my local needs.
        let emptyRanges: [DataRange] = []
        
        // WHEN
        do {
            try self.checkContinuity(ranges: emptyRanges)
            
            // THEN
            // no exception, all good
        } catch {
            XCTFail("Unexpected")
        }
    }
    
    enum DomainError: Error {
        case gap(leftUpper: UInt64, rightLower: UInt64)
        case nonZeroStarted
    }
    
    /// Check that the chunks provided are continuously describing chunks without gaps.
    private func checkContinuity(ranges: [DataRange]) throws {
        /// Create an offsetted sequence
        let offsetedRanges = ranges.dropFirst()
        
        /// Create a zip to check continuity
        let zip = zip(ranges, offsetedRanges)
        for tuple in zip {
            let leftUpperBound = tuple.0.upperBound
            let rightLowerBound = tuple.1.lowerBound
            
            guard leftUpperBound+1 == rightLowerBound else {
                throw DomainError.gap(leftUpper: leftUpperBound, rightLower: rightLowerBound)
            }
        }
    }
}
