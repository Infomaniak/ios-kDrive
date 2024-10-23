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

import InfomaniakCoreUIKit
import kDriveCore
import UIKit

protocol StoreStorageDelegate: AnyObject {
    func storageDidChange(_ newValue: Int)
}

class StoreStorageTableViewCell: UITableViewCell {
    @IBOutlet var storageValueLabel: IKLabel!
    @IBOutlet var slider: UISlider!
    @IBOutlet var containerView: UIView!

    weak var delegate: StoreStorageDelegate?

    let step: Float = 5
    let offset: Float = 3
    let unit: Int64 = 1_099_511_627_776 // Terabyte

    override func awakeFromNib() {
        super.awakeFromNib()

        containerView.cornerRadius = UIConstants.cornerRadius
        slider.value = 3
        updateStorageValue(slider.value)
    }

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        // Round value
        let roundedValue = floor(sender.value / step) * step + offset
        sender.value = roundedValue
        // Update label
        updateStorageValue(roundedValue)
        delegate?.storageDidChange(Int(roundedValue))
    }

    private func updateStorageValue(_ newValue: Float) {
        storageValueLabel.text = Constants.formatFileSize(Int64(newValue) * unit)
    }
}
