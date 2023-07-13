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

import kDriveResources
import UIKit

public extension NSMutableAttributedString {
    convenience init(string: String, boldText: String, color: UIColor? = nil) {
        self.init(string: string)
        let range = (string as NSString).localizedStandardRange(of: boldText)
        addAttribute(.strokeWidth, value: NSNumber(value: -3.0), range: range)
        if let color {
            addAttribute(.foregroundColor, value: color, range: range)
        }
    }

    convenience init(string: String, highlightedText: String) {
        self.init(string: string)
        addAttribute(
            .foregroundColor,
            value: KDriveResourcesAsset.infomaniakColor.color,
            range: (string as NSString).localizedStandardRange(of: highlightedText)
        )
    }
}
