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
import UIKit

protocol SelectPhotoFormatDelegate: AnyObject {
    func didSelectPhotoFormat(_ format: PhotoFileFormat)
}

class SelectPhotoFormatViewController: UIViewController {
    @IBOutlet var tableView: UITableView!

    private var tableContent: [PhotoFileFormat] = [.jpg, .heic]
    private var selectedFormat: PhotoFileFormat!

    weak var delegate: SelectPhotoFormatDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: SelectionTableViewCell.self)
    }

    static func instantiate(selectedFormat: PhotoFileFormat) -> SelectPhotoFormatViewController {
        let viewController = Storyboard.saveFile
            .instantiateViewController(withIdentifier: "SelectImageFormatViewController") as! SelectPhotoFormatViewController
        viewController.selectedFormat = selectedFormat
        return viewController
    }
}

// MARK: - UITableViewDataSource

extension SelectPhotoFormatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableContent.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: SelectionTableViewCell.self, for: indexPath)
        let photoFormat = tableContent[indexPath.row]
        cell.label.text = photoFormat.selectionTitle
        if photoFormat == selectedFormat {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = SelectPhotoFormatFooterView.instantiate()
        return footerView
    }
}

// MARK: - UITableViewDelegate

extension SelectPhotoFormatViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.didSelectPhotoFormat(tableContent[indexPath.row])
        navigationController?.popViewController(animated: true)
    }
}
