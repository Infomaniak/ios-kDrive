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

class UploadTableViewCell: InsetTableViewCell {
    // This view is reused if FileListCollectionView header
    @IBOutlet weak var cardContentView: UploadCardView!
    private var currentFileId: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        cardContentView.retryButton?.isHidden = true
        cardContentView.iconView.isHidden = true
        cardContentView.progressView.isHidden = true
        cardContentView.iconView.isHidden = false
        cardContentView.progressView.setInfomaniakStyle()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardContentView.editImage?.isHidden = true
        cardContentView.retryButton?.isHidden = true
        cardContentView.progressView.isHidden = true
        cardContentView.detailsLabel.isHidden = false
        cardContentView.iconView.isHidden = false
        cardContentView.iconView.image = nil
        cardContentView.iconView.contentMode = .scaleAspectFit
        cardContentView.iconView.layer.cornerRadius = 0
        cardContentView.iconView.layer.masksToBounds = false
        cardContentView.progressView.updateProgress(0, animated: false)
    }

    private func setStatusFor(uploadFile: UploadFile) {
        if let error = uploadFile.error, error != .taskRescheduled {
            cardContentView.retryButton?.isHidden = false
            cardContentView.detailsLabel.text = KDriveResourcesStrings.Localizable.errorUpload + " (\(error.localizedDescription))"
        } else {
            cardContentView.retryButton?.isHidden = true
            var status = KDriveResourcesStrings.Localizable.uploadInProgressPending
            if ReachabilityListener.instance.currentStatus == .offline {
                status = KDriveResourcesStrings.Localizable.uploadNetworkErrorDescription
            } else if UserDefaults.shared.isWifiOnly && ReachabilityListener.instance.currentStatus != .wifi {
                status = KDriveResourcesStrings.Localizable.uploadNetworkErrorWifiRequired
            }
            if uploadFile.size > 0 {
                cardContentView.detailsLabel.text = uploadFile.formattedSize + " • " + status
            } else {
                cardContentView.detailsLabel.text = status
            }
        }
    }

    func configureWith(uploadFile: UploadFile, progress: CGFloat?) {
        currentFileId = uploadFile.id
        cardContentView.titleLabel.text = uploadFile.name
        setStatusFor(uploadFile: uploadFile)

        if let progress = progress, let currentFileId = currentFileId {
            updateProgress(fileId: currentFileId, progress: progress, animated: false)
        }

        cardContentView.iconView.image = uploadFile.convertedType.icon
        uploadFile.getThumbnail { [weak self, fileId = uploadFile.id] image in
            DispatchQueue.main.async {
                guard fileId == self?.currentFileId else { return }
                self?.cardContentView.iconView.layer.cornerRadius = UIConstants.imageCornerRadius
                self?.cardContentView.iconView.contentMode = .scaleAspectFill
                self?.cardContentView.iconView.layer.masksToBounds = true
                self?.cardContentView.iconView.image = image
            }
        }

        cardContentView.cancelButtonPressedHandler = {
            let realm = DriveFileManager.constants.uploadsRealm
            if let file = realm.object(ofType: UploadFile.self, forPrimaryKey: uploadFile.id) {
                UploadQueue.instance.cancel(file)
            }
        }
        cardContentView.retryButtonPressedHandler = { [weak self] in
            self?.cardContentView.retryButton?.isHidden = true
            let realm = DriveFileManager.constants.uploadsRealm
            if let file = realm.object(ofType: UploadFile.self, forPrimaryKey: uploadFile.id) {
                UploadQueue.instance.retry(file)
            }
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
        importedFile.getThumbnail { image in
            DispatchQueue.main.async {
                self.cardContentView.iconView.layer.cornerRadius = UIConstants.imageCornerRadius
                self.cardContentView.iconView.contentMode = .scaleAspectFill
                self.cardContentView.iconView.layer.masksToBounds = true
                self.cardContentView.iconView.image = image
            }
        }
    }

    func updateProgress(fileId: String, progress: CGFloat, animated: Bool = true) {
        if let currentFileId = currentFileId, fileId == currentFileId {
            cardContentView.iconView.isHidden = true
            cardContentView.progressView.isHidden = false
            cardContentView.progressView.updateProgress(progress, animated: animated)

            var status = KDriveResourcesStrings.Localizable.uploadInProgressTitle
            if ReachabilityListener.instance.currentStatus == .offline {
                status += " • " + KDriveResourcesStrings.Localizable.uploadNetworkErrorDescription
            } else if UserDefaults.shared.isWifiOnly && ReachabilityListener.instance.currentStatus != .wifi {
                status += " • " + KDriveResourcesStrings.Localizable.uploadNetworkErrorWifiRequired
            }
            cardContentView.detailsLabel.text = status
        }
    }
}
