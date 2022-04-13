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

protocol RoundedCornersList {
    func reloadCorners(insertions: [Int], deletions: [Int], count: Int)
    func reloadList(with modifications: [IndexPath])
}

extension RoundedCornersList {
    func reloadCorners(insertions: [Int], deletions: [Int], count: Int) {
        var modifications = Set<IndexPath>()
        if insertions.contains(0) {
            modifications.insert(IndexPath(row: 1, section: 0))
        }
        if deletions.contains(0) {
            modifications.insert(IndexPath(row: 0, section: 0))
        }
        if insertions.contains(count - 1) {
            modifications.insert(IndexPath(row: count - 2, section: 0))
        }
        if deletions.contains(count) {
            modifications.insert(IndexPath(row: count - 1, section: 0))
        }
        reloadList(with: Array(modifications))
    }
}

extension UICollectionView: RoundedCornersList {
    func reloadList(with modifications: [IndexPath]) {
        reloadItems(at: modifications)
    }
}

extension UITableView: RoundedCornersList {
    func reloadList(with modifications: [IndexPath]) {
        reloadRows(at: modifications, with: .fade)
    }
}
