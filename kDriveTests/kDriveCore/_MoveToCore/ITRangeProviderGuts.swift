//
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

/// Integration Tests of the RangeProviderGuts
final class ITRangeProviderGuts: XCTestCase {
    
    // MARK: - readFileByteSize
    
    func testReadFileByteSize() {
        // GIVEN
        let expectedFileBytes = UInt64(4865229)
        let file = "Matterhorn_as_seen_from_Zermatt,_Wallis,_Switzerland,_2012_August,Wikimedia_Commons"
        let bundle = Bundle(for: type(of: self))
        let pathURL = bundle.url(forResource: file, withExtension: "jpg")!
        let guts = RangeProviderGuts(fileURL: pathURL)
        
        // WHEN
        do {
            let size = try guts.readFileByteSize()
            
            // THEN
            XCTAssertEqual(size, expectedFileBytes)
        } catch {
            XCTFail("Unexpected")
        }
    }
    
    func testReadFileByteSize_FileDoesNotExists() {
        // GIVEN
        let notThereFileURL = URL(string: "file:///Arcalod_2117.jpg")!
        let rangeProvider = RangeProviderGuts(fileURL: notThereFileURL)
        
        // WHEN
        do {
            let _ = try rangeProvider.readFileByteSize()
            
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

    // Covered by UT
    
}
