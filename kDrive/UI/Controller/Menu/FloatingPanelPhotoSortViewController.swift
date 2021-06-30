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
import FloatingPanel
import kDriveCore

protocol PhotoSortDelegate: AnyObject {
    func didSelect(sortMode: PhotoSortMode)
}

class FloatingPanelPhotoSortViewController: UITableViewController, FloatingPanelControllerDelegate {

    let tableContent: [PhotoSortMode] = PhotoSortMode.allCases

    var selectedSortMode: PhotoSortMode!
    weak var delegate: PhotoSortDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: FloatingPanelSortOptionTableViewCell.self)
        tableView.separatorColor = .clear
        tableView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
        let selectedIndex = (tableContent.firstIndex(where: { $0 == selectedSortMode }) ?? 0) + 1
        tableView.selectRow(at: IndexPath(row: selectedIndex, section: 0), animated: false, scrollPosition: .none)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableContent.count + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: FloatingPanelSortOptionTableViewCell.self, for: indexPath)
        if indexPath.row == 0 {
            cell.titleLabel.text = KDriveStrings.Localizable.sortTitle
            cell.isHeader = true
        } else {
            cell.titleLabel.text = tableContent[indexPath.row - 1].title
            cell.separator?.isHidden = true
            cell.isHeader = false
        }
        cell.setAccessibility()
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row != 0 else { return }
        delegate?.didSelect(sortMode: tableContent[indexPath.row - 1])
        dismiss(animated: true)
    }

    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout {
        return PlusButtonFloatingPanelLayout(height: min(260 + view.safeAreaInsets.bottom, UIScreen.main.bounds.size.height - 48))
    }
}
