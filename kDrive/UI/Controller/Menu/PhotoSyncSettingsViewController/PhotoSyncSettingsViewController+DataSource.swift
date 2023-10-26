/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

    // MARK: Cell for Sections

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .syncSwitch:
            return cellForSyncSwitchSection(at: indexPath)
        case .syncLocation:
            return cellForSyncLocationSection(at: indexPath)
        case .syncSettings:
            return cellForSyncSettingsSection(at: indexPath)
        case .syncDenied:
            return cellForSyncDeniedSection(at: indexPath)
        }
    }

    private func cellForSyncSwitchSection(at indexPath: IndexPath) -> UITableViewCell {
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
    }

    private func cellForSyncLocationSection(at indexPath: IndexPath) -> UITableViewCell {
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
    }

    private func cellForSyncSettingsSection(at indexPath: IndexPath) -> UITableViewCell {
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
        case .importLocalAlbums:
            let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == settingsRows.count - 1)
            cell.valueLabel.text = "Upload local Albums"
            cell.valueSwitch.setOn(newSyncSettings.syncLocalAlbumsEnabled, animated: true)
            cell.switchHandler = { [weak self] sender in
                self?.newSyncSettings.syncLocalAlbumsEnabled = sender.isOn
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
    }

    private func cellForSyncDeniedSection(at indexPath: IndexPath) -> UITableViewCell {
        switch deniedRows[indexPath.row] {
        case .deniedExplanation:
            return tableView.dequeueReusableCell(type: PhotoAccessDeniedTableViewCell.self, for: indexPath)
        }
    }
}
