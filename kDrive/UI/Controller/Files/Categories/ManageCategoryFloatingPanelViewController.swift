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
import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class CategoryFloatingPanelAction: Equatable {
    let id: Int
    let name: String
    let image: UIImage
    var tintColor: UIColor = KDriveResourcesAsset.iconColor.color
    var isEnabled = true

    init(id: Int, name: String, image: UIImage, tintColor: UIColor = KDriveResourcesAsset.iconColor.color) {
        self.id = id
        self.name = name
        self.image = image
        self.tintColor = tintColor
    }

    static let edit = CategoryFloatingPanelAction(id: 1,
                                                  name: KDriveResourcesStrings.Localizable.buttonEdit,
                                                  image: KDriveResourcesAsset.edit.image)
    static let delete = CategoryFloatingPanelAction(id: 2,
                                                    name: KDriveResourcesStrings.Localizable.buttonDelete,
                                                    image: KDriveResourcesAsset.delete.image,
                                                    tintColor: KDriveResourcesAsset.binColor.color)

    static var actions: [CategoryFloatingPanelAction] {
        return [edit, delete]
    }

    static func == (lhs: CategoryFloatingPanelAction, rhs: CategoryFloatingPanelAction) -> Bool {
        return lhs.id == rhs.id
    }
}

class ManageCategoryFloatingPanelViewController: UICollectionViewController {
    weak var presentingParent: UIViewController?

    var driveFileManager: DriveFileManager!
    var category: kDriveCore.Category!

    private enum Section: CaseIterable {
        case header, actions
    }

    private let actions = CategoryFloatingPanelAction.actions

    // MARK: - Public methods

    convenience init() {
        self.init(collectionViewLayout: Self.createLayout())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(WrapperCollectionViewCell.self, forCellWithReuseIdentifier: "WrapperCollectionViewCell")
        collectionView.register(cellView: FloatingPanelQuickActionCollectionViewCell.self)
        collectionView.alwaysBounceVertical = false
        collectionView.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color

        setupContent()
    }

    // MARK: - Private methods

    private static func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { section, _ in
            switch Section.allCases[section] {
            case .header:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(56))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            case .actions:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
                group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)
                return NSCollectionLayoutSection(group: group)
            }
        }
    }

    private func setupContent() {
        for action in actions {
            switch action {
            case .edit:
                action.isEnabled = driveFileManager.drive.categoryRights.canEdit
            case .delete:
                action.isEnabled = driveFileManager.drive.categoryRights.canDelete && !category.isPredefined
            default:
                break
            }
        }
    }

    private func handleAction(_ action: CategoryFloatingPanelAction, at indexPath: IndexPath) {
        @InjectService var matomo: MatomoUtils
        switch action {
        case .edit:
            let editCategoryViewController = EditCategoryViewController.instantiate(driveFileManager: driveFileManager)
            editCategoryViewController.category = Category(value: category!)
            presentingParent?.navigationController?.pushViewController(editCategoryViewController, animated: true)
            dismiss(animated: true)
        case .delete:
            let attrString = NSMutableAttributedString(
                string: KDriveResourcesStrings.Localizable.modalDeleteCategoryDescription(category.name),
                boldText: category.name
            )
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.buttonDelete,
                                                message: attrString,
                                                action: KDriveResourcesStrings.Localizable.buttonDelete,
                                                destructive: true,
                                                loading: true) {
                matomo.track(eventWithCategory: .categories, name: "delete")
                do {
                    let response = try await self.driveFileManager.delete(category: self.category)
                    if response {
                        // Dismiss panel
                        (self.presentingParent as? ManageCategoriesViewController)?.reloadCategories()
                        self.presentingParent?.dismiss(animated: true)
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackBarCategoryDeleted)
                    } else {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorDelete)
                    }
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
            }
            present(alert, animated: true)
        default:
            break
        }
    }

    // MARK: - Collection view data source

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Section.allCases.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section.allCases[section] {
        case .header:
            return 1
        case .actions:
            return actions.count
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section.allCases[indexPath.section] {
        case .header:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "WrapperCollectionViewCell",
                for: indexPath
            ) as! WrapperCollectionViewCell
            let tableCell = cell.reuse(withCellType: CategoryTableViewCell.self)
            tableCell.initWithPositionAndShadow()
            tableCell.configure(with: category, showMoreButton: false)
            tableCell.leadingConstraint.constant = 0
            return cell
        case .actions:
            let cell = collectionView.dequeueReusableCell(type: FloatingPanelQuickActionCollectionViewCell.self, for: indexPath)
            let action = actions[indexPath.item]
            cell.configure(name: action.name,
                           icon: action.image,
                           tintColor: action.tintColor,
                           isEnabled: action.isEnabled,
                           isLoading: false)
            return cell
        }
    }

    // MARK: - Collection view delegate

    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        switch Section.allCases[indexPath.section] {
        case .header:
            return false
        case .actions:
            return actions[indexPath.item].isEnabled
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section.allCases[indexPath.section] {
        case .header:
            break
        case .actions:
            let action = actions[indexPath.item]
            handleAction(action, at: indexPath)
        }
    }
}

extension ManageCategoryFloatingPanelViewController: FloatingPanelControllerDelegate {
    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout {
        return PlusButtonFloatingPanelLayout(height: min(180, UIScreen.main.bounds.size.height - 48))
    }
}
