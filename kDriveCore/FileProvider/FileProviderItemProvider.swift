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

import FileProvider
import Foundation

/// Something to standardise the bridge from Realm Objects to `FileProvider` DTOs
protocol FileProviderItemProvider {
    /// Anything  _to_ FileProvider DTO
    func toFileProviderItem(parent: NSFileProviderItemIdentifier?,
                            drive: Drive?,
                            domain: NSFileProviderDomain?) -> NSFileProviderItem
}

/// Something to hide implementation details form the FileProviderExtension
public extension NSFileProviderItem {
    func trashModifier(newValue: Bool) {
        if let item = self as? FileProviderItem {
            item.isTrashed = newValue
        } else if let item = self as? UploadFileProviderItem {
            item.isTrashed = newValue
        } else {
            fatalError("unsupported type")
        }
    }

    func favoriteRankModifier(newValue: NSNumber?) {
        if let item = self as? FileProviderItem {
            item.favoriteRank = newValue
        } else if let item = self as? UploadFileProviderItem {
            item.favoriteRank = newValue
        } else {
            fatalError("unsupported type")
        }
    }
}
