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
import Kingfisher
import UIKit

class HomeLastPicCollectionViewCell: UICollectionViewCell {
    @IBOutlet var contentInsetView: UIView!
    @IBOutlet var fileImage: UIImageView!
    @IBOutlet var highlightView: UIView!
    @IBOutlet var checkmarkImage: UIImageView!
    @IBOutlet var videoGradientView: UIView!

    private var thumbnailDownloadTask: Kingfisher.DownloadTask?
    private let videoGradientLayer = CAGradientLayer()

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
        highlightView.isHidden = true

        videoGradientLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.3).cgColor
        ]
        videoGradientView.layer.insertSublayer(videoGradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard videoGradientLayer.frame.size != videoGradientView.frame.size else { return }
        videoGradientLayer.frame = videoGradientView.frame
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        file = nil
        selectionMode = false
        thumbnailDownloadTask?.cancel()
        highlightView.isHidden = true
        checkmarkImage.isHidden = true
        checkmarkImage.image = nil
        videoGradientView.isHidden = true
        fileImage.image = nil
        fileImage.backgroundColor = nil
    }

    override var isHighlighted: Bool {
        didSet {
            highlightView.isHidden = !isHighlighted
        }
    }

    func configureLoading() {
        highlightView.isHidden = true
        checkmarkImage.isHidden = true
        videoGradientView.isHidden = true
        fileImage.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color
        contentInsetView.cornerRadius = UIConstants.cornerRadius
    }

    func configureWith(file: File, roundedCorners: Bool = true, selectionMode: Bool = false) {
        self.selectionMode = selectionMode
        self.file = file
        checkmarkImage.isHidden = !selectionMode
        highlightView.isHidden = false
        thumbnailDownloadTask = file.getThumbnail { [weak self, fileId = file.id] image, isThumbnail in
            if fileId == self?.file?.id {
                self?.highlightView.isHidden = true
                self?.fileImage.image = isThumbnail ? image : KDriveResourcesAsset.fileImageSmall.image
            }
        }
        accessibilityLabel = file.name
        isAccessibilityElement = true
        if roundedCorners {
            contentInsetView.cornerRadius = UIConstants.cornerRadius
        }
        videoGradientView.isHidden = !(file.uti.conforms(to: .video) || file.uti.conforms(to: .movie))
        configureForSelection()
    }

    private func configureForSelection() {
        guard selectionMode else { return }
        checkmarkImage.image = isSelected ? KDriveResourcesAsset.select.image : FileCollectionViewCell.emptyCheckmarkImage
    }
}
