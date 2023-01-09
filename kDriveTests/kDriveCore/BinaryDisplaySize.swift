/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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
import kDriveCore
import XCTest
@testable import kDrive

final class BinaryDisplaySizeTests: XCTestCase {
    
    // MARK: - toBytes
    
    func testToBytesFromBytes() {
        // GIVEN
        let bytes: UInt64 = 1024
        let displayBytes = BinaryDisplaySize.bytes(bytes)
        
        // WHEN
        let recBytes = displayBytes.toBytes
        
        // THEN
        XCTAssertEqual(recBytes, bytes)
    }
    
    func testToBytesFromKilobytes() {
        // GIVEN
        let kilobytes: Double = 1
        let expectedBytes: UInt64 = 1024 /* 1024 is a kibibyte, not a kilobyte*/
        let displayKilobytes = BinaryDisplaySize.kilobytes(kilobytes)
        
        // WHEN
        let recBytes = displayKilobytes.toBytes
        
        // THEN
        XCTAssertEqual(recBytes, expectedBytes)
    }
    
    func testToBytesFromMBytes() {
        // GIVEN
        let megabytes: Double = 1
        let expectedBytes: UInt64 =  1 * 1024 * 1024 /* 1024^2 is a Mbibyte, not a Mbyte */
        let displayMegabytes = BinaryDisplaySize.megabytes(megabytes)
        
        // WHEN
        let recBytes = displayMegabytes.toBytes
        
        // THEN
        XCTAssertEqual(recBytes, expectedBytes)
    }
    
    func testToBytesFromGBytes() {
        // GIVEN
        let gigabytes: Double = 1
        let expectedBytes: UInt64 = 1 * 1024 * 1024 * 1024 /* 1024^3 is a Gbibyte, not a Gbyte */
        let displayGigabytes = BinaryDisplaySize.gigabytes(gigabytes)
        
        // WHEN
        let recBytes = displayGigabytes.toBytes
        
        // THEN
        XCTAssertEqual(recBytes, expectedBytes)
    }

    // MARK: - toGigabytes
    
    func testToGigabytesFromBytes() {
        // GIVEN
        let bytes: UInt64 = 1 * 1024 * 1024 * 1024 /* 1024^3 bytes is a Gbibyte, not a Gbyte */
        let expectedGb: Double = 1
        let displayBytes = BinaryDisplaySize.bytes(bytes)
        
        // WHEN
        let recBytes = displayBytes.toGigabytes
        
        // THEN
        XCTAssertEqual(recBytes, expectedGb)
    }

    func testToGigabytesFromKilobytes() {
        // GIVEN
        let kilobytes: Double = 1 * 1024 * 1024 /* 1024^2 Kbytes is a Gbibyte, not a Gbyte */
        let expectedGb: Double = 1
        let displayKilobytes = BinaryDisplaySize.kilobytes(kilobytes)

        // WHEN
        let recBytes = displayKilobytes.toGigabytes

        // THEN
        XCTAssertEqual(recBytes, expectedGb)
    }

    func testToGigabytesFromMBytes() {
        // GIVEN
        let megabytes: Double = 1 * 1024
        let expectedGb: Double = 1
        let displayMegabytes = BinaryDisplaySize.megabytes(megabytes)

        // WHEN
        let recBytes = displayMegabytes.toGigabytes

        // THEN
        XCTAssertEqual(recBytes, expectedGb)
    }

    func testToGigabytesFromGBytes() {
        // GIVEN
        let gigabytes: Double = 1
        let expectedGb: Double = 1
        let displayGigabytes = BinaryDisplaySize.gigabytes(gigabytes)

        // WHEN
        let recBytes = displayGigabytes.toGigabytes

        // THEN
        XCTAssertEqual(recBytes, expectedGb)
    }
    
}
