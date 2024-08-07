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
    /// Category identifier
    @Persisted public var categoryId: Int
    /// Whether the Category was generated by an AI or not
    @Persisted public var isGeneratedByAI: Bool
    /// State of user validation after auto assignment from AI
    @Persisted public var userValidation: String
    /// User identifier
    @Persisted public var userId: Int?
    /// Date when the category was added to file
    @Persisted public var addedAt: Date

    public func isContentEqual(to source: FileCategory) -> Bool {
        return categoryId == source.categoryId
    }

    convenience init(
        categoryId: Int,
        isGeneratedByAI: Bool = false,
        userValidation: String = "CORRECT",
        userId: Int?,
        addedAt: Date = Date()
    ) {
        self.init()
        self.categoryId = categoryId
        self.isGeneratedByAI = isGeneratedByAI
        self.userValidation = userValidation
        self.userId = userId
        self.addedAt = addedAt
    }

    enum CodingKeys: String, CodingKey {
        case categoryId
        case isGeneratedByAI = "isGeneratedByAi"
        case userValidation
        case userId
        case addedAt
    }
}
