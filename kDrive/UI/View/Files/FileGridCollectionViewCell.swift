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

final class FileGridViewModel: FileViewModel {
    var iconImageHidden: Bool { file.isDirectory }

    var hasThumbnail: Bool { !file.isDirectory && file.supportedBy.contains(.thumbnail) }

    var shouldCenterTitle: Bool { file.isDirectory }

    override func setThumbnail(on imageView: UIImageView) {
        imageView.image = nil
        imageView.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color
        thumbnailDownloadTask?.cancel()
        thumbnailDownloadTask = file.getThumbnail { image, _ in
            imageView.image = image
            imageView.backgroundColor = nil
        }
    }
}

class FileGridCollectionViewCell: FileCollectionViewCell {
    @IBOutlet weak var _checkmarkImage: UIImageView!
    @IBOutlet weak var largeIconImageView: UIImageView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet var stackViewCenterConstraint: NSLayoutConstraint?

    override var checkmarkImage: UIImageView? {
        return _checkmarkImage
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        logoImage.layer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentInsetView.cornerRadius = UIConstants.cornerRadius
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        titleLabel.textAlignment = .natural
        stackViewCenterConstraint?.isActive = false
        largeIconImageView.isHidden = true
        logoImage.isHidden = false
        logoImage.backgroundColor = nil
        iconImageView.backgroundColor = nil
    }

    override func initStyle(isFirst: Bool, isLast: Bool) {
        // META: keep SonarCloud happy
    }

    override func configure(with viewModel: FileViewModel) {
        super.configure(with: viewModel)
        guard let viewModel = viewModel as? FileGridViewModel else { return }
        iconImageView.isHidden = viewModel.iconImageHidden
        if viewModel.isImporting {
            logoImage.isHidden = true
            largeIconImageView.isHidden = true
            importProgressView?.isHidden = false
            importProgressView?.enableIndeterminate()
            moreButton.tintColor = KDriveResourcesAsset.primaryTextColor.color
            moreButton.backgroundColor = nil
        } else if viewModel.hasThumbnail {
            logoImage.isHidden = false
            largeIconImageView.isHidden = true
            iconImageView.isHidden = false
            importProgressView?.isHidden = true
            moreButton.tintColor = .white
            moreButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            moreButton.cornerRadius = moreButton.frame.width / 2
        } else {
            logoImage.isHidden = true
            largeIconImageView.isHidden = false
            importProgressView?.isHidden = true
            moreButton.tintColor = KDriveResourcesAsset.primaryTextColor.color
            moreButton.backgroundColor = nil
        }
        logoImage.contentMode = .scaleAspectFill
        stackViewCenterConstraint?.isActive = viewModel.shouldCenterTitle
        titleLabel.textAlignment = viewModel.shouldCenterTitle ? .center : .natural
        checkmarkImage?.isHidden = !viewModel.selectionMode
        iconImageView.image = viewModel.icon
        iconImageView.tintColor = viewModel.iconTintColor
        largeIconImageView.image = viewModel.icon
        largeIconImageView.tintColor = viewModel.iconTintColor
    }

    override func configureWith(driveFileManager: DriveFileManager, file: File, selectionMode: Bool = false) {
        configure(with: FileGridViewModel(driveFileManager: driveFileManager, file: file, selectionMode: selectionMode))
    }

    override func configureLoading() {
        titleLabel.text = " "
        let titleLayer = CALayer()
        titleLayer.anchorPoint = .zero
        titleLayer.bounds = CGRect(x: 0, y: 0, width: 100, height: 15)
        titleLayer.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color.cgColor
        titleLabel.layer.addSublayer(titleLayer)
        favoriteImageView?.isHidden = true
        logoImage.image = nil
        logoImage.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color
        largeIconImageView.isHidden = true
        iconImageView.isHidden = false
        iconImageView.image = nil
        iconImageView.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color
        moreButton.isHidden = true
        checkmarkImage?.isHidden = true
    }

    override func configureForSelection() {
        guard viewModel?.selectionMode == true else { return }
        configureCheckmarkImage()
    }
}
