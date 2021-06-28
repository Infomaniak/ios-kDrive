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

protocol TrashOptionsDelegate: AnyObject {
    func didClickOnTrashOption(option: TrashOption, files: [File])
}

enum TrashOption: CaseIterable {
    case restoreIn, restore, delete

    var title: String {
        switch self {
        case .restoreIn:
            return KDriveStrings.Localizable.trashActionRestoreFileIn
        case .restore:
            return KDriveStrings.Localizable.trashActionRestoreFileOriginalPlace
        case .delete:
            return KDriveStrings.Localizable.trashActionDelete
        }
    }

    var icon: UIImage {
        switch self {
        case .restore, .restoreIn:
            return KDriveAsset.refresh.image
        case .delete:
            return KDriveAsset.delete.image
        }
    }
}

class TrashFloatingPanelTableViewController: UITableViewController, FloatingPanelControllerDelegate {

    weak var delegate: TrashOptionsDelegate?
    var trashedFiles: [File]!

    let tableContent = TrashOption.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.separatorColor = .clear
        tableView.alwaysBounceVertical = false
        tableView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
        tableView.register(cellView: FloatingPanelTableViewCell.self)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableContent.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: FloatingPanelTableViewCell.self, for: indexPath)
        let option = tableContent[indexPath.row]
        cell.titleLabel.text = option.title
        cell.accessoryImageView.image = option.icon
        cell.accessoryImageView.tintColor = KDriveAsset.iconColor.color
        cell.separator?.isHidden = true

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dismiss(animated: false)
        delegate?.didClickOnTrashOption(option: tableContent[indexPath.row], files: trashedFiles)
    }
}
