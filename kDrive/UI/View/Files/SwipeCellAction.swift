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

import kDriveCore
import kDriveResources
import UIKit

enum SwipeCellActionIdentifier: String {
    case share
    case delete
}

struct SwipeCellAction: Equatable {
    let identifier: SwipeCellActionIdentifier
    let title: String
    let backgroundColor: UIColor
    let icon: UIImage

    static func == (lhs: SwipeCellAction, rhs: SwipeCellAction) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

extension SwipeCellAction {
    static let share = SwipeCellAction(
        identifier: .share,
        title: KDriveResourcesStrings.Localizable.buttonFileRights,
        backgroundColor: KDriveResourcesAsset.infomaniakColor.color,
        icon: KDriveResourcesAsset.share.image
    )
    static let delete = SwipeCellAction(
        identifier: .delete,
        title: KDriveResourcesStrings.Localizable.buttonDelete,
        backgroundColor: KDriveResourcesAsset.binColor.color,
        icon: KDriveResourcesAsset.delete.image
    )
}

extension SortType: Selectable {
    var title: String {
        return value.translation
    }
}
