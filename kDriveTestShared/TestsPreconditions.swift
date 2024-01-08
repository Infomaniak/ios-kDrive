/*
 Infomaniak Mail - iOS App
 Copyright (C) 2022 Infomaniak Network SA

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

/// Sanity checks of SWIFT_ACTIVE_COMPILATION_CONDITIONS
final class TestsPreconditions: XCTestCase {
    func testTestFlagIsSet() {
        // WHEN
        #if !TEST
        XCTFail("the TEST flag is expected to be set in test target")
        #endif
    }

    func testDebugFlagIsSet() {
        // WHEN
        #if !DEBUG
        XCTFail("the DEBUG flag is expected to be set in test target")
        #endif
    }
}
