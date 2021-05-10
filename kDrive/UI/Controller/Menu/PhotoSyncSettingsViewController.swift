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
import Photos
import kDriveCore
import RealmSwift

class PhotoSyncSettingsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var saveButton: UIButton!

    private enum PhotoSyncSection {
        case syncSwitch
        case syncLocation
        case syncSettings
        case syncDenied
    }
    private enum PhotoSyncSwitchRows {
        case syncSwitch
    }
    private enum PhotoSyncLocationRows {
        case driveSelection
        case folderSelection
    }
    private enum PhotoSyncSettingsRows {
        case importPicturesSwitch
        case importVideosSwitch
        case importScreenshotsSwitch
        case syncMode
    }
    private enum PhotoSyncDeniedRows {
        case deniedExplanation
    }
    private var sections: [PhotoSyncSection] = [.syncSwitch]
    private let switchSyncRows: [PhotoSyncSwitchRows] = [.syncSwitch]
    private let locationRows: [PhotoSyncLocationRows] = [.driveSelection, .folderSelection]
    private let settingsRows: [PhotoSyncSettingsRows] = [.importPicturesSwitch, .importVideosSwitch, .importScreenshotsSwitch, .syncMode]
    private let deniedRows: [PhotoSyncDeniedRows] = [.deniedExplanation]

    private var currentSyncSettings: PhotoSyncSettings!
    private var photoSyncEnabled: Bool!
    private var syncVideosEnabled: Bool!
    private var syncPicturesEnabled: Bool!
    private var syncScreenshotsEnabled: Bool!
    private var currentUserId: Int!
    private var currentDriveId: Int!
    private var syncMode: PhotoSyncMode = .new
    private var selectedDirectory: File?

    var driveFileManager: DriveFileManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: ParameterTableViewCell.self)
        tableView.register(cellView: ParameterSwitchTableViewCell.self)
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
        let savedCurrentId = currentSyncSettings.userId
        currentUserId = savedCurrentId == -1 ? AccountManager.instance.currentAccount.userId : savedCurrentId
        let savedCurrentDrive = currentSyncSettings.driveId
        currentDriveId = savedCurrentDrive == -1 ? driveFileManager.drive.id : savedCurrentDrive
        syncMode = currentSyncSettings.syncMode
        updateSaveButtonState()
        updateSectionList()
        if currentSyncSettings.parentDirectoryId != -1,
            let drive = AccountManager.instance.getDrive(for: currentUserId, driveId: currentDriveId),
            let driveFileManager = AccountManager.instance.getDriveFileManager(for: drive) {
            //We should always have the folder in cache but just in case we don't...
            if let photoSyncDirectory = driveFileManager.getCachedFile(id: currentSyncSettings.parentDirectoryId) {
                self.selectedDirectory = photoSyncDirectory
                self.updateSaveButtonState()
            } else {
                driveFileManager.getFile(id: currentSyncSettings.parentDirectoryId) { (file, _, _) in
                    self.selectedDirectory = file?.freeze()
                    self.tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .none)
                }
            }
        }
    }

    func updateSectionList() {
        if photoSyncEnabled {
            sections = [.syncSwitch, .syncLocation, .syncSettings]
        } else {
            var limited = false
            if #available(iOS 14, *) {
                limited = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
            }
            if limited || PHPhotoLibrary.authorizationStatus() == .denied {
                sections = [.syncSwitch, .syncDenied]
            } else {
                sections = [.syncSwitch]
            }
        }
    }

    func updateSaveButtonState() {
        var isEdited = false
        if PhotoLibraryUploader.instance.isSyncEnabled != photoSyncEnabled {
            isEdited = true
        } else if PhotoLibraryUploader.instance.isSyncEnabled == photoSyncEnabled && photoSyncEnabled {
            isEdited = PhotoLibraryUploader.instance.isSyncEnabled != photoSyncEnabled ||
                currentSyncSettings.driveId != currentDriveId ||
                currentSyncSettings.userId != currentUserId ||
                currentSyncSettings.parentDirectoryId != selectedDirectory?.id ||
                currentSyncSettings.syncPicturesEnabled != syncPicturesEnabled ||
                currentSyncSettings.syncVideosEnabled != syncVideosEnabled ||
                currentSyncSettings.syncScreenshotsEnabled != syncScreenshotsEnabled ||
                currentSyncSettings.syncMode != syncMode
        }
        saveButton.isHidden = !isEdited
        
        if selectedDirectory == nil && photoSyncEnabled {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = isEdited
        }
    }

    @IBAction func saveButtonPressed(_ sender: UIButton) {
        DispatchQueue.global(qos: .utility).async {
            let realm = DriveFileManager.constants.uploadsRealm
            self.saveSettings(using: realm)
            let _ = PhotoLibraryUploader.instance.addNewPicturesToUploadQueue(using: realm)
        }
        navigationController?.popViewController(animated: true)
    }

    func saveSettings(using realm: Realm) {
        if photoSyncEnabled {
            let lastSyncDate: Date
            if syncMode == .new {
                lastSyncDate = Date(timeIntervalSinceNow: 0)
            } else {
                lastSyncDate = Date(timeIntervalSince1970: 0)
            }

            let newSettings = PhotoSyncSettings(userId: currentUserId,
                driveId: currentDriveId,
                parentDirectoryId: selectedDirectory!.id,
                lastSync: lastSyncDate,
                syncMode: syncMode,
                syncPictures: syncPicturesEnabled,
                syncVideos: syncVideosEnabled,
                syncScreenshots: syncScreenshotsEnabled)
            PhotoLibraryUploader.instance.enableSyncWithSettings(newSettings)
        } else {
            PhotoLibraryUploader.instance.disableSync()
        }
    }

    private func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { (status) in
                completion(status)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { (status) in
                completion(status)
            }
        }
    }

    class func instantiate() -> PhotoSyncSettingsViewController {
        return UIStoryboard(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "PhotoSyncSettingsViewController") as! PhotoSyncSettingsViewController
    }

}

