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
import kDriveResources
import UIKit

class HomeLargeTitleHeaderView: UICollectionReusableView {
    @IBOutlet var chevronButton: UIButton!
    @IBOutlet var titleButton: IKButton!
    var titleButtonPressedHandler: ((UIButton) -> Void)?

    var text: String? {
        get {
            titleButton.titleLabel?.text
        }
        set {
            UIView.performWithoutAnimation {
                titleButton.setTitle(newValue, for: .normal)
                titleButton.layoutIfNeeded()
            }
        }
    }

    var isEnabled = true {
        didSet {
            chevronButton.isHidden = !isEnabled
            titleButton.isUserInteractionEnabled = isEnabled
        }
    }

    @IBAction func titleButtonPressed(_ sender: UIButton) {
        titleButtonPressedHandler?(sender)
    }

    func configureForDriveSwitch(
        accountManager: AccountManageable,
        driveFileManager: DriveFileManager,
        presenter: SelectSwitchDriveDelegate,
        selectMode: Bool
    ) {
        isEnabled = accountManager.drives.count > 1 && !selectMode
        text = driveFileManager.drive.name
        titleButtonPressedHandler = { [weak self] _ in
            guard let self else { return }
            let drives = accountManager.drives
            let floatingPanelViewController = FloatingPanelSelectOptionViewController<Drive>.instantiatePanel(
                options: drives,
                selectedOption: driveFileManager.drive,
                headerTitle: KDriveResourcesStrings.Localizable.buttonSwitchDrive,
                delegate: presenter
            )
            presenter.present(floatingPanelViewController, animated: true)
        }
    }
}
