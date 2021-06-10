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

extension URL {
    public var typeIdentifier: UTI? {
        if hasDirectoryPath {
            return .folder
        }
        if let uti = try? resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
            return UTI(uti)
        }
        /*if #available(iOS 14.0, *) {
            let identifier = UTType(filenameExtension: pathExtension, conformingTo: .item)?.identifier
            return identifier
        } else {*/
        return UTI(filenameExtension: pathExtension, conformingTo: .item)
        // }
    }

    public var creationDate: Date? {
        return try? resourceValues(forKeys: [.creationDateKey]).creationDate
    }
}
