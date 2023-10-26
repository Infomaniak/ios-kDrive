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
import Photos
import RealmSwift
import UIKit

final class PhotoSyncSettingsViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploader

    enum PhotoSyncSection {
        case syncSwitch
        case syncLocation
        case syncSettings
        case syncDenied
    }

    enum PhotoSyncSwitchRows: CaseIterable {
        case syncSwitch
    }

    enum PhotoSyncLocationRows: CaseIterable {
        case driveSelection
        case folderSelection
    }

    enum PhotoSyncSettingsRows: CaseIterable {
        case syncMode
        case importPicturesSwitch
        case importVideosSwitch
        case importScreenshotsSwitch
        case createDatedSubFolders
        case deleteAssetsAfterImport
        case photoFormat
    }

    enum PhotoSyncDeniedRows: CaseIterable {
        case deniedExplanation
    }

    var sections: [PhotoSyncSection] = [.syncSwitch]
    let switchSyncRows: [PhotoSyncSwitchRows] = PhotoSyncSwitchRows.allCases
    let locationRows: [PhotoSyncLocationRows] = PhotoSyncLocationRows.allCases
    let settingsRows: [PhotoSyncSettingsRows] = PhotoSyncSettingsRows.allCases
    let deniedRows: [PhotoSyncDeniedRows] = PhotoSyncDeniedRows.allCases

    var newSyncSettings: PhotoSyncSettings = {
        @InjectService var photoUploader: PhotoLibraryUploader
        if photoUploader.settings != nil {
            return PhotoSyncSettings(value: photoUploader.settings as Any)
        } else {
            return PhotoSyncSettings()
        }
    }()

    var photoSyncEnabled: Bool = InjectService<PhotoLibraryUploader>().wrappedValue.isSyncEnabled
    var selectedDirectory: File? {
        didSet {
            newSyncSettings.parentDirectoryId = selectedDirectory?.id ?? -1
            if oldValue == nil || selectedDirectory == nil {
                Task { @MainActor in
                    self.updateSections()
                }
            }
        }
    }

    var driveFileManager: DriveFileManager? {
        didSet {
            newSyncSettings.userId = driveFileManager?.drive.userId ?? -1
            newSyncSettings.driveId = driveFileManager?.drive.id ?? -1
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hideBackButtonText()

        tableView.register(cellView: ParameterTableViewCell.self)
        tableView.register(cellView: ParameterSwitchTableViewCell.self)
        tableView.register(cellView: ParameterWifiTableViewCell.self)
        tableView.register(cellView: LocationTableViewCell.self)
        tableView.register(cellView: MenuTableViewCell.self)
        tableView.register(cellView: PhotoAccessDeniedTableViewCell.self)
        tableView.register(cellView: PhotoSyncSettingsTableViewCell.self)
        tableView.register(cellView: PhotoFormatTableViewCell.self)

        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 50

        let view = FooterButtonView.instantiate(title: KDriveResourcesStrings.Localizable.buttonSave)
        view.delegate = self
        tableView.tableFooterView = view

        let savedCurrentUserId = newSyncSettings.userId
        let savedCurrentDriveId = newSyncSettings.driveId
        if savedCurrentUserId != -1 && savedCurrentDriveId != -1 {
            driveFileManager = accountManager.getDriveFileManager(for: savedCurrentDriveId, userId: savedCurrentUserId)
        }
        updateSaveButtonState()
        updateSectionList()
        if newSyncSettings.parentDirectoryId != -1 {
            // We should always have the folder in cache but just in case we don't...
            if let photoSyncDirectory = driveFileManager?.getCachedFile(id: newSyncSettings.parentDirectoryId) {
                selectedDirectory = photoSyncDirectory
                updateSaveButtonState()
            } else {
                Task {
                    let file = try await driveFileManager?.file(id: newSyncSettings.parentDirectoryId)
                    self.selectedDirectory = file?.freeze()
                    self.tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .none)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationController?.navigationBar.isTranslucent = false

        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName, "PhotoSync"])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        navigationController?.navigationBar.isTranslucent = true
    }

    // Hack to have auto layout working in table view footer
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let footerView = tableView.tableFooterView else {
            return
        }

        let width = tableView.bounds.size.width
        let size = footerView.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height))

        if footerView.frame.size.height != size.height {
            footerView.frame.size.height = size.height
            tableView.tableFooterView = footerView
        }
    }

    func updateSectionList() {
        sections = [.syncSwitch]
        if photoSyncEnabled {
            sections.append(.syncLocation)
            if driveFileManager != nil && selectedDirectory != nil {
                sections.append(.syncSettings)
            }
        } else {
            var limited = false
            if #available(iOS 14, *) {
                limited = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
            }
            if limited || PHPhotoLibrary.authorizationStatus() == .denied {
                sections.append(.syncDenied)
            }
        }
    }

    func updateSections() {
        let previousSections = sections
        updateSectionList()
        let commonSections = Set(previousSections).intersection(sections)
        tableView.performBatchUpdates {
            tableView.deleteSections(IndexSet(commonSections.count ..< previousSections.count), with: .fade)
            tableView.insertSections(IndexSet(commonSections.count ..< sections.count), with: .fade)
        }
        // Scroll to bottom
        let lastSection = sections.count - 1
        tableView.scrollToRow(
            at: IndexPath(row: tableView(tableView, numberOfRowsInSection: lastSection) - 1, section: lastSection),
            at: .middle,
            animated: true
        )
    }

    func updateSaveButtonState() {
        let isEdited = photoLibraryUploader.isSyncEnabled != photoSyncEnabled || photoLibraryUploader.settings?
            .isContentEqual(to: newSyncSettings) == false

        let footer = tableView.tableFooterView as? FooterButtonView
        if (driveFileManager == nil || selectedDirectory == nil) && photoSyncEnabled {
            footer?.footerButton.isEnabled = false
        } else {
            footer?.footerButton.isEnabled = isEdited
        }
    }

    func saveSettings() {
        BackgroundRealm.uploads.execute { _ in
            if photoSyncEnabled {
                guard newSyncSettings.userId != -1 && newSyncSettings.driveId != -1 && newSyncSettings.parentDirectoryId != -1
                else { return }
                switch newSyncSettings.syncMode {
                case .new:
                    newSyncSettings.lastSync = Date()
                case .all:
                    if let currentSyncSettings = photoLibraryUploader.settings, currentSyncSettings.syncMode == .all {
                        newSyncSettings.lastSync = currentSyncSettings.lastSync
                    } else {
                        newSyncSettings.lastSync = Date(timeIntervalSince1970: 0)
                    }
                case .fromDate:
                    if let currentSyncSettings = photoLibraryUploader.settings,
                       currentSyncSettings
                       .syncMode == .all ||
                       (currentSyncSettings.syncMode == .fromDate && currentSyncSettings.fromDate
                           .compare(newSyncSettings.fromDate) == .orderedAscending) {
                        newSyncSettings.lastSync = currentSyncSettings.lastSync
                    } else {
                        newSyncSettings.lastSync = newSyncSettings.fromDate
                    }
                }
                photoLibraryUploader.enableSync(with: newSyncSettings)
            } else {
                photoLibraryUploader.disableSync()
            }
        }
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        if #available(iOS 14, *) {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
    }

    class func instantiate() -> PhotoSyncSettingsViewController {
        return Storyboard.menu
            .instantiateViewController(withIdentifier: "PhotoSyncSettingsViewController") as! PhotoSyncSettingsViewController
    }
}

