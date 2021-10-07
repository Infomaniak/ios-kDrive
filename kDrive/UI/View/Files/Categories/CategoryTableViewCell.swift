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

import InfomaniakCore
import kDriveCore
import UIKit

protocol CategoryCellDelegate: AnyObject {
    func didTapMoreButton(_ cell: CategoryTableViewCell)
}

class CategoryTableViewCell: InsetTableViewCell {
    @IBOutlet weak var circleImageView: UIImageView!
    @IBOutlet weak var label: IKLabel!
    @IBOutlet weak var moreButton: UIButton!

    weak var delegate: CategoryCellDelegate?

    private var category: kDriveCore.Category!

    override func awakeFromNib() {
        super.awakeFromNib()

        circleImageView.layer.cornerRadius = circleImageView.frame.height / 2
        circleImageView.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if category != nil {
            generateIcon(for: category, selected: selected)
        }
    }

    func configure(with category: kDriveCore.Category, showMoreButton: Bool) {
        self.category = category
        label.text = category.localizedName
        moreButton.isHidden = !showMoreButton
        generateIcon(for: category, selected: isSelected)
    }

    private func generateIcon(for category: kDriveCore.Category, selected: Bool) {
        let size = CGSize(width: 24, height: 24)
        let renderer = UIGraphicsImageRenderer(size: size)
        circleImageView.image = renderer.image { ctx in
            category.color?.setFill()
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            ctx.cgContext.fill(rect)
            if isSelected {
                UIColor.white.setFill()
                KDriveAsset.bigCheck.image.draw(in: CGRect(x: 6.5, y: 8, width: 11, height: 8.5))
            }
        }
    }

    @IBAction func menuButtonPressed(_ sender: UIButton) {
        delegate?.didTapMoreButton(self)
    }
}
