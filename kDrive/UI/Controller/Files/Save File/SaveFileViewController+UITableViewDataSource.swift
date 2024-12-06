/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

import kDriveResources
import UIKit

// MARK: - UITableViewDataSource

extension SaveFileViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = sections[section]
        if section == .fileName {
            return items.count
        } else {
            return 1
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .alert:
            let cell = tableView.dequeueReusableCell(type: AlertTableViewCell.self, for: indexPath)
            cell.configure(with: .warning, message: KDriveResourcesStrings.Localizable.snackBarUploadError(errorCount))
            return cell
        case .fileName:
            let item = items[indexPath.row]
            if items.count > 1 {
                let cell = tableView.dequeueReusableCell(type: UploadTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(
                    isFirst: indexPath.row == 0,
                    isLast: indexPath.row == self.tableView(tableView, numberOfRowsInSection: indexPath.section) - 1
                )
                cell.configureWith(importedFile: item)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(type: FileNameTableViewCell.self, for: indexPath)
                cell.textField.text = item.name
                cell.textDidChange = { [weak self] text in
                    guard let self else { return }
                    item.name = text ?? KDriveResourcesStrings.Localizable.allUntitledFileName
                    if let text, !text.isEmpty {
                        updateButton()
                    } else {
                        enableButton = false
                    }
                }
                return cell
            }
        case .driveSelection:
            let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.configure(with: selectedDriveFileManager?.drive)
            return cell
        case .directorySelection:
            let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.configure(with: selectedDirectory, drive: selectedDriveFileManager!.drive)
            return cell
        case .photoFormatOption:
            let cell = tableView.dequeueReusableCell(type: PhotoFormatTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.configure(with: userPreferredPhotoFormat)
            return cell
        case .importing:
            let cell = tableView.dequeueReusableCell(type: ImportingTableViewCell.self, for: indexPath)
            cell.importationProgressView.observedProgress = importProgress
            return cell
        default:
            fatalError("Not supported by this datasource")
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableView.numberOfSections - 1 && !importInProgress {
            let view = FooterButtonView.instantiate(title: KDriveResourcesStrings.Localizable.buttonSave)
            view.delegate = self
            view.footerButton.isEnabled = enableButton
            return view
        }
        return nil
    }
}

extension SaveFileViewController {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .fileName:
            return HomeTitleView.instantiate(title: "")
        case .driveSelection:
            return HomeTitleView.instantiate(title: "kDrive")
        case .directorySelection:
            return HomeTitleView.instantiate(title: KDriveResourcesStrings.Localizable.allPathTitle)
        case .photoFormatOption:
            return HomeTitleView.instantiate(title: KDriveResourcesStrings.Localizable.photoFormatTitle)
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == tableView.numberOfSections - 1 && !importInProgress {
            return 124
        }
        return 32
    }
}
