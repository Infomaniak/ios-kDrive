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
import InfomaniakCore
import kDriveCore

class UploadTableViewCell: InsetTableViewCell {

    //This view is reused if FileListCollectionView header
    @IBOutlet weak var cardContentView: UploadCardView!
    private var currentFileId: String!

    override func awakeFromNib() {
        super.awakeFromNib()
        cardContentView.retryButton?.isHidden = true
        cardContentView.iconView.isHidden = true
        cardContentView.progressView.isHidden = true
        cardContentView.iconView.isHidden = false
        cardContentView.progressView.trackTintColor = KDriveAsset.secondaryTextColor.color.withAlphaComponent(0.2)
        cardContentView.progressView.progressTintColor = KDriveAsset.infomaniakColor.color
        cardContentView.progressView.thicknessRatio = 0.15
        cardContentView.progressView.indeterminateProgress = 0.75
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardContentView.retryButton?.isHidden = true
        cardContentView.progressView.isHidden = true
        cardContentView.iconView.isHidden = false
        cardContentView.progressView.updateProgress(0, animated: false)
    }

    private func setStatusFor(uploadFile: UploadFile) {
        cardContentView.retryButton?.isHidden = uploadFile.error == nil
        if let error = uploadFile.error {
            cardContentView.detailsLabel.text = KDriveStrings.Localizable.errorUpload + " (\(error.localizedDescription))"
        } else {
            var status = KDriveStrings.Localizable.uploadInProgressPending
            if ReachabilityListener.instance.currentStatus == .offline {
                status = KDriveStrings.Localizable.uploadNetworkErrorDescription
            } else if UserDefaults.isWifiOnlyMode() && ReachabilityListener.instance.currentStatus != .wifi {
                status = KDriveStrings.Localizable.uploadNetworkErrorWifiRequired
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

        if let progress = progress {
            updateProgress(fileId: currentFileId, progress: progress, animated: false)
        }

        uploadFile.getIconForUploadFile { (placeholder) in
            cardContentView.iconView.layer.cornerRadius = 0
            cardContentView.iconView.image = placeholder
        } completion: { (icon) in
            self.cardContentView.iconView.layer.cornerRadius = UIConstants.imageCornerRadius
            self.cardContentView.iconView.image = icon
        }

        cardContentView.cancelButtonPressedHandler = {
            let realm = DriveFileManager.constants.uploadsRealm
            if let file = realm.object(ofType: UploadFile.self, forPrimaryKey: uploadFile.id) {
                UploadQueue.instance.cancel(file, using: realm)
            }
        }
        cardContentView.retryButtonPressedHandler = {
            self.cardContentView.retryButton?.isHidden = true
            let realm = DriveFileManager.constants.uploadsRealm
            if let file = realm.object(ofType: UploadFile.self, forPrimaryKey: uploadFile.id) {
                UploadQueue.instance.retry(file, using: realm)
            }
        }
    }

    func updateProgress(fileId: String, progress: CGFloat, animated: Bool = true) {
        if fileId == currentFileId {
            cardContentView.iconView.isHidden = true
            cardContentView.progressView.isHidden = false
            cardContentView.progressView.updateProgress(progress, animated: animated)

            var status = KDriveStrings.Localizable.uploadInProgressTitle
            if ReachabilityListener.instance.currentStatus == .offline {
                status += " • " + KDriveStrings.Localizable.uploadNetworkErrorDescription
            } else if UserDefaults.isWifiOnlyMode() && ReachabilityListener.instance.currentStatus != .wifi {
                status += " • " + KDriveStrings.Localizable.uploadNetworkErrorWifiRequired
            }
            cardContentView.detailsLabel.text = status
        }
    }
}
