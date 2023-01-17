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
    override func setUpWithError() throws {
        // usualy prepare mocking solver
    }
    
    override func tearDownWithError() throws {
        // usualy teardown mocking solver so the next test is stable
    }

    func testAllRanges_zeroes() throws {
        // GIVEN
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        var rangeProvider = RangeProvider(fileURL: stubURL)
        let mckGuts = MCKRangeProviderGuts( /* all zeroes by default */ )
        
        rangeProvider.guts = mckGuts
        
        // WHEN
        do {
            let _ = try rangeProvider.allRanges
            
            // THEN
            XCTFail("Unexpected")
        } catch {
            // success if some execption has shown
        }
    }
    
    func testAllRanges_FileTooSmall() throws {
        // GIVEN
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        var rangeProvider = RangeProvider(fileURL: stubURL)
        let mckGuts = MCKRangeProviderGuts()
        mckGuts.readFileByteSizeReturnValue = 1024
        
        rangeProvider.guts = mckGuts
        
        // WHEN
        do {
            let _ = try rangeProvider.allRanges
            
            // THEN
            XCTFail("Unexpected")
        } catch {
            // Expecting a .FileTooSmall error
            guard case .FileTooSmall = error as? RangeProvider.ErrorDomain else {
                XCTFail("Unexpected")
                return
            }
            
            // success
        }
    }
    
    func testAllRanges_FileExactlyMinSize() throws {
        // GIVEN
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        var rangeProvider = RangeProvider(fileURL: stubURL)
        let mckGuts = MCKRangeProviderGuts()
        mckGuts.readFileByteSizeReturnValue = RangeProvider.APIConsts.chunkMinSize
        
        rangeProvider.guts = mckGuts
        
        // WHEN
        do {
            let _ = try rangeProvider.allRanges
            
            // THEN
            XCTFail("Unexpected")
        } catch {
            // Expecting a .FileTooSmall error
            guard case .FileTooSmall = error as? RangeProvider.ErrorDomain else {
                XCTFail("Unexpected")
                return
            }
            
            // success
        }
    }
    
    func testAllRanges_FileTooLarge() throws {
        // GIVEN
        let stubURL = URL(string: "file:///Arcalod_2117.jpg")!
        var rangeProvider = RangeProvider(fileURL: stubURL)
        let mckGuts = MCKRangeProviderGuts()
        mckGuts.readFileByteSizeReturnValue = RangeProvider.APIConsts.fileMaxSize + 1
        rangeProvider.guts = mckGuts
        
        // WHEN
        do {
            let _ = try rangeProvider.allRanges
            
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
        let mckGuts = MCKRangeProviderGuts()
        mckGuts.readFileByteSizeReturnValue = RangeProvider.APIConsts.chunkMinSize + 1
        mckGuts.preferedChunkSizeReturnValue = 1 * 1024 * 1024
        
        rangeProvider.guts = mckGuts
        
        // WHEN
        do {
            let ranges = try rangeProvider.allRanges
            
            // THEN
            XCTAssertNotNil(ranges)
            XCTAssertEqual(ranges.count, 0)
            
            XCTAssertTrue(mckGuts.buildRangesCalled)
            XCTAssertTrue(mckGuts.preferedChunkSizeCalled)
            XCTAssertTrue(mckGuts.readFileByteSizeCalled)
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }
}
