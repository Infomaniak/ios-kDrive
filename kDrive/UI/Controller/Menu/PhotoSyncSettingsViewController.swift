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
import Photos
import RealmSwift
import UIKit

class PhotoSyncSettingsViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var saveButton: UIButton!

    private enum PhotoSyncSection {
        case syncSwitch
        case syncLocation
        case syncSettings
        case syncDenied
    }

    private enum PhotoSyncSwitchRows: CaseIterable {
        case syncSwitch
    }

    private enum PhotoSyncLocationRows: CaseIterable {
        case driveSelection
        case folderSelection
    }

    private enum PhotoSyncSettingsRows: CaseIterable {
        case syncMode
        case importPicturesSwitch
        case importVideosSwitch
        case importScreenshotsSwitch
        case createDatedSubFolders
        case deleteAssetsAfterImport
    }

    private enum PhotoSyncDeniedRows: CaseIterable {
        case deniedExplanation
    }

    private var sections: [PhotoSyncSection] = [.syncSwitch]
    private let switchSyncRows: [PhotoSyncSwitchRows] = PhotoSyncSwitchRows.allCases
    private let locationRows: [PhotoSyncLocationRows] = PhotoSyncLocationRows.allCases
    private let settingsRows: [PhotoSyncSettingsRows] = PhotoSyncSettingsRows.allCases
    private let deniedRows: [PhotoSyncDeniedRows] = PhotoSyncDeniedRows.allCases

    private var currentSyncSettings: PhotoSyncSettings!
    private var photoSyncEnabled: Bool!
    private var syncVideosEnabled: Bool!
    private var syncPicturesEnabled: Bool!
    private var syncScreenshotsEnabled: Bool!
    private var createDatedSubFolders: Bool!
    private var deleteAssetsAfterImport: Bool!
    private var syncMode: PhotoSyncMode = .new
    private var selectedDirectory: File? {
        didSet {
            if oldValue == nil || selectedDirectory == nil {
                DispatchQueue.main.async {
                    self.updateSections()
                }
            }
        }
    }

    private var driveFileManager: DriveFileManager?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: ParameterTableViewCell.self)
        tableView.register(cellView: ParameterSwitchTableViewCell.self)
        tableView.register(cellView: ParameterWifiTableViewCell.self)
        tableView.register(cellView: LocationTableViewCell.self)
        tableView.register(cellView: MenuTableViewCell.self)
        tableView.register(cellView: PhotoAccessDeniedTableViewCell.self)

        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listFloatingButtonPaddingBottom, right: 0)
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 50

        photoSyncEnabled = PhotoLibraryUploader.instance.isSyncEnabled
        currentSyncSettings = PhotoLibraryUploader.instance.settings ?? PhotoSyncSettings()

        syncVideosEnabled = currentSyncSettings.syncVideosEnabled
        syncPicturesEnabled = currentSyncSettings.syncPicturesEnabled
        syncScreenshotsEnabled = currentSyncSettings.syncScreenshotsEnabled
        createDatedSubFolders = currentSyncSettings.createDatedSubFolders
        deleteAssetsAfterImport = currentSyncSettings.deleteAssetsAfterImport
        let savedCurrentUserId = currentSyncSettings.userId
        let savedCurrentDriveId = currentSyncSettings.driveId
        if savedCurrentUserId != -1 && savedCurrentDriveId != -1 {
            driveFileManager = AccountManager.instance.getDriveFileManager(for: savedCurrentDriveId, userId: savedCurrentUserId)
        }
        syncMode = currentSyncSettings.syncMode
        updateSaveButtonState()
        updateSectionList()
        if currentSyncSettings.parentDirectoryId != -1 {
            // We should always have the folder in cache but just in case we don't...
            if let photoSyncDirectory = driveFileManager?.getCachedFile(id: currentSyncSettings.parentDirectoryId) {
                selectedDirectory = photoSyncDirectory
                updateSaveButtonState()
            } else {
                driveFileManager?.getFile(id: currentSyncSettings.parentDirectoryId) { file, _, _ in
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        navigationController?.navigationBar.isTranslucent = true
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
        let previousCount = sections.count
        updateSectionList()
        let newCount = sections.count
        if newCount - previousCount < 0 {
            // Delete sections
            tableView.deleteSections(IndexSet(newCount ..< previousCount), with: .fade)
        } else {
            // Insert sections
            tableView.insertSections(IndexSet(previousCount ..< newCount), with: .fade)
        }
    }

    func updateSaveButtonState() {
        var isEdited = false
        if PhotoLibraryUploader.instance.isSyncEnabled != photoSyncEnabled {
            isEdited = true
        } else if PhotoLibraryUploader.instance.isSyncEnabled == photoSyncEnabled && photoSyncEnabled {
            isEdited = PhotoLibraryUploader.instance.isSyncEnabled != photoSyncEnabled ||
                currentSyncSettings.driveId != driveFileManager?.drive.id ||
                currentSyncSettings.userId != driveFileManager?.drive.userId ||
                currentSyncSettings.parentDirectoryId != selectedDirectory?.id ||
                currentSyncSettings.syncPicturesEnabled != syncPicturesEnabled ||
                currentSyncSettings.syncVideosEnabled != syncVideosEnabled ||
                currentSyncSettings.syncScreenshotsEnabled != syncScreenshotsEnabled ||
                currentSyncSettings.createDatedSubFolders != createDatedSubFolders ||
                currentSyncSettings.deleteAssetsAfterImport != deleteAssetsAfterImport ||
                currentSyncSettings.syncMode != syncMode
        }
        saveButton.isHidden = !isEdited

        if (driveFileManager == nil || selectedDirectory == nil) && photoSyncEnabled {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = isEdited
        }
    }

    @IBAction func saveButtonPressed(_ sender: UIButton) {
        DispatchQueue.global(qos: .utility).async {
            let realm = DriveFileManager.constants.uploadsRealm
            self.saveSettings(using: realm)
            DispatchQueue.main.async {
                self.navigationController?.popViewController(animated: true)
            }
            _ = PhotoLibraryUploader.instance.addNewPicturesToUploadQueue(using: realm)
        }
    }

    func saveSettings(using realm: Realm) {
        guard let driveFileManager = driveFileManager, let selectedDirectory = selectedDirectory else { return }
        if photoSyncEnabled {
            let lastSyncDate: Date
            if syncMode == .new {
                lastSyncDate = Date(timeIntervalSinceNow: 0)
            } else {
                lastSyncDate = Date(timeIntervalSince1970: 0)
            }

            let newSettings = PhotoSyncSettings(userId: driveFileManager.drive.userId,
                                                driveId: driveFileManager.drive.id,
                                                parentDirectoryId: selectedDirectory.id,
                                                lastSync: lastSyncDate,
                                                syncMode: syncMode,
                                                syncPictures: syncPicturesEnabled,
                                                syncVideos: syncVideosEnabled,
                                                syncScreenshots: syncScreenshotsEnabled,
                                                createDatedSubFolders: createDatedSubFolders,
                                                deleteAssetsAfterImport: deleteAssetsAfterImport)
            PhotoLibraryUploader.instance.enableSync(with: newSettings)
        } else {
            PhotoLibraryUploader.instance.disableSync()
        }
    }

    private func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                completion(status)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                completion(status)
            }
        }
    }

    class func instantiate() -> PhotoSyncSettingsViewController {
        return Storyboard.menu.instantiateViewController(withIdentifier: "PhotoSyncSettingsViewController") as! PhotoSyncSettingsViewController
    }
}

