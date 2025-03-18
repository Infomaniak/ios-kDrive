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

protocol FooterButtonDelegate: AnyObject {
    func didClickOnButton(_ sender: IKLargeButton)
}

class FooterButtonView: UITableViewHeaderFooterView {
    @IBOutlet var footerButton: IKLargeButton!
    @IBOutlet var background: UIView!
    weak var delegate: FooterButtonDelegate?

    @IBAction func buttonClicked(_ sender: IKLargeButton) {
        delegate?.didClickOnButton(sender)
    }

    class func instantiate(title: String = "") -> FooterButtonView {
        let view = Bundle.main.loadNibNamed("FooterButtonView", owner: nil, options: nil)![0] as! FooterButtonView
        UIView.performWithoutAnimation {
            view.footerButton.setTitle(title, for: .normal)
            view.footerButton.layoutIfNeeded()
        }
        return view
    }
}
