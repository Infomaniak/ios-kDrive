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

class PhotoSyncSettingsViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploader

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
        case photoFormat
    }

    private enum PhotoSyncDeniedRows: CaseIterable {
        case deniedExplanation
    }

    private var sections: [PhotoSyncSection] = [.syncSwitch]
    private let switchSyncRows: [PhotoSyncSwitchRows] = PhotoSyncSwitchRows.allCases
    private let locationRows: [PhotoSyncLocationRows] = PhotoSyncLocationRows.allCases
    private let settingsRows: [PhotoSyncSettingsRows] = PhotoSyncSettingsRows.allCases
    private let deniedRows: [PhotoSyncDeniedRows] = PhotoSyncDeniedRows.allCases

    private var newSyncSettings: PhotoSyncSettings = {
        @InjectService var photoUploader: PhotoLibraryUploader
        if photoUploader.settings != nil {
            return PhotoSyncSettings(value: photoUploader.settings as Any)
        } else {
            return PhotoSyncSettings()
        }
    }()

    private var photoSyncEnabled: Bool = InjectService<PhotoLibraryUploader>().wrappedValue.isSyncEnabled
    private var selectedDirectory: File? {
        didSet {
            newSyncSettings.parentDirectoryId = selectedDirectory?.id ?? -1
            if oldValue == nil || selectedDirectory == nil {
                Task { @MainActor in
                    self.updateSections()
                }
            }
        }
    }

    private var driveFileManager: DriveFileManager? {
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

    func saveSettings() async {
        BackgroundRealm.uploads.execute { _ in
            if self.photoSyncEnabled {
                guard self.newSyncSettings.userId != -1 && self.newSyncSettings.driveId != -1 && self.newSyncSettings
                    .parentDirectoryId != -1
                else { return }
                switch self.newSyncSettings.syncMode {
                case .new:
                    self.newSyncSettings.lastSync = Date()
                case .all:
                    if let currentSyncSettings = self.photoLibraryUploader.settings, currentSyncSettings.syncMode == .all {
                        self.newSyncSettings.lastSync = currentSyncSettings.lastSync
                    } else {
                        self.newSyncSettings.lastSync = Date(timeIntervalSince1970: 0)
                    }
                case .fromDate:
                    if let currentSyncSettings = self.photoLibraryUploader.settings,
                       currentSyncSettings
                       .syncMode == .all ||
                       (currentSyncSettings.syncMode == .fromDate && currentSyncSettings.fromDate
                           .compare(self.newSyncSettings.fromDate) == .orderedAscending) {
                        self.newSyncSettings.lastSync = currentSyncSettings.lastSync
                    } else {
                        self.newSyncSettings.lastSync = self.newSyncSettings.fromDate
                    }
                }
                self.photoLibraryUploader.enableSync(with: self.newSyncSettings)
            } else {
                self.photoLibraryUploader.disableSync()
            }
        }
    }

    private func requestAuthorization() async -> PHAuthorizationStatus {
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

// MARK: - Table view data source

extension PhotoSyncSettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .syncSwitch:
            let saveDetailsHeaderText = KDriveResourcesStrings.Localizable.syncSettingsDescription
            // We recycle the header view, it's easier to add \n than setting dynamic constraints
            let headerView = HomeTitleView.instantiate(title: "\n" + saveDetailsHeaderText + "\n")
            headerView.titleLabel.font = .systemFont(ofSize: 14)
            headerView.titleLabel.numberOfLines = 0
            return headerView
        case .syncLocation:
            return HomeTitleView.instantiate(title: KDriveResourcesStrings.Localizable.syncSettingsSaveOn)
        case .syncSettings:
            return HomeTitleView.instantiate(title: KDriveResourcesStrings.Localizable.settingsTitle)
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
                cell.valueLabel.text = KDriveResourcesStrings.Localizable.syncSettingsButtonActiveSync
                cell.valueSwitch.setOn(photoSyncEnabled, animated: true)
                cell.switchHandler = { [weak self] sender in
                    guard let self else { return }
                    if sender.isOn {
                        Task {
                            let status = await self.requestAuthorization()
                            Task { @MainActor in
                                self.driveFileManager = self.accountManager.currentDriveFileManager
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
                        photoSyncEnabled = false
                        updateSections()
                        updateSaveButtonState()
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
                cell.valueLabel.text = KDriveResourcesStrings.Localizable.syncSettingsButtonSyncPicture
                cell.valueSwitch.setOn(newSyncSettings.syncPicturesEnabled, animated: true)
                cell.switchHandler = { [weak self] sender in
                    self?.newSyncSettings.syncPicturesEnabled = sender.isOn
                    self?.updateSaveButtonState()
                }
                return cell
            case .importVideosSwitch:
                let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.valueLabel.text = KDriveResourcesStrings.Localizable.syncSettingsButtonSyncVideo
                cell.valueSwitch.setOn(newSyncSettings.syncVideosEnabled, animated: true)
                cell.switchHandler = { [weak self] sender in
                    self?.newSyncSettings.syncVideosEnabled = sender.isOn
                    self?.updateSaveButtonState()
                }
                return cell
            case .importScreenshotsSwitch:
                let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.valueLabel.text = KDriveResourcesStrings.Localizable.syncSettingsButtonSyncScreenshot
                cell.valueSwitch.setOn(newSyncSettings.syncScreenshotsEnabled, animated: true)
                cell.switchHandler = { [weak self] sender in
                    self?.newSyncSettings.syncScreenshotsEnabled = sender.isOn
                    self?.updateSaveButtonState()
                }
                return cell
            case .createDatedSubFolders:
                let cell = tableView.dequeueReusableCell(type: ParameterWifiTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.titleLabel.text = KDriveResourcesStrings.Localizable.createDatedSubFoldersTitle
                cell.detailsLabel.text = KDriveResourcesStrings.Localizable.createDatedSubFoldersDescription
                cell.valueSwitch.setOn(newSyncSettings.createDatedSubFolders, animated: true)
                cell.switchHandler = { [weak self] sender in
                    self?.newSyncSettings.createDatedSubFolders = sender.isOn
                    self?.updateSaveButtonState()
                }
                return cell
            case .deleteAssetsAfterImport:
                let cell = tableView.dequeueReusableCell(type: ParameterWifiTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.titleLabel.text = KDriveResourcesStrings.Localizable.deletePicturesTitle
                cell.detailsLabel.text = KDriveResourcesStrings.Localizable.deletePicturesDescription
                cell.valueSwitch.setOn(newSyncSettings.deleteAssetsAfterImport, animated: true)
                cell.switchHandler = { [weak self] sender in
                    self?.newSyncSettings.deleteAssetsAfterImport = sender.isOn
                    self?.updateSaveButtonState()
                }
                return cell
            case .syncMode:
                let cell = tableView.dequeueReusableCell(type: PhotoSyncSettingsTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.titleLabel.text = KDriveResourcesStrings.Localizable.syncSettingsButtonSaveDate
                cell.valueLabel.text = newSyncSettings.syncMode.title.lowercased()
                cell.delegate = self
                if newSyncSettings.syncMode == .fromDate {
                    cell.datePicker.isHidden = false
                    cell.datePicker.date = newSyncSettings.fromDate
                } else {
                    cell.datePicker.isHidden = true
                }
                return cell
            case .photoFormat:
                let cell = tableView.dequeueReusableCell(type: PhotoFormatTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
                cell.configure(with: newSyncSettings.photoFormat)
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

        // Making sure the user cannot spam the button on tasks that may take a while
        let button = sender as? IKLargeButton
        button?.setLoading(true)

        Task(priority: .userInitiated) {
            await self.saveSettings()

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