// MARK: - Table view data source

extension PhotoSyncSettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .syncSwitch:
            let saveDetailsHeaderText = KDriveStrings.Localizable.syncSettingsDescription
            // We recycle the header view, it's easier to add \n than setting dynamic constraints
            let headerView = HomeTitleView.instantiate(title: "\n" + saveDetailsHeaderText + "\n")
            headerView.titleLabel.font = .systemFont(ofSize: 14)
            headerView.titleLabel.numberOfLines = 0
            return headerView
        case .syncLocation:
            return HomeTitleView.instantiate(title: KDriveStrings.Localizable.syncSettingsSaveOn)
        case .syncSettings:
            return HomeTitleView.instantiate(title: KDriveStrings.Localizable.settingsTitle)
        case .syncDenied:
            return nil
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .syncSwitch:
            return switchSyncRows.count
        case .syncLocation:
            return locationRows.count
        case .syncSettings:
            return settingsRows.count
        case .syncDenied:
            return deniedRows.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .syncSwitch:
            switch switchSyncRows[indexPath.row] {
            case .syncSwitch:
                let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == switchSyncRows.count - 1)
                cell.valueLabel.text = KDriveStrings.Localizable.syncSettingsButtonActiveSync
                cell.valueSwitch.setOn(photoSyncEnabled, animated: true)
                cell.switchHandler = { [weak self] sender in
                    guard let self = self else { return }
                    if sender.isOn {
                        self.requestAuthorization { status in
                            DispatchQueue.main.async {
                                self.driveFileManager = AccountManager.instance.currentDriveFileManager
                                if status == .authorized {
                                    self.photoSyncEnabled = true
                                } else {
                                    sender.setOn(false, animated: true)
                                    self.photoSyncEnabled = false
                                }
                                self.updateSections()
                                self.updateSaveButtonState()
                            }
                        }
                    } else {
                        self.photoSyncEnabled = false
                        self.updateSections()
                        self.updateSaveButtonState()
                    }
                }
                return cell
            }
        case .syncLocation:
            switch locationRows[indexPath.row] {
            case .driveSelection:
                let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == locationRows.count - 1)
                cell.configure(with: driveFileManager?.drive)
                return cell
            case .folderSelection:
                let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == locationRows.count - 1)
                cell.configure(with: selectedDirectory, drive: driveFileManager!.drive)

                return cell
            }
        case .syncSettings:
            switch settingsRows[indexPath.row] {
            case .importPicturesSwitch:
                let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.valueLabel.text = KDriveStrings.Localizable.syncSettingsButtonSyncPicture
                cell.valueSwitch.setOn(syncPicturesEnabled, animated: true)
                cell.switchHandler = { [weak self] sender in
                    self?.syncPicturesEnabled = sender.isOn
                    self?.updateSaveButtonState()
                }
                return cell
            case .importVideosSwitch:
                let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.valueLabel.text = KDriveStrings.Localizable.syncSettingsButtonSyncVideo
                cell.valueSwitch.setOn(syncVideosEnabled, animated: true)
                cell.switchHandler = { [weak self] sender in
                    self?.syncVideosEnabled = sender.isOn
                    self?.updateSaveButtonState()
                }
                return cell
            case .importScreenshotsSwitch:
                let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.valueLabel.text = KDriveStrings.Localizable.syncSettingsButtonSyncScreenshot
                cell.valueSwitch.setOn(syncScreenshotsEnabled, animated: true)
                cell.switchHandler = { [weak self] sender in
                    self?.syncScreenshotsEnabled = sender.isOn
                    self?.updateSaveButtonState()
                }
                return cell
            case .createDatedSubFolders:
                let cell = tableView.dequeueReusableCell(type: ParameterWifiTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.titleLabel.text = KDriveStrings.Localizable.createDatedSubFoldersTitle
                cell.detailsLabel.text = KDriveStrings.Localizable.createDatedSubFoldersDescription
                cell.valueSwitch.setOn(createDatedSubFolders, animated: true)
                cell.switchHandler = { [weak self] sender in
                    self?.createDatedSubFolders = sender.isOn
                    self?.updateSaveButtonState()
                }
                return cell
            case .deleteAssetsAfterImport:
                let cell = tableView.dequeueReusableCell(type: ParameterWifiTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.titleLabel.text = KDriveStrings.Localizable.deletePicturesTitle
                cell.detailsLabel.text = KDriveStrings.Localizable.deletePicturesDescription
                cell.valueSwitch.setOn(deleteAssetsAfterImport, animated: true)
                cell.switchHandler = { [weak self] sender in
                    self?.deleteAssetsAfterImport = sender.isOn
                    self?.updateSaveButtonState()
                }
                return cell
            case .syncMode:
                let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.titleLabel.text = KDriveStrings.Localizable.syncSettingsButtonSaveDate
                cell.valueLabel.text = syncMode == .new ? KDriveStrings.Localizable.syncSettingsSaveDateNowValue : KDriveStrings.Localizable.syncSettingsSaveDateAllPictureValue
                return cell
            }
        case .syncDenied:
            switch deniedRows[indexPath.row] {
            case .deniedExplanation:
                return tableView.dequeueReusableCell(type: PhotoAccessDeniedTableViewCell.self, for: indexPath)
            }
        }
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
                if let selectedDrive = driveFileManager?.drive {
                    selectDriveViewController.selectedDrive = selectedDrive
                    selectDriveViewController.delegate = self
                    navigationController?.pushViewController(selectDriveViewController, animated: true)
                }
            } else if row == .folderSelection {
                if let driveFileManager = driveFileManager {
                    let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager, startDirectory: selectedDirectory, disabledDirectoriesSelection: [driveFileManager.getRootFile()], delegate: self)
                    navigationController?.present(selectFolderNavigationController, animated: true)
                }
            }

        } else if section == .syncSettings {
            let row = settingsRows[indexPath.row]
            if row == .syncMode {
                let alert = AlertChoiceViewController(title: KDriveStrings.Localizable.syncSettingsButtonSaveDate, choices: [KDriveStrings.Localizable.syncSettingsSaveDateNowValue2, KDriveStrings.Localizable.syncSettingsSaveDateAllPictureValue], selected: syncMode == .new ? 0 : 1, action: KDriveStrings.Localizable.buttonValid) { selectedIndex in
                    self.syncMode = selectedIndex == 0 ? .new : .all
                    self.updateSaveButtonState()
                    self.tableView.reloadRows(at: [indexPath], with: .fade)

                    if self.syncMode == .all {
                        if #available(iOS 13.0, *) { } else {
                            // DispatchQueue because we need to present this view after dismissing the previous one
                            DispatchQueue.main.async {
                                let alertController = AlertTextViewController(title: KDriveStrings.Localizable.ios12LimitationPhotoSyncTitle, message: KDriveStrings.Localizable.ios12LimitationPhotoSyncDescription, action: KDriveStrings.Localizable.buttonClose, hasCancelButton: false, handler: nil)
                                self.present(alertController, animated: true)
                            }
                        }
                    }
                }
                present(alert, animated: true)
            }
        }
    }
}

// MARK: - Select drive delegate

extension PhotoSyncSettingsViewController: SelectDriveDelegate {
    func didSelectDrive(_ drive: Drive) {
        driveFileManager = AccountManager.instance.getDriveFileManager(for: drive)
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
