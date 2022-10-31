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
import kDriveResources
import UIKit

class HomeLastPicCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var contentInsetView: UIView!
    @IBOutlet weak var fileImage: UIImageView!
    @IBOutlet weak var darkLayer: UIView!
    @IBOutlet weak var checkmarkImage: UIImageView!
    @IBOutlet weak var videoData: UIView!
    @IBOutlet weak var durationLabel: IKLabel!

    override var isSelected: Bool {
        didSet {
            configureForSelection()
        }
    }

    var selectionMode = false
    var file: File?

    override func awakeFromNib() {
        super.awakeFromNib()
        fileImage.layer.masksToBounds = true
        darkLayer.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        darkLayer.isHidden = true
        fileImage.image = nil
        fileImage.backgroundColor = nil
    }

    override var isHighlighted: Bool {
        didSet {
            darkLayer.isHidden = !isHighlighted
        }
    }

    func configureLoading() {
        darkLayer.isHidden = true
        checkmarkImage.isHidden = true
        fileImage.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color
        contentInsetView.cornerRadius = UIConstants.cornerRadius
    }

    func configureWith(file: File, roundedCorners: Bool = true, selectionMode: Bool = false) {
        self.selectionMode = selectionMode
        self.file = file
        checkmarkImage.isHidden = !selectionMode
        darkLayer.isHidden = false
        file.getThumbnail { [weak self, fileId = file.id] image, isThumbnail in
            if fileId == self?.file?.id {
                self?.darkLayer.isHidden = true
                self?.fileImage.image = isThumbnail ? image : KDriveResourcesAsset.fileImageSmall.image
            }
        }
        accessibilityLabel = file.name
        isAccessibilityElement = true
        if roundedCorners {
            contentInsetView.cornerRadius = UIConstants.cornerRadius
        }
        configureForVideo()
        configureForSelection()
    }

    private func configureForSelection() {
        guard selectionMode else { return }
        checkmarkImage.image = isSelected ? KDriveResourcesAsset.select.image : FileCollectionViewCell.emptyCheckmarkImage
    }

    private func configureForVideo() {
        if file?.uti.conforms(to: .video) == true || file?.uti.conforms(to: .movie) == true {
            let gradient = CAGradientLayer()
            gradient.frame = videoData.bounds
            gradient.colors = [
                UIColor.black.withAlphaComponent(0).cgColor,
                UIColor.black.cgColor
            ]
            videoData.layer.insertSublayer(gradient, at: 0)
            videoData.isHidden = false
        } else {
            videoData.isHidden = true
        }
    }
}
