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

struct ProductIdentifiers {
    let name = "ProductIds"
    let fileExtension = "plist"

    var isEmpty: String {
        return "\(name).\(fileExtension) is empty."
    }

    var wasNotFound: String {
        return "Could not find resource file: \(name).\(fileExtension)."
    }

    /// An array with the product identifiers to be queried.
    var identifiers: [String]? {
        guard let path = Bundle.main.path(forResource: name, ofType: fileExtension) else { return nil }
        return NSArray(contentsOfFile: path) as? [String]
    }
}
