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

import DifferenceKit
import Foundation
import RealmSwift

public class FileCategory: EmbeddedObject, Codable, ContentEquatable {
    @Persisted public var id: Int
    @Persisted public var isGeneratedByIA: Bool
    @Persisted public var IACategoryUserValidation: String
    @Persisted public var userId: Int?
    @Persisted public var addedToFileAt: Date

    public func isContentEqual(to source: FileCategory) -> Bool {
        return id == source.id
    }

    convenience init(id: Int, isGeneratedByIA: Bool = false, IACategoryUserValidation: String = "CORRECT", userId: Int?, addedToFileAt: Date = Date()) {
        self.init()
        self.id = id
        self.isGeneratedByIA = isGeneratedByIA
        self.IACategoryUserValidation = IACategoryUserValidation
        self.userId = userId
        self.addedToFileAt = addedToFileAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case isGeneratedByIA = "is_generated_by_ia"
        case IACategoryUserValidation = "ia_category_user_validation"
        case userId = "user_id"
        case addedToFileAt = "added_to_file_at"
    }
}
