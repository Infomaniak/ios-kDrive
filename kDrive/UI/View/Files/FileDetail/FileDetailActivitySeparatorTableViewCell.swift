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

class FileDetailActivitySeparatorTableViewCell: UITableViewCell {
    @IBOutlet var topSeparator: UIView!
    @IBOutlet var topSeparatorHeight: NSLayoutConstraint!
    @IBOutlet var textView: UIView!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var bottomSeparator: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        topSeparator.isHidden = false
        bottomSeparator.isHidden = false
        topSeparatorHeight.constant = 30
    }
}
