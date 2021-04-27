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
import InfomaniakLogin
import InfomaniakCore
import kDriveCore

class NoDriveViewController: UIViewController {

    @IBOutlet weak var circleView: UIView!
    @IBOutlet weak var otherProfileButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCircleView()
    }

    @IBAction func testButtonPressed(_ sender: Any) {
        if let url = URL(string: ApiRoutes.orderDrive()) {
            UIApplication.shared.open(url)
        }
    }

    @IBAction func otherProfileButtonPressed(_ sender: Any) {
        dismiss(animated: true)
    }

    private func setupCircleView() {
        circleView.cornerRadius = circleView.bounds.width / 2
    }

    class func instantiate() -> NoDriveViewController {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "NoDriveViewController") as! NoDriveViewController
    }
}
