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
import InfomaniakDI
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
    @LazyInjectService private var downloadQueue: DownloadQueueable

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
        observationToken?.cancel()
        observationToken = nil
        switchView.setOn(false, animated: false)
        switchView.isHidden = true
        chipContainerView.subviews.forEach { $0.removeFromSuperview() }
    }

    func configure(with action: FloatingPanelAction,
                   file: File?,
                   showProgress: Bool,
                   driveFileManager: DriveFileManager,
                   currentPackId: DrivePackId? = nil) {
        titleLabel.text = action.name
        iconImageView.image = action.image
        iconImageView.tintColor = action.tintColor

        switch action {
        case .offline:
            guard let file else { return }
            configureAvailableOffline(with: file)
        case .favorite:
            guard let file, file.isFavorite else { return }
            titleLabel.text = action.reverseName
            iconImageView.tintColor = KDriveResourcesAsset.favoriteColor.color
        case .upsaleColor:
            guard currentPackId == .myKSuite else { return }
            configureChip()
        case .convertToDropbox:
            guard currentPackId == .myKSuite, driveFileManager.drive.dropboxQuotaExceeded else { return }
            configureChip()
        default:
            break
        }

        if let file {
            observeProgress(showProgress, file: file)
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
        let fileExists = FileManager.default.fileExists(atPath: file.localUrl.path)

        if let downloadOperation = downloadQueue.operation(for: file.id),
           !downloadOperation.isCancelled,
           !fileExists {
            switchView.setOn(true, animated: true)
        } else if file.isAvailableOffline, fileExists {
            switchView.setOn(true, animated: false)
        } else {
            switchView.setOn(false, animated: true)
        }

        if file.isAvailableOffline, fileExists {
            iconImageView.image = KDriveResourcesAsset.check.image
            iconImageView.tintColor = KDriveResourcesAsset.greenColor.color
        } else {
            iconImageView.image = KDriveResourcesAsset.availableOffline.image
            iconImageView.tintColor = KDriveResourcesAsset.iconColor.color
        }
    }

    func observeProgress(_ showProgress: Bool, file: File) {
        observationToken?.cancel()
        observationToken = nil
        setProgress(showProgress ? -1 : nil)
        if showProgress {
            observationToken = downloadQueue.observeFileDownloadProgress(self, fileId: file.id) { _, progress in
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
            observationToken = downloadQueue.observeArchiveDownloadProgress(self, archiveId: archiveId) { _, progress in
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
