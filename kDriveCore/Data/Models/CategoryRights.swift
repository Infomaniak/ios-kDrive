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
import RealmSwift

public class CategoryRights: EmbeddedObject, Codable {
    @Persisted public var canCreateCategory: Bool
    @Persisted public var canEditCategory: Bool
    @Persisted public var canDeleteCategory: Bool
    @Persisted public var canReadCategoryOnFile: Bool
    @Persisted public var canPutCategoryOnFile: Bool

    enum CodingKeys: String, CodingKey {
        case canCreateCategory = "can_create_category"
        case canEditCategory = "can_edit_category"
        case canDeleteCategory = "can_delete_category"
        case canReadCategoryOnFile = "can_read_category_on_file"
        case canPutCategoryOnFile = "can_put_category_on_file"
    }
}
