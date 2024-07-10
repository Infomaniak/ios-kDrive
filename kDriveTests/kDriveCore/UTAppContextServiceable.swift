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

final class UTAppContextServiceable: XCTestCase {
    override func setUp() {
        MockingHelper.clearRegisteredTypes()
        MockingHelper.registerConcreteTypes(configuration: .minimal)
    }

    func testIsExtension_app() {
        // GIVEN
        let appContextService = AppContextService(context: .app)

        // WHEN
        let isExtension = appContextService.isExtension

        // THEN
        XCTAssertFalse(isExtension, "Should not be an extension")
    }

    func testIsExtension_appTests() {
        // GIVEN
        let appContextService = AppContextService(context: .appTests)

        // WHEN
        let isExtension = appContextService.isExtension

        // THEN
        XCTAssertFalse(isExtension, "Should not be an extension")
    }

    func testIsExtension_actionExtension() {
        // GIVEN
        let appContextService = AppContextService(context: .actionExtension)

        // WHEN
        let isExtension = appContextService.isExtension

        // THEN
        XCTAssertTrue(isExtension, "Should be an extension")
    }

    func testIsExtension_fileProviderExtension() {
        // GIVEN
        let appContextService = AppContextService(context: .fileProviderExtension)

        // WHEN
        let isExtension = appContextService.isExtension

        // THEN
        XCTAssertTrue(isExtension, "Should be an extension")
    }

    func testIsExtension_shareExtension() {
        // GIVEN
        let appContextService = AppContextService(context: .shareExtension)

        // WHEN
        let isExtension = appContextService.isExtension

        // THEN
        XCTAssertTrue(isExtension, "Should be an extension")
    }
}
