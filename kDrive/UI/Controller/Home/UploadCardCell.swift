/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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

class UploadCardCell: UICollectionViewCell {
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploadable

    static let identifier = String(describing: UploadCardCell.self)

    @IBOutlet var uploadCardView: UploadCardView!

    private var uploadCountManager: UploadCountManager?
    private var networkObserver: ObservationToken?

    var onUploadCardViewTapped: (() -> Void)?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        uploadCardView.iconView.isHidden = true
        uploadCardView.progressView.setInfomaniakStyle()
        updateWifiView()

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOnUploadCardView))
        uploadCardView.addGestureRecognizer(tapGestureRecognizer)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadWifiView),
            name: .reloadWifiView,
            object: nil
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        uploadCountManager = nil
        networkObserver = nil
        onUploadCardViewTapped = nil
    }

    func configure(
        driveFileManager: DriveFileManager,
        presenter: UIViewController
    ) {
        observeNetworkChange()
        observeUploadCount(driveFileManager: driveFileManager)
        uploadCardView.setUploadCount(uploadCountManager?.uploadCount ?? 0)

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
        updateWifiView()
    }

    @objc private func reloadWifiView() {
        updateWifiView()
    }

    @objc private func didTapOnUploadCardView() {
        onUploadCardViewTapped?()
    }

    private func observeUploadCount(driveFileManager: DriveFileManager) {
        uploadCountManager = UploadCountManager(driveFileManager: driveFileManager) { [weak self] in
            guard let self, let uploadCountManager else { return }
            self.uploadCardView.setUploadCount(uploadCountManager.uploadCount)
        }
    }

    private func observeNetworkChange() {
        networkObserver = ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                self.updateWifiView()
            }
        }
    }

    private func updateWifiView() {
        if photoLibraryUploader.isWifiOnly && ReachabilityListener.instance.currentStatus == .cellular {
            uploadCardView.titleLabel.text = KDriveResourcesStrings.Localizable.uploadPausedTitle
            uploadCardView.progressView.isHidden = true
            uploadCardView.iconView.image = UIImage(systemName: "exclamationmark.arrow.triangle.2.circlepath")
            uploadCardView.iconView.isAccessibilityElement = false
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
    }
}
