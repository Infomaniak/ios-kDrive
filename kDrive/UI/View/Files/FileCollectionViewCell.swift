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

protocol FileCellDelegate: AnyObject {
    func didTapMoreButton(_ cell: FileCollectionViewCell)
}

class FileCollectionViewCell: UICollectionViewCell, SwipableCell {

    internal var swipeStartPoint: CGPoint = .zero
    internal var initialTrailingConstraintValue: CGFloat = 0

    @IBOutlet weak var disabledView: UIView!
    @IBOutlet weak var contentInsetView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel?
    @IBOutlet weak var logoImage: UIImageView!
    @IBOutlet weak var accessoryImage: UIImageView?
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var favoriteImageView: UIImageView!
    @IBOutlet weak var availableOfflineImageView: UIImageView!
    @IBOutlet weak var centerTitleConstraint: NSLayoutConstraint!
    @IBOutlet weak var innerViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var innerViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var swipeActionsView: UIStackView?
    @IBOutlet weak var stackViewTrailingConstraint: NSLayoutConstraint?
    @IBOutlet weak var detailsStackView: UIStackView?
    @IBOutlet weak var downloadProgressView: RPCircularProgress?
    @IBOutlet weak var highlightedView: UIView!

    var downloadObservationToken: ObservationToken?
    weak var delegate: FileCellDelegate?

    override var isSelected: Bool {
        didSet {
            configureForSelection()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            setHighlighting()
        }
    }

    var checkmarkImage: UIImageView {
        return logoImage
    }

    var selectionMode = false

    internal var file: File!