// MARK: - Table view data source
extension PhotoSyncSettingsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .syncSwitch:
            let saveDetailsHeaderText = KDriveStrings.Localizable.syncSettingsDescription
            //We recycle the header view, it's easier to add \n than setting dynamic constraints
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
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == (self.tableView(tableView, numberOfRowsInSection: indexPath.section)) - 1)
                cell.valueLabel.text = KDriveStrings.Localizable.syncSettingsButtonActiveSync
                cell.valueSwitch.setOn(photoSyncEnabled, animated: true)
                cell.switchDelegate = { sender in
                    if sender.isOn {
                        self.requestAuthorization { (status) in
                            DispatchQueue.main.async {
                                self.currentUserId = AccountManager.instance.currentAccount.userId
                                self.currentDriveId = self.driveFileManager.drive.id
                                if status == .authorized {
                                    self.photoSyncEnabled = true
                                } else {
                                    sender.setOn(false, animated: true)
                                    self.photoSyncEnabled = false
                                }
                                let previousCount = self.sections.count
                                self.updateSectionList()
                                let newCount = self.sections.count
                                if previousCount != newCount {
                                    if newCount == 3 {
                                        tableView.insertSections([1, 2], with: .fade)
                                    } else {
                                        tableView.insertSections([1], with: .fade)
                                    }
                                }
                                self.updateSaveButtonState()
                            }
                        }
                    } else {
                        self.photoSyncEnabled = false
                        self.updateSaveButtonState()
                        self.updateSectionList()
                        tableView.deleteSections([1, 2], with: .fade)
                    }
                }
                return cell
            }
        case .syncLocation:
            switch locationRows[indexPath.row] {
            case .driveSelection:
                let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == (self.tableView(tableView, numberOfRowsInSection: indexPath.section)) - 1)
                cell.configure(with: AccountManager.instance.getDrive(for: currentUserId, driveId: currentDriveId))
                return cell
            case .folderSelection:
                let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == (self.tableView(tableView, numberOfRowsInSection: indexPath.section)) - 1)
                cell.configure(with: selectedDirectory, drive: AccountManager.instance.getDrive(for: currentUserId, driveId: currentDriveId)!)

                return cell
            }
        case .syncSettings:
            switch settingsRows[indexPath.row] {
            case .importPicturesSwitch:
                let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == (self.tableView(tableView, numberOfRowsInSection: indexPath.section)) - 1)
                cell.valueLabel.text = KDriveStrings.Localizable.syncSettingsButtonSyncPicture
                cell.valueSwitch.setOn(syncPicturesEnabled, animated: true)
                cell.switchDelegate = { sender in
                    self.syncPicturesEnabled = sender.isOn
                    self.updateSaveButtonState()
                }
                return cell
            case .importVideosSwitch:
                let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == (self.tableView(tableView, numberOfRowsInSection: indexPath.section)) - 1)
                cell.valueLabel.text = KDriveStrings.Localizable.syncSettingsButtonSyncVideo
                cell.valueSwitch.setOn(syncVideosEnabled, animated: true)
                cell.switchDelegate = { sender in
                    self.syncVideosEnabled = sender.isOn
                    self.updateSaveButtonState()
                }
                return cell
            case .importScreenshotsSwitch:
                let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == (self.tableView(tableView, numberOfRowsInSection: indexPath.section)) - 1)
                cell.valueLabel.text = KDriveStrings.Localizable.syncSettingsButtonSyncScreenshot
                cell.valueSwitch.setOn(syncScreenshotsEnabled, animated: true)
                cell.switchDelegate = { sender in
                    self.syncScreenshotsEnabled = sender.isOn
                    self.updateSaveButtonState()
                }
                return cell
            case .syncMode:
                let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == (self.tableView(tableView, numberOfRowsInSection: indexPath.section)) - 1)
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
                if let selectedDrive = AccountManager.instance.getDrive(for: currentUserId, driveId: currentDriveId) {
                    selectDriveViewController.selectedDrive = selectedDrive
                    selectDriveViewController.delegate = self
                    navigationController?.pushViewController(selectDriveViewController, animated: true)
                }
            } else if row == .folderSelection {
                let drive = AccountManager.instance.getDrive(for: currentUserId, driveId: currentDriveId)!
                let driveFileManager = AccountManager.instance.getDriveFileManager(for: drive)!
                let selectFolderNavigationViewController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager)
                (selectFolderNavigationViewController.viewControllers.first as? SelectFolderViewController)?.delegate = self
                (selectFolderNavigationViewController.viewControllers.first as? SelectFolderViewController)?.disabledDirectoriesSelection = [driveFileManager.getRootFile()]
                navigationController?.present(selectFolderNavigationViewController, animated: true)
            }

        } else if section == .syncSettings {
            let row = settingsRows[indexPath.row]
            if row == .syncMode {
                let alert = AlertChoiceViewController(title: KDriveStrings.Localizable.syncSettingsButtonSaveDate, choices: [KDriveStrings.Localizable.syncSettingsSaveDateNowValue2, KDriveStrings.Localizable.syncSettingsSaveDateAllPictureValue], selected: syncMode == .new ? 0 : 1, action: KDriveStrings.Localizable.buttonValid) { (selectedIndex) in
                    self.syncMode = selectedIndex == 0 ? .new : .all
                    self.updateSaveButtonState()
                    self.tableView.reloadRows(at: [indexPath], with: .fade)

                    if self.syncMode == .all {
                        if #available(iOS 13.0, *) { } else {
                            //DispatchQueue because we need to present this view after dismissing the previous one
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
        currentUserId = drive.userId
        currentDriveId = drive.id
        driveFileManager = AccountManager.instance.getDriveFileManager(for: drive)!
        selectedDirectory = nil
        self.updateSaveButtonState()
        tableView.reloadRows(at: [IndexPath(row: 0, section: 1), IndexPath(row: 1, section: 1)], with: .fade)
    }

}

// MARK: - Select folder delegate
extension PhotoSyncSettingsViewController: SelectFolderDelegate {

    func didSelectFolder(_ folder: File) {
        selectedDirectory = folder
        self.updateSaveButtonState()
        tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .fade)
    }

}
