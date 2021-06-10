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
import kDriveCore

protocol FooterButtonDelegate: AnyObject {
    func didClickOnButton()
}

class FooterButtonView: UITableViewHeaderFooterView {

    @IBOutlet weak var footerButton: IKLargeButton!
    @IBOutlet weak var background: UIView!
    weak var delegate: FooterButtonDelegate?

    override class func awakeFromNib() {
        super.awakeFromNib()

    }

    @IBAction func buttonClicked(_ sender: IKLargeButton) {
        delegate?.didClickOnButton()
    }

    class func instantiate(title: String = "") -> FooterButtonView {
        let view = Bundle.main.loadNibNamed("FooterButtonView", owner: nil, options: nil)![0] as! FooterButtonView
        view.footerButton.setTitle(title, for: .normal)
        return view
    }

}
