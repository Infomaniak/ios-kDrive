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

        let footerView = SelectPhotoFormatFooterView.instantiate()
        tableView.tableFooterView = footerView
        tableView.sectionHeaderHeight = 0
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let footerView = tableView.tableFooterView else {
            return
        }

        let width = tableView.bounds.size.width
        let size = footerView.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height))

        if footerView.frame.size.height != size.height {
            footerView.frame.size.height = size.height
            tableView.tableFooterView = footerView
        }
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
    func numberOfSections(in _: UITableView) -> Int {
        return tableContent.count
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: SelectionTableViewCell.self, for: indexPath)
        let photoFormat = tableContent[indexPath.section]
        cell.label.text = photoFormat.selectionTitle
        if photoFormat == selectedFormat {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SelectPhotoFormatViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.didSelectPhotoFormat(tableContent[indexPath.section])
        navigationController?.popViewController(animated: true)
    }
}