// MARK: - Table view delegate

extension PhotoSyncSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let section = sections[indexPath.section]
        if section == .syncLocation {
            let row = locationRows[indexPath.row]
            if row == .driveSelection {
                let selectDriveViewController = SelectDriveViewController.instantiate()
                selectDriveViewController.selectedDrive = driveFileManager?.drive
                selectDriveViewController.delegate = self
                navigationController?.pushViewController(selectDriveViewController, animated: true)
            } else if row == .folderSelection {
                if let driveFileManager {
                    let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(
                        driveFileManager: driveFileManager,
                        startDirectory: selectedDirectory,
                        disabledDirectoriesSelection: [driveFileManager.getCachedRootFile()],
                        delegate: self
                    )
                    navigationController?.present(selectFolderNavigationController, animated: true)
                }
            }

        } else if section == .syncSettings {
            let row = settingsRows[indexPath.row]
            switch row {
            case .syncMode:
                let alert = AlertChoiceViewController(
                    title: KDriveResourcesStrings.Localizable.syncSettingsButtonSaveDate,
                    choices: [KDriveResourcesStrings.Localizable.syncSettingsSaveDateNowValue2,
                              KDriveResourcesStrings.Localizable.syncSettingsSaveDateAllPictureValue,
                              KDriveResourcesStrings.Localizable.syncSettingsSaveDateFromDateValue2],
                    selected: newSyncSettings.syncMode.rawValue,
                    action: KDriveResourcesStrings.Localizable.buttonValid
                ) { selectedIndex in
                    self.newSyncSettings.syncMode = PhotoSyncMode(rawValue: selectedIndex) ?? .new
                    self.updateSaveButtonState()
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                }
                present(alert, animated: true)
            case .photoFormat:
                let selectPhotoFormatViewController = SelectPhotoFormatViewController
                    .instantiate(selectedFormat: newSyncSettings.photoFormat)
                selectPhotoFormatViewController.delegate = self
                navigationController?.pushViewController(selectPhotoFormatViewController, animated: true)
            default:
                break
            }
        }
    }
}

