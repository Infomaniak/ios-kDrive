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

import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class EditCategoryViewController: UITableViewController {
    @LazyInjectService var accountManager: AccountManageable

    var driveFileManager: DriveFileManager!
    // If we have a category we edit it, otherwise, we create a new one
    var category: kDriveCore.Category?
    /// The files to add the category to after creating it.
    var filesToAdd: [File]?
    var name = ""

    var color = "#1abc9c"

    private var rows: [Row] = [.name, .color]

    private enum Row: CaseIterable {
        case editInfo, name, color
    }

    private var create: Bool {
        return category == nil
    }

    private var saveButtonEnabled: Bool {
        if let category {
            return category.isPredefined || !category.name.isBlank
        } else {
            return !name.isBlank
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: AlertTableViewCell.self)
        tableView.register(cellView: FileNameTableViewCell.self)
        tableView.register(cellView: ColorSelectionTableViewCell.self)

        updateTitle()
        setRows()
        hideKeyboardWhenTappedAround()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            self.tableView.reloadData()
        }
    }

    private func updateTitle() {
        title = create ? KDriveResourcesStrings.Localizable.createCategoryTitle : KDriveResourcesStrings.Localizable
            .editCategoryTitle
    }

    private func setRows() {
        rows = [.name, .color]
        if !create {
            rows.insert(.editInfo, at: 0)
            // Remove name edition for predefined categories
            if category?.isPredefined == true, let index = rows.firstIndex(of: .name) {
                rows.remove(at: index)
            }
        }
    }

    static func instantiate(driveFileManager: DriveFileManager) -> EditCategoryViewController {
        let viewController = Storyboard.files
            .instantiateViewController(withIdentifier: "EditCategoryViewController") as! EditCategoryViewController
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
        if let categoryId = category?.id {
            coder.encode(categoryId, forKey: "CategoryId")
        }
        if let filesIdToAdd = filesToAdd?.map(\.id) {
            coder.encode(filesIdToAdd, forKey: "FilesId")
        }
        coder.encode(name, forKey: "Name")
        coder.encode(color, forKey: "Color")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        let categoryId = coder.decodeInteger(forKey: "CategoryId")
        let filesId = coder.decodeObject(of: [NSNumber.self], forKey: "FilesId") as? [NSNumber]
        if let name = coder.decodeObject(of: NSString.self, forKey: "Name") {
            self.name = name as String
        }
        if let color = coder.decodeObject(of: NSString.self, forKey: "Color") {
            self.color = color as String
        }

        guard let driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: accountManager.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
        category = driveFileManager.drive.categories.first { $0.id == categoryId }
        filesToAdd = filesId?.compactMap { driveFileManager.getCachedFile(id: Int(truncating: $0)) }
        // Reload view
        updateTitle()
        setRows()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .editInfo:
            let cell = tableView.dequeueReusableCell(type: AlertTableViewCell.self, for: indexPath)
            cell.configure(with: .info, message: KDriveResourcesStrings.Localizable.editCategoryInfoDescription)
            return cell
        case .name:
            let cell = tableView.dequeueReusableCell(type: FileNameTableViewCell.self, for: indexPath)
            cell.textField.setHint(KDriveResourcesStrings.Localizable.categoryNameField)
            cell.textField.text = category?.name ?? name
            cell.textDidChange = { [unowned self] text in
                if let text {
                    if create {
                        name = text
                    } else {
                        category?.name = text
                    }
                    // Update save button
                    guard let footer = tableView.footerView(forSection: tableView.numberOfSections - 1) as? FooterButtonView
                    else {
                        return
                    }
                    footer.footerButton.isEnabled = saveButtonEnabled
                }
            }
            cell.textField.becomeFirstResponder()
            return cell
        case .color:
            let cell = tableView.dequeueReusableCell(type: ColorSelectionTableViewCell.self, for: indexPath)
            cell.delegate = self
            cell.selectColor(category?.colorHex ?? color)
            cell.layoutIfNeeded()
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = FooterButtonView.instantiate(title: KDriveResourcesStrings.Localizable.buttonSave)
        view.footerButton.isEnabled = saveButtonEnabled
        view.delegate = self
        return view
    }
}

// MARK: - Category color delegate

extension EditCategoryViewController: ColorSelectionDelegate {
    func didSelectColor(_ color: String) {
        if create {
            self.color = color
        } else {
            category?.colorHex = color
        }
    }
}

// MARK: - Footer button delegate

extension EditCategoryViewController: FooterButtonDelegate {
    @objc func didClickOnButton() {
        MatomoUtils.track(eventWithCategory: .categories, name: category != nil ? "update" : "add")
        Task { [proxyFilesToAdd = filesToAdd?.map { $0.proxify() }] in
            do {
                if let category {
                    // Edit category
                    _ = try await driveFileManager.edit(
                        category: category,
                        name: category.isPredefined ? nil : category.name,
                        color: category.colorHex
                    )
                    navigationController?.popViewController(animated: true)
                } else {
                    // Create category
                    let category = try await driveFileManager.createCategory(name: name, color: color)
                    // If files were given, add the new category to them
                    if let proxyFilesToAdd {
                        try await driveFileManager.add(category: category, to: proxyFilesToAdd)
                    }
                    navigationController?.popViewController(animated: true)
                }
            } catch {
                UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
    }
}
