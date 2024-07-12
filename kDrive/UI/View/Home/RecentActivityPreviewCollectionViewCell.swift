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

class RecentActivityPreviewCollectionViewCell: UICollectionViewCell {
    @IBOutlet var contentInsetView: UIView!
    @IBOutlet var previewImage: UIImageView!
    @IBOutlet var moreLabel: UILabel!
    @IBOutlet var darkLayer: UIView!
    @IBOutlet var noPreviewView: UIView!
    @IBOutlet var logoContainerView: UIView!
    @IBOutlet var logoImage: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        moreLabel.isHidden = true
        darkLayer.isHidden = true
        noPreviewView.isHidden = true
        logoContainerView.cornerRadius = logoContainerView.frame.width / 2
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        moreLabel.isHidden = true
        darkLayer.isHidden = true
    }

    override var isHighlighted: Bool {
        didSet {
            setHighlighting()
        }
    }

    func setHighlighting() {
        let hasDarkLayer = !moreLabel.isHidden
        if isHighlighted {
            darkLayer.alpha = hasDarkLayer ? 0.6 : 0.4
            darkLayer.isHidden = false
        } else {
            darkLayer.isHidden = !hasDarkLayer
            darkLayer.alpha = 0.5
        }
    }

    func configureWithPreview(file: File, more: Int?) {
        previewImage.isHidden = false
        noPreviewView.isHidden = true
        previewImage.image = nil
        previewImage.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        let fileId = file.id
        file.getThumbnail { [weak self] image, _ in
            if fileId == file.id {
                self?.previewImage.image = image
                self?.previewImage.backgroundColor = nil
            }
        }
        if let count = more {
            setMoreLabel(count: count)
            accessibilityLabel = "\(file.name) +\(count)"
        } else {
            accessibilityLabel = file.name
        }
        isAccessibilityElement = true
    }

    func configureWithoutPreview(file: File?, more: Int?) {
        previewImage.isHidden = true
        noPreviewView.isHidden = false
        if let file {
            logoImage.image = file.icon
            logoImage.tintColor = file.tintColor
        } else {
            logoImage.image = ConvertedType.unknown.icon
            logoImage.tintColor = ConvertedType.unknown.tintColor
        }
        accessibilityLabel = file?.name
        if let count = more {
            setMoreLabel(count: count)
            if let name = file?.name {
                accessibilityLabel = "\(name) +\(count)"
            } else {
                accessibilityLabel = "+\(count)"
            }
        } else {
            accessibilityLabel = file?.name
        }
        isAccessibilityElement = true
    }

    private func setMoreLabel(count: Int) {
        darkLayer.isHidden = false
        moreLabel.isHidden = false
        moreLabel.text = "+\(count)"
    }

    func configureLoading() {
        previewImage.isHidden = false
        noPreviewView.isHidden = true
        previewImage.image = nil
        previewImage.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color
    }
}
