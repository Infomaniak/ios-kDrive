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
import InfomaniakDI
import kDriveCore
import kDriveResources
import Kingfisher
import UIKit

protocol FileCellDelegate: AnyObject {
    func didTapMoreButton(_ cell: FileCollectionViewCell)
}

@MainActor class FileViewModel {
    static let observedProperties = [
        "name",
        "rawType",
        "rawStatus",
        "_capabilities",
        "dropbox",
        "rawVisibility",
        "extensionType",
        "isFavorite",
        "deletedAt",
        "lastModifiedAt",
        "isAvailableOffline",
        "categories",
        "size",
        "supportedBy",
        "color",
        "externalImport.status"
    ]
    var file: File
    var selectionMode: Bool
    var isSelected = false

    /// Public share data if file exists within a public share
    let publicShareProxy: PublicShareProxy?

    private var downloadProgressObserver: ObservationToken?
    private var downloadObserver: ObservationToken?
    var thumbnailDownloadTask: Kingfisher.DownloadTask?
    @LazyInjectService var downloadQueue: DownloadQueueable

    var title: String {
        guard !file.isInvalidated else { return "" }
        return file.formattedLocalizedName
    }

    var icon: UIImage {
        guard !file.isInvalidated else { return UIImage() }
        return file.icon
    }

    var iconTintColor: UIColor? {
        guard !file.isInvalidated else { return nil }
        return file.tintColor
    }

    var iconAccessibilityLabel: String {
        guard !file.isInvalidated else { return "" }
        return file.convertedType.title
    }

    var isFavorite: Bool {
        guard !file.isInvalidated else { return false }
        return file.isFavorite
    }

    var moreButtonHidden: Bool { selectionMode }

    var categories = [kDriveCore.Category]()

    private var formattedDate: String {
        guard !file.isInvalidated else { return "" }

        if let deletedAt = file.deletedAt {
            return Constants.formatFileDeletionRelativeDate(deletedAt)
        } else {
            return Constants.formatFileLastModifiedRelativeDate(file.lastModifiedAt)
        }
    }

    var subtitle: String {
        if isImporting {
            return KDriveResourcesStrings.Localizable.uploadInProgressTitle + "…"
        } else if !file.isInvalidated, let fileSize = file.getFileSize() {
            return fileSize + " • " + formattedDate
        } else {
            return formattedDate
        }
    }

    var isAvailableOffline: Bool {
        guard !file.isInvalidated else { return false }
        return file.isAvailableOffline && FileManager.default.fileExists(atPath: file.localUrl.path)
    }

    var isImporting: Bool {
        guard !file.isInvalidated else { return false }
        return file.isImporting
    }

    init(driveFileManager: DriveFileManager, file: File, selectionMode: Bool) {
        self.file = file
        self.selectionMode = selectionMode
        publicShareProxy = driveFileManager.publicShareProxy
        categories = driveFileManager.drive.categories(for: file)
    }

    func setUpDownloadObserver(_ handler: @escaping (Bool, Bool, Double) -> Void) {
        guard !file.isInvalidated else { return }

        downloadProgressObserver?.cancel()
        downloadProgressObserver = downloadQueue
            .observeFileDownloadProgress(self, fileId: file.id) { [weak self] _, progress in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard !file.isInvalidated else { return }
                    handler(!file.isAvailableOffline || progress < 1, progress >= 1 || progress == 0, progress)
                }
            }
        downloadObserver?.cancel()
        downloadObserver = downloadQueue.observeFileDownloaded(self, fileId: file.id) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                handler(!isAvailableOffline, true, 1)
            }
        }
    }

    func setThumbnail(on imageView: UIImageView) {
        // check if public share / use specific endpoint
        guard !file.isInvalidated,
              (file.convertedType == .image || file.convertedType == .video) && file.supportedBy.contains(.thumbnail) else {
            return
        }

        // Configure placeholder
        imageView.image = nil
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = UIConstants.Image.cornerRadius
        imageView.layer.masksToBounds = true
        imageView.backgroundColor = KDriveResourcesAsset.loaderDefaultColor.color

        if let publicShareProxy {
            // Fetch public share thumbnail
            thumbnailDownloadTask = file.getPublicShareThumbnail(publicShareId: publicShareProxy.shareLinkUid,
                                                                 publicDriveId: publicShareProxy.driveId,
                                                                 publicFileId: file.id) { [
                requestFileId = file.id,
                weak self
            ] image, _ in
                self?.setImage(image, on: imageView, requestFileId: requestFileId)
            }

        } else {
            // Fetch thumbnail
            thumbnailDownloadTask = file.getThumbnail { [requestFileId = file.id, weak self] image, _ in
                self?.setImage(image, on: imageView, requestFileId: requestFileId)
            }
        }
    }

    private func setImage(_ image: UIImage, on imageView: UIImageView, requestFileId: Int) {
        guard !file.isInvalidated,
              !isSelected else {
            return
        }

        if file.id == requestFileId {
            imageView.image = image
            imageView.backgroundColor = nil
        }
    }

    deinit {
        downloadProgressObserver?.cancel()
        downloadObserver?.cancel()
        thumbnailDownloadTask?.cancel()
    }
}

