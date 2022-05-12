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
    @IBOutlet weak var tableView: UITableView!

    private var tableContent: [PhotoFileFormat] = [.jpg, .heic]
    private var selectedFormat: PhotoFileFormat!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: SelectionTableViewCell.self)
    }

    static func instantiate(selectedFormat: PhotoFileFormat?) -> SelectPhotoFormatViewController {
        let viewController = Storyboard.saveFile.instantiateViewController(withIdentifier: "SelectImageFormatViewController") as! SelectPhotoFormatViewController
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
        let currentFormat = tableContent[indexPath.row]
        cell.label.text = currentFormat.title
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SelectPhotoFormatViewController: UITableViewDelegate {

}