// MARK: - Select drive delegate

extension PhotoSyncSettingsViewController: SelectDriveDelegate {
    func didSelectDrive(_ drive: Drive) {
        driveFileManager = accountManager.getDriveFileManager(for: drive)
        selectedDirectory = nil
        updateSaveButtonState()
        tableView.reloadRows(at: [IndexPath(row: 0, section: 1), IndexPath(row: 1, section: 1)], with: .fade)
    }
}

// MARK: - Select folder delegate

extension PhotoSyncSettingsViewController: SelectFolderDelegate {
    func didSelectFolder(_ folder: File) {
        selectedDirectory = folder
        updateSaveButtonState()
        tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .fade)
    }
}

// MARK: - Select photo format delegate

extension PhotoSyncSettingsViewController: SelectPhotoFormatDelegate {
    func didSelectPhotoFormat(_ format: PhotoFileFormat) {
        newSyncSettings.photoFormat = format
        updateSaveButtonState()
        tableView.reloadData()
    }
}

// MARK: - Footer button delegate

extension PhotoSyncSettingsViewController: FooterButtonDelegate {
    func didClickOnButton(_ sender: AnyObject) {
        MatomoUtils.trackPhotoSync(isEnabled: photoSyncEnabled, with: newSyncSettings)

        DispatchQueue.global(qos: .userInitiated).async {
            self.saveSettings()
            Task { @MainActor in
                self.navigationController?.popViewController(animated: true)
            }

            // Add new pictures to be uploaded and reload upload queue
            self.photoLibraryUploader.scheduleNewPicturesForUpload()
            @InjectService var uploadQueue: UploadQueue
            uploadQueue.rebuildUploadQueueFromObjectsInRealm()
        }
    }
}

// MARK: - Photo Sync Settings Cell Delegate

extension PhotoSyncSettingsViewController: PhotoSyncSettingsTableViewCellDelegate {
    func didSelectDate(date: Date) {
        newSyncSettings.fromDate = date
        updateSaveButtonState()
    }
}