class FileCollectionViewCell: UICollectionViewCell {
    static let identifier = String(describing: FileCollectionViewCell.self)

    var swipeStartPoint: CGPoint = .zero
    var initialTrailingConstraintValue: CGFloat = 0

    @IBOutlet var disabledView: UIView!
    @IBOutlet var contentInsetView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var detailLabel: UILabel?
    @IBOutlet var logoImage: UIImageView!
    @IBOutlet var accessoryImage: UIImageView?
    @IBOutlet var moreButton: UIButton!
    @IBOutlet var favoriteImageView: UIImageView?
    @IBOutlet var collectionView: UICollectionView?
    @IBOutlet var availableOfflineImageView: UIImageView!
    @IBOutlet var centerTitleConstraint: NSLayoutConstraint!
    @IBOutlet var innerViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet var innerViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var swipeActionsView: UIStackView?
    @IBOutlet var stackViewTrailingConstraint: NSLayoutConstraint?
    @IBOutlet var detailsStackView: UIStackView?
    @IBOutlet var importProgressView: RPCircularProgress?
    @IBOutlet var downloadProgressView: RPCircularProgress?
    @IBOutlet var highlightedView: UIView!
    @IBOutlet var trailingConstraint: NSLayoutConstraint!
    @IBOutlet var leadingConstraint: NSLayoutConstraint!
    @IBOutlet var logoWidthConstraint: NSLayoutConstraint!
    @IBOutlet var logoHeightConstraint: NSLayoutConstraint!
    @IBOutlet var topConstraint: NSLayoutConstraint!
    @IBOutlet var logoLeadingConstraint: NSLayoutConstraint!

    var viewModel: FileViewModel?

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = KDriveResourcesAsset.separatorColor.color
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    weak var delegate: FileCellDelegate?

    override var isSelected: Bool {
        didSet {
            viewModel?.isSelected = isSelected
            configureForSelection()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            setHighlighting()
        }
    }

    var checkmarkImage: UIImageView? {
        return logoImage
    }

