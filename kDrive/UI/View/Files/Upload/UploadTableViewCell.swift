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
import InfomaniakCoreDB
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

final class UploadTableViewCell: InsetTableViewCell {
    // This view is reused if FileListCollectionView header
    @IBOutlet var cardContentView: UploadCardView!
    private var currentFileId: String?
    private var thumbnailRequest: UploadFile.ThumbnailRequest?
    private var progressObservation: NotificationToken?
    @LazyInjectService(customTypeIdentifier: kDriveDBID.uploads) private var uploadsDatabase: Transactionable
    @LazyInjectService var uploadService: UploadServiceable

    override func awakeFromNib() {
        super.awakeFromNib()
        cardContentView.retryButton?.isHidden = true
        cardContentView.iconView.isHidden = true
        cardContentView.progressView.isHidden = true
        cardContentView.iconView.isHidden = false
        cardContentView.editImage?.isHidden = true
        cardContentView.progressView.setInfomaniakStyle()
        cardContentView.iconViewHeightConstraint.constant = 24
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailRequest?.cancel()
        thumbnailRequest = nil
        cardContentView.editImage?.isHidden = true
        cardContentView.retryButton?.isHidden = true
        cardContentView.progressView.isHidden = true
        cardContentView.detailsLabel.isHidden = false
        cardContentView.iconView.image = nil
        cardContentView.iconView.contentMode = .scaleAspectFit
        cardContentView.iconView.layer.cornerRadius = 0
        cardContentView.iconView.layer.masksToBounds = false
        cardContentView.iconView.isHidden = false
        cardContentView.progressView.updateProgress(0, animated: false)
        cardContentView.iconViewHeightConstraint.constant = 24
        progressObservation?.invalidate()
    }

    deinit {
        thumbnailRequest?.cancel()
    }

    private func setStatusFor(uploadFile: UploadFile) {
        guard !uploadFile.isInvalidated else {
            return
        }

        if let error = uploadFile.error, error != .taskRescheduled {
            cardContentView.retryButton?.isHidden = false
            if error.localizedDescription == KDriveResourcesStrings.Localizable.uploadOverDataRestrictedError {
                cardContentView.detailsLabel.text = error.localizedDescription
            } else {
                cardContentView.detailsLabel.text = KDriveResourcesStrings.Localizable
                    .errorUpload + " (\(error.localizedDescription))"
            }

        } else {
            cardContentView.retryButton?
                .isHidden = (uploadFile.maxRetryCount > 0) // Display retry for uploads that reached automatic retry limit

            var status = KDriveResourcesStrings.Localizable.uploadInProgressPending
            if ReachabilityListener.instance.currentStatus == .offline {
                status = KDriveResourcesStrings.Localizable.uploadNetworkErrorDescription
            } else if UserDefaults.shared.isWifiOnly,
                      ReachabilityListener.instance.currentStatus != .wifi,
                      uploadFile.isPhotoSyncUpload {
                status = KDriveResourcesStrings.Localizable.uploadNetworkErrorWifiRequired
            }

            if uploadFile.size > 0 {
                cardContentView.detailsLabel.text = uploadFile.formattedSize + " • " + status
            } else {
                cardContentView.detailsLabel.text = status
            }
        }
    }

    private func addThumbnail(image: UIImage) {
        Task { @MainActor in
            self.cardContentView.iconView.layer.cornerRadius = UIConstants.Image.cornerRadius
            self.cardContentView.iconView.contentMode = .scaleAspectFill
            self.cardContentView.iconView.layer.masksToBounds = true
            self.cardContentView.iconViewHeightConstraint.constant = 38
            self.cardContentView.iconView.image = image
        }
    }

    func configureWith(frozenUploadFile: UploadFile, progress: CGFloat?) {
        assert(frozenUploadFile.isFrozen, "Expected a frozen upload file")
        guard let uploadFile = frozenUploadFile.thaw() else {
            return
        }

        // set `uploadFileId` asap so the configuration is applied correctly
        let uploadFileId = uploadFile.id
        currentFileId = uploadFileId

        // Set initial text
        cardContentView.titleLabel.text = uploadFile.name
        setStatusFor(uploadFile: uploadFile)

        // Set initial progress value if any
        if let progress {
            updateProgress(frozenUploadFile: frozenUploadFile, progress: progress, animated: true)
        }

        // observe the progres
        let observationClosure: (ObjectChange<UploadFile>) -> Void = { [weak self] change in
            guard let self else {
                return
            }

            switch change {
            case .change(let newLiveFile, _):
                guard let progress = newLiveFile.progress,
                      newLiveFile.error == nil || newLiveFile.error == DriveError.taskRescheduled else {
                    return
                }

                updateProgress(frozenUploadFile: newLiveFile.freeze(), progress: progress, animated: false)
            case .error, .deleted:
                break
            }
        }
        progressObservation = uploadFile.observe(keyPaths: ["progress"], observationClosure)

        cardContentView.iconView.image = uploadFile.convertedType.icon
        thumbnailRequest = uploadFile.getThumbnail { [weak self] image in
            self?.addThumbnail(image: image)
        }

        cardContentView.cancelButtonPressedHandler = {
            guard !uploadFile.isInvalidated else {
                return
            }

            guard let file = self.uploadsDatabase.fetchObject(ofType: UploadFile.self, forPrimaryKey: uploadFileId) else {
                return
            }

            self.uploadService.cancel(uploadFileId: file.id)
        }
        cardContentView.retryButtonPressedHandler = { [weak self] in
            guard let self, !uploadFile.isInvalidated else {
                return
            }

            cardContentView.retryButton?.isHidden = true
            uploadService.retry(uploadFileId)
        }
    }

    func configureWith(importedFile: ImportedFile) {
        cardContentView.cancelButton?.isHidden = true
        cardContentView.retryButton?.isHidden = true
        cardContentView.editImage?.isHidden = false

        cardContentView.editImage?.image = KDriveResourcesAsset.edit.image
        cardContentView.iconView.image = ConvertedType.fromUTI(importedFile.uti).icon
        cardContentView.titleLabel.text = importedFile.name
        cardContentView.detailsLabel.isHidden = true
        let request = importedFile.getThumbnail { [weak self] image in
            self?.addThumbnail(image: image)
        }
        thumbnailRequest = .qlThumbnailRequest(request)
    }

    func updateProgress(frozenUploadFile: UploadFile, progress: CGFloat, animated: Bool = true) {
        assert(frozenUploadFile.isFrozen, "Expecting a Frozen object")
        guard let currentFileId, frozenUploadFile.id == currentFileId else { return }

        cardContentView.iconView.isHidden = true
        cardContentView.progressView.isHidden = false
        cardContentView.progressView.updateProgress(progress, animated: animated)

        var status = KDriveResourcesStrings.Localizable.uploadInProgressTitle
        if ReachabilityListener.instance.currentStatus == .offline {
            status += " • " + KDriveResourcesStrings.Localizable.uploadNetworkErrorDescription
        } else if UserDefaults.shared.isWifiOnly,
                  ReachabilityListener.instance.currentStatus != .wifi,
                  frozenUploadFile.isPhotoSyncUpload {
            status += " • " + KDriveResourcesStrings.Localizable.uploadNetworkErrorWifiRequired
        }
        cardContentView.detailsLabel.text = status
    }
}
