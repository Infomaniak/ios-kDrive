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
import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import UIKit

class FloatingPanelActionCollectionViewCell: UICollectionViewCell {
    @IBOutlet var disabledView: UIView!
    @IBOutlet var highlightedView: UIView!
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var progressView: RPCircularProgress!
    @IBOutlet var titleLabel: IKLabel!
    @IBOutlet var switchView: UISwitch!
    @IBOutlet var chipContainerView: UIView!

    private var observationToken: ObservationToken?

    override var isHighlighted: Bool {
        didSet {
            setHighlighting()
        }
    }

    private func setHighlighting() {
        highlightedView.isHidden = !isHighlighted
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        switchView.isHidden = true
        progressView.setInfomaniakStyle()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        switchView.isHidden = true
        chipContainerView.subviews.forEach { $0.removeFromSuperview() }
        observationToken?.cancel()
    }

    func configure(with action: FloatingPanelAction,
                   file: File?, showProgress: Bool,
                   driveFileManager: DriveFileManager,
                   currentPackId: DrivePackId? = nil) {
        titleLabel.text = action.name
        iconImageView.image = action.image
        iconImageView.tintColor = action.tintColor

        if let file {
            if action == .favorite && file.isFavorite {
                titleLabel.text = action.reverseName
                iconImageView.tintColor = KDriveResourcesAsset.favoriteColor.color
            }
            if action == .offline {
                configureAvailableOffline(with: file)
            } else {
                observeProgress(showProgress, file: file)
            }
        }

        switch action {
        case .upsaleColor:
            guard currentPackId == .myKSuite else { return }
            configureChip()
        case .convertToDropbox:
            guard currentPackId == .myKSuite, driveFileManager.drive.dropboxQuotaExceeded else { return }
            configureChip()
        default:
            break
        }
    }

    func configure(with action: FloatingPanelAction,
                   files: [File],
                   driveFileManager: DriveFileManager,
                   showProgress: Bool,
                   archiveId: String?) {
        configure(with: action, file: nil, showProgress: false, driveFileManager: driveFileManager)

        switch action {
        case .favorite:
            if files.allSatisfy(\.isFavorite) {
                titleLabel.text = action.reverseName
                iconImageView.tintColor = KDriveResourcesAsset.favoriteColor.color
            }
        case .offline:
            let onlyFiles = files.filter { !$0.isDirectory }
            let filesAvailableOffline = onlyFiles.allSatisfy(\.isAvailableOffline)
            switchView.isHidden = false
            iconImageView.image = filesAvailableOffline ? KDriveResourcesAsset.check.image : action.image
            iconImageView.tintColor = filesAvailableOffline ? KDriveResourcesAsset.greenColor.color : action.tintColor
            switchView.isOn = filesAvailableOffline
            setProgress(showProgress ? -1 : nil)
        case .download:
            if let archiveId {
                observeProgress(showProgress, archiveId: archiveId)
            } else {
                setProgress(showProgress ? -1 : nil)
            }
        case .folderColor:
            let containsColorableFiles = files.contains(where: \.canBeColored)
            setEnabled(containsColorableFiles)
        case .manageCategories:
            let filesAreDisabled = files.allSatisfy(\.isDisabled)
            setEnabled(!filesAreDisabled)
        default:
            break
        }
    }

    func configureChip() {
        let chipView = MyKSuiteChip.instantiateGrayChip()

        chipView.translatesAutoresizingMaskIntoConstraints = false
        chipContainerView.addSubview(chipView)

        NSLayoutConstraint.activate([
            chipView.leadingAnchor.constraint(equalTo: chipContainerView.leadingAnchor),
            chipView.trailingAnchor.constraint(equalTo: chipContainerView.trailingAnchor),
            chipView.topAnchor.constraint(equalTo: chipContainerView.topAnchor),
            chipView.bottomAnchor.constraint(equalTo: chipContainerView.bottomAnchor)
        ])
    }

    func configureAvailableOffline(with file: File) {
        switchView.isHidden = false
        if switchView.isOn != file.isAvailableOffline {
            switchView.setOn(file.isAvailableOffline, animated: true)
        }

        let fileExists = FileManager.default.fileExists(atPath: file.localUrl.path)
        if file.isAvailableOffline && fileExists {
            iconImageView.image = KDriveResourcesAsset.check.image
            iconImageView.tintColor = KDriveResourcesAsset.greenColor.color
        } else {
            iconImageView.image = KDriveResourcesAsset.availableOffline.image
            iconImageView.tintColor = KDriveResourcesAsset.iconColor.color
        }

        observeProgress(file.isAvailableOffline && !fileExists, file: file)
    }

    func observeProgress(_ showProgress: Bool, file: File) {
        observationToken?.cancel()
        setProgress(showProgress ? -1 : nil)
        if showProgress {
            observationToken = DownloadQueue.instance.observeFileDownloadProgress(self, fileId: file.id) { _, progress in
                Task { @MainActor [weak self] in
                    self?.setProgress(progress)
                }
            }
        }
    }

    func observeProgress(_ showProgress: Bool, archiveId: String) {
        observationToken?.cancel()
        setProgress(showProgress ? -1 : nil)
        if showProgress {
            observationToken = DownloadQueue.instance.observeArchiveDownloadProgress(self, archiveId: archiveId) { _, progress in
                Task { @MainActor [weak self] in
                    self?.setProgress(progress)
                }
            }
        }
    }

    func setProgress(_ progress: CGFloat? = -1) {
        if let downloadProgress = progress, downloadProgress < 1 {
            iconImageView.isHidden = true
            progressView.isHidden = false
            if downloadProgress < 0 {
                progressView.enableIndeterminate()
            } else {
                progressView.enableIndeterminate(false)
                progressView.updateProgress(downloadProgress)
            }
        } else {
            iconImageView.isHidden = false
            progressView.isHidden = true
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
}
