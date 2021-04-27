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

class RecentActivityCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var contentInsetView: UIView!
    @IBOutlet weak var previewImage: UIImageView!
    @IBOutlet weak var moreLabel: UILabel!
    @IBOutlet weak var darkLayer: UIView!
    @IBOutlet weak var noPreviewView: UIView!
    @IBOutlet weak var logoContainerView: UIView!
    @IBOutlet weak var logoImage: UIImageView!

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
        previewImage.backgroundColor = KDriveAsset.backgroundColor.color
        let fileId = file.id
        file.getThumbnail { (image, _) in
            if fileId == file.id {
                self.previewImage.image = image
                self.previewImage.backgroundColor = nil
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
        logoImage.image = file?.icon ?? KDriveCoreAsset.fileDefault.image
        logoImage.tintColor = KDriveAsset.infomaniakColor.color
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
        previewImage.backgroundColor = KDriveAsset.loaderDarkerDefaultColor.color
    }
}
