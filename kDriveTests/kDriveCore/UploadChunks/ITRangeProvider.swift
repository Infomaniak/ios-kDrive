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

/// Integration Tests of the RangeProvider
final class ITRangeProvider: XCTestCase {
    override class func setUp() {
        super.setUp()
        MockingHelper.clearRegisteredTypes()
        MockingHelper.registerConcreteTypes(configuration: .minimal)
    }

    /// Image from wikimedia under CC.
    static let file = "Matterhorn_as_seen_from_Zermatt,_Wallis,_Switzerland,_2012_August,Wikimedia_Commons"

    // MARK: - allRanges

    /// Here I test that I can chunk a file and re-glue it together.
    func testAllRanges_image() throws {
        // GIVEN
        let bundle = Bundle(for: type(of: self))
        guard let path = bundle.path(forResource: Self.file, ofType: "jpg"),
              let imageData = NSData(contentsOfFile: path) else {
            XCTFail("unexpected")
            return
        }

        guard let pathURL = bundle.url(forResource: Self.file, withExtension: "jpg") else {
            XCTFail("unexpected")
            return
        }

        let rangeProvider = RangeProvider(fileURL: pathURL)

        // WHEN
        do {
            let ranges = try rangeProvider.allRanges

            // THEN
            XCTAssertNotNil(ranges)
            try UTRangeProviderGuts.checkContinuity(ranges: ranges)
        } catch {
            XCTFail("Unexpected \(error)")
        }

        // THEN
        XCTAssertNotNil(rangeProvider)
        XCTAssertNotNil(imageData)
    }
}