    static var emptyCheckmarkImage: UIImage = {
        let size = CGSize(width: 24, height: 24)
        let lineWidth: CGFloat = 1
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            ctx.cgContext.setFillColor(KDriveAsset.backgroundCardViewColor.color.cgColor)
            ctx.cgContext.setStrokeColor(KDriveAsset.borderColor.color.cgColor)
            ctx.cgContext.setLineWidth(lineWidth)

            let diameter = min(size.width, size.height) - lineWidth
            let rect = CGRect(x: (size.width - diameter) / 2, y: (size.height - diameter) / 2, width: diameter, height: diameter)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fillStroke)
        }
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        moreButton.accessibilityLabel = KDriveStrings.Localizable.buttonMenu
        downloadProgressView?.trackTintColor = KDriveAsset.secondaryTextColor.color.withAlphaComponent(0.2)
        downloadProgressView?.progressTintColor = KDriveAsset.infomaniakColor.color
        downloadProgressView?.thicknessRatio = 0.15
        downloadProgressView?.indeterminateProgress = 0.75
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        centerTitleConstraint?.isActive = false
        resetSwipeActions()
        detailLabel?.text = ""
        logoImage.image = nil
        logoImage.contentMode = .scaleAspectFit
        logoImage.layer.cornerRadius = 0
        logoImage.layer.masksToBounds = false
        detailsStackView?.isHidden = false
        availableOfflineImageView?.isHidden = true
        downloadProgressView?.isHidden = true
        downloadProgressView?.updateProgress(0, animated: false)
        downloadObservationToken?.cancel()
    }

    func initStyle(isFirst: Bool, isLast: Bool) {
        if isLast && isFirst {
            contentInsetView.roundCorners(corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner], radius: 10)
        } else if isFirst {
            contentInsetView.roundCorners(corners: [.layerMaxXMinYCorner, .layerMinXMinYCorner], radius: 10)
        } else if isLast {
            contentInsetView.roundCorners(corners: [.layerMaxXMaxYCorner, .layerMinXMaxYCorner], radius: 10)
        } else {
            contentInsetView.roundCorners(corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner], radius: 0)
        }
        contentInsetView.clipsToBounds = true
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            disabledView.isHidden = true
            disabledView.superview?.sendSubviewToBack(disabledView)
            isUserInteractionEnabled = true
        } else {
            disabledView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
            disabledView.isHidden = false
            disabledView.superview?.bringSubviewToFront(disabledView)
            isUserInteractionEnabled = false
        }
    }

    func setHighlighting() {
        highlightedView?.isHidden = !isHighlighted
    }

    func setThumbnailFor(file: File) {
        let fileId = file.id
        if (file.convertedType == .image || file.convertedType == .video) && file.hasThumbnail {
            logoImage.image = nil
            logoImage.contentMode = .scaleAspectFill
            logoImage.layer.cornerRadius = UIConstants.imageCornerRadius
            logoImage.layer.masksToBounds = true
            logoImage.backgroundColor = KDriveAsset.loaderDefaultColor.color
            file.getThumbnail { image, _ in
                if fileId == self.file.id {
                    self.logoImage.image = image
                    self.logoImage.backgroundColor = nil
                }
            }
        }
    }

    func configureWith(file: File, selectionMode: Bool = false) {
        self.file = file
        self.selectionMode = selectionMode

        titleLabel.text = file.name
        favoriteImageView.isHidden = !file.isFavorite
        favoriteImageView.accessibilityLabel = KDriveStrings.Localizable.favoritesTitle
        logoImage.image = file.icon
        moreButton.isHidden = selectionMode
        if !selectionMode || checkmarkImage != logoImage {
            // We don't fetch the thumbnail if we are in selection mode. In list mode we fetch thumbnail for images only
            setThumbnailFor(file: file)
        }

        availableOfflineImageView?.isHidden = !file.isAvailableOffline || !FileManager.default.fileExists(atPath: file.localUrl.path)
        availableOfflineImageView?.accessibilityLabel = KDriveStrings.Localizable.offlineFileTitle
        downloadObservationToken = DownloadQueue.instance.observeFileDownloadProgress(self, fileId: file.id) { fileId, progress in
            if fileId == file.id {
                DispatchQueue.main.async { [weak self] in
                    self?.downloadProgressView?.isHidden = progress >= 1 || progress == 0
                    self?.downloadProgressView?.updateProgress(CGFloat(progress))
                    self?.availableOfflineImageView?.isHidden = !file.isAvailableOffline || progress < 1
                }
            }
        }

        let formattedDate: String
        if let deletedAtDate = file.deletedAtDate {
            formattedDate = Constants.formatFileDeletionRelativeDate(deletedAtDate)
        } else {
            formattedDate = Constants.formatFileLastModifiedRelativeDate(file.lastModifiedDate)
        }

        if file.type == "file" {
            stackViewTrailingConstraint?.constant = -12
            detailLabel?.text = file.getFileSize() + " • " + formattedDate
        } else {
            stackViewTrailingConstraint?.constant = 16
            detailLabel?.text = formattedDate
        }

        configureForSelection()
    }

    func configureWith(trashedFile: File) {
        self.file = trashedFile
        titleLabel.text = trashedFile.name
        favoriteImageView.isHidden = true
        logoImage.image = trashedFile.icon

        let formattedDate = Constants.formatFileLastModifiedDate(trashedFile.lastModifiedDate)

        if trashedFile.type == "file" {
            accessoryImage?.isHidden = true
            detailLabel?.text = trashedFile.getFileSize() + " • " + formattedDate

        } else {
            accessoryImage?.isHidden = false
            detailLabel?.text = formattedDate
        }

        configureForSelection()
    }

    private func configureForSelection() {
        guard selectionMode else { return }
        accessoryImage?.isHidden = true
        checkmarkImage.image = isSelected ? KDriveAsset.select.image : FileCollectionViewCell.emptyCheckmarkImage
    }

    func configureWith(fileType: FileTypeRow) {
        centerTitleConstraint.isActive = true
        detailsStackView?.isHidden = true
        favoriteImageView.isHidden = true
        accessoryImage?.isHidden = true
        logoImage.image = fileType.icon
        titleLabel.text = fileType.name
    }

    func configureWith(recentSearch: String) {
        centerTitleConstraint.isActive = true
        detailsStackView?.isHidden = true
        favoriteImageView.isHidden = true
        accessoryImage?.isHidden = true
        logoImage.image = KDriveCoreAsset.clock.image
        logoImage.tintColor = KDriveCoreAsset.secondaryTextColor.color
        titleLabel.text = recentSearch
    }

    @IBAction func moreButtonTap(_ sender: Any) {
        delegate?.didTapMoreButton(self)
    }
}
