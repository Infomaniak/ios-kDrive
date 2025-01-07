/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import UIKit

public class NoDriveUpsaleViewController: UpsaleViewController {
    var onDismissViewController: (() -> Void)?

    override func configureButtons() {
        dismissButton.style = .primaryButton
        freeTrialButton.setTitle(KDriveStrings.Localizable.obtainkDriveAdFreeTrialButton, for: .normal)
        freeTrialButton.addTarget(self, action: #selector(freeTrial), for: .touchUpInside)

        dismissButton.style = .secondaryButton
        dismissButton.setTitle(KDriveStrings.Localizable.buttonLater, for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)
    }

    override func configureHeader() {
        titleImageView.contentMode = .scaleAspectFit
        titleImageView.image = KDriveResourcesAsset.upsaleHeaderNoDrive.image
    }

    @objc public func dismissViewController() {
        dismiss(animated: true, completion: nil)
        onDismissViewController?()
    }
}
