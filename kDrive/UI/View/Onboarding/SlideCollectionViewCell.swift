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
import Lottie
import UIKit

class SlideCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var illustrationAnimationView: AnimationView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var animationViewTopConstraint: NSLayoutConstraint!

    var isSmallDevice = false

    override func layoutSubviews() {
        super.layoutSubviews()
        if isSmallDevice {
            animationViewTopConstraint.constant = 170
        }
    }

    func configureCell(slide: Slide, isSmallDevice: Bool = false) {
        backgroundImageView.image = slide.backgroundImage
        backgroundImageView.tintColor = KDriveResourcesAsset.backgroundColor.color
        illustrationAnimationView.animation = Animation.named(slide.animationName)
        titleLabel.text = slide.title
        descriptionLabel.text = slide.description
    }
}
