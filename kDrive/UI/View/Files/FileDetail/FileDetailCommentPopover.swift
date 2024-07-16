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

class FileDetailCommentPopover: UIViewController {
    @IBOutlet var tableView: UITableView!

    var users: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        tableView.register(cellView: FileDetailCommentListTableViewCell.self)

        tableView.separatorColor = .clear
    }

    class func instantiate() -> FileDetailCommentPopover {
        return Storyboard.files.instantiateViewController(withIdentifier: "FileDetailCommentPopover") as! FileDetailCommentPopover
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension FileDetailCommentPopover: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: FileDetailCommentListTableViewCell.self, for: indexPath)
        cell.userLabel.text = users[indexPath.row]
        cell.selectionStyle = .none
        return cell
    }
}
