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

import UIKit

class NewFolderShareRuleUserLayout: UICollectionViewFlowLayout {

    var overlap: CGFloat = 10

    override init() {
        super.init()
        self.sharedInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.sharedInit()
    }

    func sharedInit() {
        self.scrollDirection = .vertical
        self.minimumInteritemSpacing = 0
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributesArray = super.layoutAttributesForElements(in: rect)
        for attributes in attributesArray! {
            let xPosition = attributes.center.x
            var yPosition = attributes.center.y
            attributes.zIndex = attributes.indexPath.row

            yPosition -= (overlap + itemSize.height / 6) * CGFloat(attributes.indexPath.row)

            attributes.center = CGPoint(x: xPosition, y: yPosition)
        }
        return attributesArray
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return UICollectionViewLayoutAttributes(forCellWith: indexPath)
    }
}
