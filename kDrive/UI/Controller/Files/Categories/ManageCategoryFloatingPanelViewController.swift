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

import FloatingPanel
import kDriveCore
import UIKit

struct CategoryFloatingPanelAction: Equatable {
    let id: Int
    let name: String
    let image: UIImage
    var tintColor: UIColor = KDriveAsset.iconColor.color

    static let edit = CategoryFloatingPanelAction(id: 1, name: KDriveStrings.Localizable.buttonEdit, image: KDriveAsset.edit.image)
    static let delete = CategoryFloatingPanelAction(id: 2, name: KDriveStrings.Localizable.buttonDelete, image: KDriveAsset.delete.image, tintColor: KDriveAsset.binColor.color)

    static var actions: [CategoryFloatingPanelAction] {
        return [edit, delete]
    }

    public static func == (lhs: CategoryFloatingPanelAction, rhs: CategoryFloatingPanelAction) -> Bool {
        return lhs.id == rhs.id
    }
}

class ManageCategoryFloatingPanelViewController: UITableViewController {
    weak var presentingParent: UIViewController?

    var driveFileManager: DriveFileManager!
    var category: kDriveCore.Category!

    private var actions = CategoryFloatingPanelAction.actions

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: CategoryTableViewCell.self)
        tableView.register(cellView: CategoryFloatingPanelCollectionTableViewCell.self)
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.alwaysBounceVertical = false
        tableView.backgroundColor = KDriveAsset.backgroundCardViewColor.color

        setupContent()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            // Reload collection view
            if self.tableView.numberOfSections > 1 {
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .fade)
            }
        }
    }

    private func setupContent() {
        actions = actions.filter { action in
            switch action {
            case .edit:
                return driveFileManager.drive.categoryRights.canEditCategory
            case .delete:
                return driveFileManager.drive.categoryRights.canDeleteCategory && !category.isPredefined
            default:
                return true
            }
        }
    }

    private func handleAction(_ action: CategoryFloatingPanelAction, at indexPath: IndexPath) {
        switch action {
        case .edit:
            let editCategoryViewController = EditCategoryViewController.instantiate(driveFileManager: driveFileManager)
            editCategoryViewController.category = Category(value: category!)
            presentingParent?.navigationController?.pushViewController(editCategoryViewController, animated: true)
            dismiss(animated: true)
        case .delete:
            let attrString = NSMutableAttributedString(string: KDriveStrings.Localizable.modalDeleteCategoryDescription(category.name), boldText: category.name)
            let alert = AlertTextViewController(title: KDriveStrings.Localizable.buttonDelete, message: attrString, action: KDriveStrings.Localizable.buttonDelete, destructive: true, loading: true) {
                let group = DispatchGroup()
                var success = false
                group.enter()
                self.driveFileManager.deleteCategory(id: self.category.id) { error in
                    if error == nil {
                        success = true
                    }
                    group.leave()
                }
                _ = group.wait(timeout: .now() + Constants.timeout)
                DispatchQueue.main.async {
                    if success {
                        // Dismiss panel
                        (self.presentingParent as? ManageCategoriesViewController)?.reloadCategories()
                        self.presentingParent?.dismiss(animated: true)
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.snackBarCategoryDeleted)
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorDelete)
                    }
                }
            }
            present(alert, animated: true)
        default:
            break
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            return 98
        } else {
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(type: CategoryTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.configure(with: category, showMoreButton: false)
            cell.leadingConstraint.constant = 0
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(type: CategoryFloatingPanelCollectionTableViewCell.self, for: indexPath)
            cell.delegate = self
            cell.actions = actions
            return cell
        }
    }
}

extension ManageCategoryFloatingPanelViewController: CategoryActionDelegate {
    func didSelectAction(_ action: CategoryFloatingPanelAction) {
        handleAction(action, at: IndexPath(row: 0, section: 1))
    }
}

extension ManageCategoryFloatingPanelViewController: FloatingPanelControllerDelegate {
    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout {
        return PlusButtonFloatingPanelLayout(height: min(170, UIScreen.main.bounds.size.height - 48))
    }
}
