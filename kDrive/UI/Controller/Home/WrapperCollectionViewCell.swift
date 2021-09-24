//
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

class WrapperCollectionViewCell: UICollectionViewCell {
    func initWith<CellClass: UITableViewCell>(cell: CellClass.Type) -> CellClass {
        let cellView = Bundle.main.loadNibNamed(String(describing: cell), owner: nil, options: nil)![0] as! CellClass
        contentView.addSubview(cellView)

        cellView.translatesAutoresizingMaskIntoConstraints = false
        let top = NSLayoutConstraint(item: cellView, attribute: .top, relatedBy: .equal, toItem: contentView, attribute: .top, multiplier: 1, constant: 0)
        let bottom = NSLayoutConstraint(item: cellView, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottom, multiplier: 1, constant: 0)
        let left = NSLayoutConstraint(item: cellView, attribute: .left, relatedBy: .equal, toItem: contentView, attribute: .left, multiplier: 1, constant: 0)
        let right = NSLayoutConstraint(item: cellView, attribute: .right, relatedBy: .equal, toItem: contentView, attribute: .right, multiplier: 1, constant: 0)

        let height = NSLayoutConstraint(item: contentView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: cellView.frame.height)

        NSLayoutConstraint.activate([top, bottom, left, right, height])
        return cellView
    }
}
