/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

public struct CornerCellContainer<Content: Differentiable>: Differentiable {
    public let isFirstInList: Bool
    public let isLastInList: Bool
    public let content: Content

    public init(isFirstInList: Bool, isLastInList: Bool, content: Content) {
        self.isFirstInList = isFirstInList
        self.isLastInList = isLastInList
        self.content = content
    }

    public var differenceIdentifier: some Hashable {
        return content.differenceIdentifier
    }

    public func isContentEqual(to source: CornerCellContainer) -> Bool {
        autoreleasepool {
            isFirstInList == source.isFirstInList
                && isLastInList == source.isLastInList
                && content.isContentEqual(to: source.content)
        }
    }
}