    static var emptyCheckmarkImage: UIImage = {
        let size = CGSize(width: 24, height: 24)
        let lineWidth = 1.0
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            ctx.cgContext.setFillColor(KDriveResourcesAsset.backgroundCardViewColor.color.cgColor)
            ctx.cgContext.setStrokeColor(KDriveResourcesAsset.borderColor.color.cgColor)
            ctx.cgContext.setLineWidth(lineWidth)

            let diameter = min(size.width, size.height) - lineWidth
            let rect = CGRect(x: (size.width - diameter) / 2, y: (size.height - diameter) / 2, width: diameter, height: diameter)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fillStroke)
        }
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        favoriteImageView?.isAccessibilityElement = true
        favoriteImageView?.accessibilityLabel = KDriveResourcesStrings.Localizable.favoritesTitle
        availableOfflineImageView?.isAccessibilityElement = true
        availableOfflineImageView?.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonAvailableOffline
        moreButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonMenu
        importProgressView?.setInfomaniakStyle()
        downloadProgressView?.setInfomaniakStyle()
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.register(cellView: CategoryBadgeCollectionViewCell.self)

        contentInsetView.addSubview(separatorView)
        NSLayoutConstraint.activate([
            separatorView.leadingAnchor.constraint(equalTo: contentInsetView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: contentInsetView.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentInsetView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1)
        ])
        separatorView.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        collectionView?.isHidden = true
        collectionView?.reloadData()
        centerTitleConstraint?.isActive = false
        detailLabel?.text = ""
        logoImage.image = nil
        logoImage.backgroundColor = nil
        logoImage.contentMode = .scaleAspectFit
        logoImage.layer.cornerRadius = 0
        logoImage.layer.masksToBounds = false
        detailsStackView?.isHidden = false
        availableOfflineImageView?.isHidden = true
        downloadProgressView?.isHidden = true
        downloadProgressView?.updateProgress(0, animated: false)
        viewModel?.thumbnailDownloadTask?.cancel()
        separatorView.isHidden = true
    }

    func initStyle(isFirst: Bool, isLast: Bool, inFolderSelectMode: Bool) {
        separatorView.isHidden = !inFolderSelectMode

        if isLast && isFirst {
            contentInsetView.roundCorners(
                corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner], radius: 10
            )
        } else if isFirst {
            contentInsetView.roundCorners(corners: [.layerMaxXMinYCorner, .layerMinXMinYCorner], radius: 10)
        } else if isLast {
            contentInsetView.roundCorners(corners: [.layerMaxXMaxYCorner, .layerMinXMaxYCorner], radius: 10)
        } else {
            contentInsetView.roundCorners(
                corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner],
                radius: 0
            )
        }
        addConstraint(isFirst: isFirst, isLast: isLast, inFolderSelectMode: inFolderSelectMode)
        contentInsetView.clipsToBounds = true
    }

    func addConstraint(isFirst: Bool, isLast: Bool, inFolderSelectMode: Bool) {
        guard inFolderSelectMode else { return }

        trailingConstraint.constant = UIConstants.Padding.mediumSmall
        leadingConstraint.constant = UIConstants.Padding.mediumSmall
        logoWidthConstraint.constant = 26
        logoHeightConstraint.constant = 26
        logoLeadingConstraint.constant = 16
        if isFirst {
            topConstraint.constant = 8
        }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            disabledView.isHidden = true
            disabledView.superview?.sendSubviewToBack(disabledView)
            isUserInteractionEnabled = true
        } else {
            disabledView.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
            disabledView.isHidden = false
            disabledView.superview?.bringSubviewToFront(disabledView)
            isUserInteractionEnabled = false
        }
    }

    func setHighlighting() {
        highlightedView?.isHidden = !isHighlighted
    }

    func configure(with viewModel: FileViewModel) {
        self.viewModel = viewModel
        configureLogoImage(viewModel: viewModel)
        titleLabel.text = viewModel.title
        detailLabel?.text = viewModel.subtitle
        favoriteImageView?.isHidden = !viewModel.isFavorite
        availableOfflineImageView.isHidden = !viewModel.isAvailableOffline
        moreButton.isHidden = viewModel.moreButtonHidden
        collectionView?.isHidden = viewModel.categories.isEmpty
        collectionView?.reloadData()

        viewModel.setUpDownloadObserver { [weak self] availableOfflineHidden, downloadProgressHidden, progress in
            self?.availableOfflineImageView?.isHidden = availableOfflineHidden
            self?.downloadProgressView?.isHidden = downloadProgressHidden
            self?.downloadProgressView?.updateProgress(progress)
        }

        configureForSelection()
    }

    func configureWith(driveFileManager: DriveFileManager, file: File, selectionMode: Bool = false) {
        let fileViewModel = FileViewModel(
            driveFileManager: driveFileManager,
            file: file,
            selectionMode: selectionMode
        )
        configure(with: fileViewModel)
    }

    /// Update the cell selection mode.
    /// - Parameter selectionMode: The new selection mode (enabled/disabled).
    func setSelectionMode(_ selectionMode: Bool) {
        guard let viewModel else { return }
        viewModel.selectionMode = selectionMode
        configure(with: viewModel)
    }

    func configureForSelection() {
        guard let viewModel,
              viewModel.selectionMode else {
            return
        }

        if isSelected {
            configureCheckmarkImage()
            configureImport(shouldDisplay: false)
        } else {
            configureLogoImage(viewModel: viewModel)
        }
    }

    private func configureLogoImage(viewModel: FileViewModel) {
        logoImage.isAccessibilityElement = true
        logoImage.accessibilityLabel = viewModel.iconAccessibilityLabel
        logoImage.image = viewModel.icon
        logoImage.tintColor = viewModel.iconTintColor
        configureImport(shouldDisplay: !isSelected)
        if !isSelected {
            viewModel.setThumbnail(on: logoImage)
        }
    }

    func configureCheckmarkImage() {
        checkmarkImage?.image = isSelected ? KDriveResourcesAsset.select.image : Self.emptyCheckmarkImage
        checkmarkImage?.isAccessibilityElement = true
        checkmarkImage?.accessibilityLabel = isSelected ? KDriveResourcesStrings.Localizable.contentDescriptionIsSelected : ""
        checkmarkImage?.backgroundColor = nil
        checkmarkImage?.contentMode = .scaleAspectFit
        checkmarkImage?.layer.cornerRadius = 0
        checkmarkImage?.layer.masksToBounds = false
    }

    func configureImport(shouldDisplay: Bool) {
        guard let viewModel else { return }

        if shouldDisplay && viewModel.isImporting {
            logoImage.isHidden = true
            importProgressView?.isHidden = false
            importProgressView?.enableIndeterminate()
        } else {
            logoImage.isHidden = false
            importProgressView?.isHidden = true
        }
    }

    func configureLoading() {
        titleLabel.text = " "
        let titleLayer = CALayer()
        titleLayer.anchorPoint = .zero
        titleLayer.bounds = CGRect(x: 0, y: 0, width: 100, height: 15)
        titleLayer.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color.cgColor
        titleLabel.layer.addSublayer(titleLayer)
        favoriteImageView?.isHidden = true
        logoImage.image = nil
        logoImage.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color
        moreButton.isHidden = true
        checkmarkImage?.isHidden = true
    }

    @IBAction func moreButtonTap(_ sender: Any) {
        delegate?.didTapMoreButton(self)
    }
}

extension FileCollectionViewCell: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(viewModel?.categories.count ?? 0, 3)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let viewModel else {
            return UICollectionViewCell()
        }
        let cell = collectionView.dequeueReusableCell(type: CategoryBadgeCollectionViewCell.self, for: indexPath)
        let category = viewModel.categories[indexPath.row]
        let more = indexPath.item == 2 && viewModel.categories.count > 3 ? viewModel.categories.count - 3 : nil
        cell.configure(with: category, more: more)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return CGSize(width: 16, height: 16)
    }

    func setIsLastCell(_ isLast: Bool) {
        separatorView.isHidden = isLast
    }
}
