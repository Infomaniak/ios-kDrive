/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import UIKit

class RootMenuHeaderView: UICollectionReusableView {
    static let kind: UICollectionView.UICollectionViewSupplementaryViewKind = .custom("menuHeader")

    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploadable

    @IBOutlet var topConstraint: NSLayoutConstraint!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!

    @IBOutlet var offlineView: UIView!
    @IBOutlet var uploadCardView: UploadCardView!

    private var uploadCountManager: UploadCountManager?
    private weak var collectionView: UICollectionView?

    var onUploadCardViewTapped: (() -> Void)?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        uploadCardView.iconView.isHidden = true
        uploadCardView.progressView.setInfomaniakStyle()
        uploadCardView.roundCorners(
            corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner],
            radius: 10
        )

        updateWifiView()

        uploadCardView.isHidden = true
        offlineView.isHidden = true
        hideIfNeeded()

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOnUploadCardView))
        uploadCardView.addGestureRecognizer(tapGestureRecognizer)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadWifiView),
            name: .reloadWifiView,
            object: nil
        )
    }

    func configureInCollectionView(
        _ collectionView: UICollectionView,
        driveFileManager: DriveFileManager,
        presenter: UIViewController
    ) {
        self.collectionView = collectionView
        observeNetworkChange()
        observeUploadCount(driveFileManager: driveFileManager)

        onUploadCardViewTapped = {
            @InjectService var router: AppNavigable
            if let navigationController = presenter.navigationController {
                router.presentUploadViewController(
                    driveFileManager: driveFileManager,
                    navigationController: navigationController,
                    animated: true
                )
            }
        }
    }

    private func hideIfNeeded() {
        if uploadCardView.isHidden && offlineView.isHidden {
            topConstraint.constant = 0
            bottomConstraint.constant = 0
        } else {
            topConstraint.constant = 16
            bottomConstraint.constant = 16
        }
    }

    @objc func reloadWifiView(_ notification: Notification) {
        updateWifiView()
    }

    @objc func didTapOnUploadCardView() {
        onUploadCardViewTapped?()
    }

    private func observeUploadCount(driveFileManager: DriveFileManager) {
        uploadCountManager = UploadCountManager(driveFileManager: driveFileManager) { [weak self] in
            guard let self else { return }

            guard let uploadCountManager else {
                return
            }

            let uploadCount = uploadCountManager.uploadCount
            let countIsEmpty = uploadCount == 0
            let shouldHideUploadCardView = countIsEmpty

            if uploadCardView.isHidden != shouldHideUploadCardView {
                uploadCardView.isHidden = shouldHideUploadCardView
                reloadHeader()
            }

            uploadCardView.setUploadCount(uploadCount)
        }
    }

    private func observeNetworkChange() {
        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] status in
            Task { [weak self] in
                guard let self else { return }

                offlineView.isHidden = status != .offline

                updateWifiView()
            }
        }
    }

    private func updateWifiView() {
        if photoLibraryUploader.isWifiOnly && ReachabilityListener.instance.currentStatus == .cellular {
            uploadCardView.titleLabel.text = KDriveResourcesStrings.Localizable.uploadPausedTitle
            uploadCardView.progressView.isHidden = true
            uploadCardView.iconView.image = UIImage(systemName: "exclamationmark.arrow.triangle.2.circlepath")
            uploadCardView.iconView.isHidden = false
            uploadCardView.iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                uploadCardView.iconView.widthAnchor.constraint(equalToConstant: 24),
                uploadCardView.iconView.heightAnchor.constraint(equalToConstant: 24)
            ])
            uploadCardView.iconView.tintColor = .gray
        } else {
            uploadCardView.titleLabel.text = KDriveResourcesStrings.Localizable.uploadInProgressTitle
            uploadCardView.progressView.isHidden = false
            uploadCardView.iconView.isHidden = true
            uploadCardView.progressView.setInfomaniakStyle()
            uploadCardView.progressView.enableIndeterminate()
        }
        reloadHeader()
    }

    private func reloadHeader() {
        hideIfNeeded()

        guard let collectionView else { return }
        UIView.transition(with: collectionView, duration: 0.25, options: .transitionCrossDissolve) {
            let sectionHeaderContext = UICollectionViewLayoutInvalidationContext()
            sectionHeaderContext.invalidateSupplementaryElements(
                ofKind: RootMenuHeaderView.kind.rawValue,
                at: [IndexPath(item: 0, section: 0)]
            )
            collectionView.collectionViewLayout.invalidateLayout(with: sectionHeaderContext)
        }
    }
}
