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

/// XCTAssert messages
enum TestsMessages {
    static let noError = "There should be no error"
    static let shouldReturnTrue = "API should return true"

    static func notNil(_ element: String) -> String {
        return "\(element.capitalized) shouldn't be nil"
    }

    static func failedToCreate(_ element: String) -> String {
        "Failed to create \(element)"
    }

    static func failedToDelete(_ element: String) -> String {
        return "Failed to delete \(element)"
    }
}
