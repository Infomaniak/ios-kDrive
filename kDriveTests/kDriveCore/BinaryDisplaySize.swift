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

import kDriveCore
import XCTest

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

    func testToBytesFromKibibytes() {
        // GIVEN
        let kibibytes: Double = 1
        let expectedBytes: UInt64 = 1024
        let displayKibibytes = BinaryDisplaySize.kibibytes(kibibytes)

        // WHEN
        let recBytes = displayKibibytes.toBytes

        // THEN
        XCTAssertEqual(recBytes, expectedBytes)
    }

    func testToBytesFromMebibytes() {
        // GIVEN
        let mebibytes: Double = 1
        let expectedBytes: UInt64 = 1 * 1024 * 1024
        let displayMebibytes = BinaryDisplaySize.mebibytes(mebibytes)

        // WHEN
        let recBytes = displayMebibytes.toBytes

        // THEN
        XCTAssertEqual(recBytes, expectedBytes)
    }

    func testToBytesFromGibibytes() {
        // GIVEN
        let gibibytes: Double = 1
        let expectedBytes: UInt64 = 1 * 1024 * 1024 * 1024
        let displayGibibytes = BinaryDisplaySize.gibibytes(gibibytes)

        // WHEN
        let recBytes = displayGibibytes.toBytes

        // THEN
        XCTAssertEqual(recBytes, expectedBytes)
    }
    
    func testToBytesFromTebibytes() {
        // GIVEN
        let tebibytes: Double = 1
        let expectedBytes: UInt64 = 1 * 1024 * 1024 * 1024 * 1024
        let displayTebibytes = BinaryDisplaySize.tebibytes(tebibytes)

        // WHEN
        let recBytes = displayTebibytes.toBytes

        // THEN
        XCTAssertEqual(recBytes, expectedBytes)
    }
    
    func testToBytesFromPebibytes() {
        // GIVEN
        let pebibytes: Double = 1
        let expectedBytes: UInt64 = 1 * 1024 * 1024 * 1024 * 1024 * 1024
        let displayPebibytes = BinaryDisplaySize.pebibytes(pebibytes)

        // WHEN
        let recBytes = displayPebibytes.toBytes

        // THEN
        XCTAssertEqual(recBytes, expectedBytes)
    }
    
    func testToBytesFromExbibytes() {
        // GIVEN
        let exbibytes: Double = 1
        let expectedBytes: UInt64 = 1 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024
        let displayExbibytes = BinaryDisplaySize.exbibytes(exbibytes)

        // WHEN
        let recBytes = displayExbibytes.toBytes

        // THEN
        XCTAssertEqual(recBytes, expectedBytes)
    }

    // MARK: - toKibibytes

    func testToKibibytesFromBytes() {
        // GIVEN
        let bytes: UInt64 = 1 * 1024
        let expectedKibibytes: Double = 1
        let displayBytes = BinaryDisplaySize.bytes(bytes)

        // WHEN
        let recBytes = displayBytes.toKibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedKibibytes)
    }

    func testToKibibytesFromKibibytes() {
        // GIVEN
        let kibibytes: Double = 1
        let expectedKibibytes: Double = 1
        let displayKibibytes = BinaryDisplaySize.kibibytes(kibibytes)

        // WHEN
        let recBytes = displayKibibytes.toKibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedKibibytes)
    }

    func testToKibibytesFromMebibytes() {
        // GIVEN
        let mebibytes: Double = 1
        let expectedKibibytes: Double = 1 * 1024
        let displayMebibytes = BinaryDisplaySize.mebibytes(mebibytes)

        // WHEN
        let recBytes = displayMebibytes.toKibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedKibibytes)
    }

    func testToKibibytesFromGibibytes() {
        // GIVEN
        let gibibytes: Double = 1
        let expectedKibibytes: Double = 1 * 1024 * 1024
        let displayGibibytes = BinaryDisplaySize.gibibytes(gibibytes)

        // WHEN
        let recBytes = displayGibibytes.toKibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedKibibytes)
    }
    
    func testToKibibytesFromTebibytes() {
        // GIVEN
        let tebibytes: Double = 1
        let expectedKibibytes: Double = 1 * 1024 * 1024 * 1024
        let displayTebibytes = BinaryDisplaySize.tebibytes(tebibytes)

        // WHEN
        let recBytes = displayTebibytes.toKibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedKibibytes)
    }
    
    func testToKibibytesFromPebibytes() {
        // GIVEN
        let pebibytes: Double = 1
        let expectedKibibytes: Double = 1 * 1024 * 1024 * 1024 * 1024
        let displayPebibytes = BinaryDisplaySize.pebibytes(pebibytes)

        // WHEN
        let recBytes = displayPebibytes.toKibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedKibibytes)
    }
    
    func testToKibibytesFromExbibytes() {
        // GIVEN
        let exbibytes: Double = 1
        let expectedKibibytes: Double = 1 * 1024 * 1024 * 1024 * 1024 * 1024
        let displayExbibytes = BinaryDisplaySize.exbibytes(exbibytes)

        // WHEN
        let recBytes = displayExbibytes.toKibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedKibibytes)
    }

    
    // MARK: - toMebibytes

    func testToMebibytesFromBytes() {
        // GIVEN
        let bytes: UInt64 = 1 * 1024 * 1024
        let expectedMebibytes: Double = 1
        let displayBytes = BinaryDisplaySize.bytes(bytes)

        // WHEN
        let recBytes = displayBytes.toMebibytes

        // THEN
        XCTAssertEqual(recBytes, expectedMebibytes)
    }

    func testToMebibytesFromKibibytes() {
        // GIVEN
        let kibibytes: Double = 1 * 1024
        let expectedMebibytes: Double = 1
        let displayKibibytes = BinaryDisplaySize.kibibytes(kibibytes)

        // WHEN
        let recBytes = displayKibibytes.toMebibytes

        // THEN
        XCTAssertEqual(recBytes, expectedMebibytes)
    }

    func testToMebibytesFromMebibytes() {
        // GIVEN
        let mebibytes: Double = 1
        let expectedMebibytes: Double = 1
        let displayMebibytes = BinaryDisplaySize.mebibytes(mebibytes)

        // WHEN
        let recBytes = displayMebibytes.toMebibytes

        // THEN
        XCTAssertEqual(recBytes, expectedMebibytes)
    }

    func testToMebibytesFromGibibytes() {
        // GIVEN
        let gibibytes: Double = 1
        let expectedMebibytes: Double = 1 * 1024
        let displayGibibytes = BinaryDisplaySize.gibibytes(gibibytes)

        // WHEN
        let recBytes = displayGibibytes.toMebibytes

        // THEN
        XCTAssertEqual(recBytes, expectedMebibytes)
    }
    
    func testToMebibytesFromTebibytes() {
        // GIVEN
        let tebibytes: Double = 1
        let expectedMebibytes: Double = 1 * 1024 * 1024
        let displayTebibytes = BinaryDisplaySize.tebibytes(tebibytes)

        // WHEN
        let recBytes = displayTebibytes.toMebibytes

        // THEN
        XCTAssertEqual(recBytes, expectedMebibytes)
    }
    
    func testToMebibytesFromPebibytes() {
        // GIVEN
        let pebibytes: Double = 1
        let expectedMebibytes: Double = 1 * 1024 * 1024 * 1024
        let displayPebibytes = BinaryDisplaySize.pebibytes(pebibytes)

        // WHEN
        let recBytes = displayPebibytes.toMebibytes

        // THEN
        XCTAssertEqual(recBytes, expectedMebibytes)
    }
    
    func testToMebibytesFromExbibytes() {
        // GIVEN
        let exbibytes: Double = 1
        let expectedMebibytes: Double = 1 * 1024 * 1024 * 1024 * 1024
        let displayExbibytes = BinaryDisplaySize.exbibytes(exbibytes)

        // WHEN
        let recBytes = displayExbibytes.toMebibytes

        // THEN
        XCTAssertEqual(recBytes, expectedMebibytes)
    }

    // MARK: - toGibibytes

    func testToGigabytesFromBytes() {
        // GIVEN
        let bytes: UInt64 = 1 * 1024 * 1024 * 1024
        let expectedGibibytes: Double = 1
        let displayBytes = BinaryDisplaySize.bytes(bytes)

        // WHEN
        let recBytes = displayBytes.toGibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedGibibytes)
    }

    func testToGigabytesFromKibibytes() {
        // GIVEN
        let kibibytes: Double = 1 * 1024 * 1024
        let expectedGibibytes: Double = 1
        let displayKibibytes = BinaryDisplaySize.kibibytes(kibibytes)

        // WHEN
        let recBytes = displayKibibytes.toGibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedGibibytes)
    }

    func testToGigabytesFromMebibytes() {
        // GIVEN
        let mebibytes: Double = 1 * 1024
        let expectedGibibytes: Double = 1
        let displayMebibytes = BinaryDisplaySize.mebibytes(mebibytes)

        // WHEN
        let recBytes = displayMebibytes.toGibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedGibibytes)
    }

    func testToGigabytesFromGibibytes() {
        // GIVEN
        let gibibytes: Double = 1
        let expectedGibibytes: Double = 1
        let displayGibibytes = BinaryDisplaySize.gibibytes(gibibytes)

        // WHEN
        let recBytes = displayGibibytes.toGibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedGibibytes)
    }
    
    func testToGigabytesFromTebibytes() {
        // GIVEN
        let tebibytes: Double = 1
        let expectedGibibytes: Double = 1 * 1024
        let displayTebibytes = BinaryDisplaySize.tebibytes(tebibytes)

        // WHEN
        let recBytes = displayTebibytes.toGibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedGibibytes)
    }
    
    func testToGigabytesFromPebibytes() {
        // GIVEN
        let pebibytes: Double = 1
        let expectedGibibytes: Double = 1 * 1024 * 1024
        let displayPebibytes = BinaryDisplaySize.pebibytes(pebibytes)

        // WHEN
        let recBytes = displayPebibytes.toGibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedGibibytes)
    }
    
    func testToGigabytesFromExbibytes() {
        // GIVEN
        let exbibytes: Double = 1
        let expectedGibibytes: Double = 1 * 1024 * 1024 * 1024
        let displayExbibytes = BinaryDisplaySize.exbibytes(exbibytes)

        // WHEN
        let recBytes = displayExbibytes.toGibibytes

        // THEN
        XCTAssertEqual(recBytes, expectedGibibytes)
    }
    
}
