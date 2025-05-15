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

import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

protocol ManageCategoriesDelegate: AnyObject {
    func didSelect(category: kDriveCore.Category)
    func didDeselect(category: kDriveCore.Category)
}

final class ManageCategoriesViewController: UITableViewController {
    @IBOutlet var createButton: UIBarButtonItem!

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable

    var driveFileManager: DriveFileManager!
    var frozenFiles: [File]?
    /// Disable category edition (can just add/remove).
    var canEdit = true
    var selectedCategories = [kDriveCore.Category]()

    var completionHandler: (() -> Void)?

    weak var delegate: ManageCategoriesDelegate?
    weak var fileListViewController: FileListViewController?

    private var categories = [kDriveCore.Category]()
    private var filteredCategories = [kDriveCore.Category]()

    private var isSearchBarEmpty: Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }

    private var isFiltering: Bool {
        return searchController.isActive && !isSearchBarEmpty
    }

    private var searchText: String? {
        return searchController.searchBar.text?.trimmingCharacters(in: .whitespaces)
    }

    private var dummyCategory: kDriveCore.Category = {
        let category = kDriveCore.Category()
        category.id = -1
        return category
    }()

    private var userCanCreateAndEditCategories: Bool {
        return driveFileManager?.drive.categoryRights.canCreate == true && canEdit
    }

    private let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hideBackButtonText()

        tableView.register(cellView: CategoryTableViewCell.self)
        tableView.keyboardDismissMode = .onDrag

        updateTitle()

        searchController.hidesNavigationBarDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.searchTextField.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color

        createButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonCreate
        navigationItem.searchController = searchController
        let viewControllersCount = navigationController?.viewControllers.count ?? 0
        if presentingViewController != nil && viewControllersCount < 2 {
            // Show cancel button
            let closeButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
            closeButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
            navigationItem.leftBarButtonItem = closeButton
        }

        definesPresentationContext = true

        updateNavigationItem()
        setUpObserver()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadCategories()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        matomo.track(view: ["ManageCategories"])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Task {
            try await fileListViewController?.viewModel.loadActivities()
        }
    }

    @objc func closeButtonPressed() {
        completionHandler?()
        searchController.dismiss(animated: true)
        dismiss(animated: true)
    }

    func reloadCategories() {
        guard driveFileManager != nil else {
            return
        }

        categories = Array(driveFileManager.drive.categories.sorted(by: \.userUsageCount, ascending: false))

        // Select categories
        if let frozenFiles {
            selectCategories(files: frozenFiles)
        } else {
            selectCategoriesNoFiles()
        }

        if searchController.isActive {
            updateSearchResults(for: searchController)
        } else {
            tableView.reloadData()
        }
    }

    private func selectCategories(files: [File]) {
        var commonCategories = Set<kDriveCore.Category>(categories)

        for file in files {
            var fileCategories = Set<kDriveCore.Category>()
            for category in file.categories {
                if let category = categories.first(where: { $0.id == category.categoryId }) {
                    fileCategories.insert(category)
                }
            }
            commonCategories.formIntersection(fileCategories)
        }

        for category in commonCategories {
            category.isSelected = true
        }
    }

    private func selectCategoriesNoFiles() {
        for category in selectedCategories {
            if let category = categories.first(where: { $0.id == category.id }) {
                category.isSelected = true
            }
        }
    }

    private func updateTitle() {
        title = frozenFiles != nil ? KDriveResourcesStrings.Localizable.manageCategoriesTitle : KDriveResourcesStrings.Localizable
            .addCategoriesTitle
    }

    private func updateNavigationItem() {
        if !userCanCreateAndEditCategories {
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func setUpObserver() {
        guard let frozenFiles else { return }
        let viewControllersCount = navigationController?.viewControllers.count ?? 0
        // Observe files changes
        for file in frozenFiles {
            driveFileManager.observeFileUpdated(self, fileId: file.id) { newFile in
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        return
                    }

                    guard !newFile.isInvalidated else {
                        if self.presentingViewController != nil && viewControllersCount < 2 {
                            self.closeButtonPressed()
                        } else {
                            self.navigationController?.popViewController(animated: true)
                        }
                        return
                    }
                    // Update list of files with new file
                    self.frozenFiles?.removeAll { $0.id == file.id }
                    self.frozenFiles?.append(newFile)
                }
            }
        }
    }

    private func category(at indexPath: IndexPath) -> kDriveCore.Category {
        return isFiltering ? filteredCategories[indexPath.row] : categories[indexPath.row]
    }

    private func showEmptyViewIfNeeded() {
        let isEmpty = (isFiltering ? filteredCategories : categories).isEmpty
        tableView.backgroundView = isEmpty ? EmptyTableView.instantiate(type: .noCategories) : nil
    }

    static func instantiate(frozenFiles: [File]? = nil, driveFileManager: DriveFileManager) -> ManageCategoriesViewController {
        #if DEBUG
        frozenFiles?.forEach { assert($0.isFrozen, "expecting each file to be frozen") }
        #endif

        let viewController = Storyboard.files
            .instantiateViewController(withIdentifier: "ManageCategoriesViewController") as! ManageCategoriesViewController
        if let frozenFiles {
            viewController.frozenFiles = frozenFiles
        }
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    static func instantiateInNavigationController(frozenFiles: [File]? = nil,
                                                  driveFileManager: DriveFileManager) -> UINavigationController {
        let viewController = instantiate(frozenFiles: frozenFiles, driveFileManager: driveFileManager)
        return UINavigationController(rootViewController: viewController)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isFiltering ? filteredCategories.count : categories.count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let category = category(at: indexPath)
        if category.isSelected {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: CategoryTableViewCell.self, for: indexPath)

        let category = category(at: indexPath)
        let count = self.tableView(tableView, numberOfRowsInSection: indexPath.section)

        cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == count - 1)
        if category == dummyCategory {
            cell.configureCreateCell(name: searchText ?? "")
        } else {
            cell.configure(
                with: category,
                showMoreButton: canEdit &&
                    (driveFileManager.drive.categoryRights.canEdit || driveFileManager.drive.categoryRights.canDelete)
            )
        }
        cell.delegate = self

        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let category = category(at: indexPath)

        if frozenFiles != nil {
            matomo.track(eventWithCategory: .categories, name: "assign")
        }

        if category == dummyCategory {
            let editCategoryViewController = EditCategoryViewController.instantiate(driveFileManager: driveFileManager)
            editCategoryViewController.filesToAdd = frozenFiles
            if let searchText {
                editCategoryViewController.name = searchText
            }
            navigationController?.pushViewController(editCategoryViewController, animated: true)
            return
        }

        category.isSelected = true
        if let frozenFiles {
            Task { [proxyFiles = frozenFiles.map { $0.proxify() }] in
                do {
                    try await driveFileManager.add(category: category, to: proxyFiles)
                } catch {
                    category.isSelected = false
                    tableView.deselectRow(at: indexPath, animated: true)
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
            }
        }
        delegate?.didSelect(category: category)
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let category = category(at: indexPath)
        guard category != dummyCategory else { return }

        if frozenFiles != nil {
            matomo.track(eventWithCategory: .categories, name: "remove")
        }

        category.isSelected = false
        if let frozenFiles {
            Task { [proxyFiles = frozenFiles.map { $0.proxify() }] in
                do {
                    try await driveFileManager.remove(category: category, from: proxyFiles)
                } catch {
                    category.isSelected = true
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
            }
        }
        delegate?.didDeselect(category: category)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "createCategory" {
            let viewController = segue.destination as? EditCategoryViewController
            viewController?.driveFileManager = driveFileManager
            viewController?.filesToAdd = frozenFiles
            if let searchText {
                viewController?.name = searchText
            }
        }
    }
}

// MARK: - Search results updating

extension ManageCategoriesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText {
            filteredCategories = categories.filter {
                $0.localizedName.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
            // Append dummy category to show creation cell if the category doesn't exist yet
            if userCanCreateAndEditCategories && !categories
                .contains(where: { $0.localizedName.caseInsensitiveCompare(searchText) == .orderedSame }) {
                filteredCategories.append(dummyCategory)
            }
            tableView.reloadData()
            showEmptyViewIfNeeded()
        }
    }
}

// MARK: - Category cell delegate

extension ManageCategoriesViewController: CategoryCellDelegate {
    func didTapMoreButton(_ cell: CategoryTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        let floatingPanelViewController = DriveFloatingPanelController()
        let manageCategoryViewController = ManageCategoryFloatingPanelViewController()
        manageCategoryViewController.presentingParent = self
        manageCategoryViewController.driveFileManager = driveFileManager
        manageCategoryViewController.category = category(at: indexPath)

        floatingPanelViewController.isRemovalInteractionEnabled = true
        floatingPanelViewController.delegate = manageCategoryViewController

        floatingPanelViewController.set(contentViewController: manageCategoryViewController)
        floatingPanelViewController.track(scrollView: manageCategoryViewController.collectionView)
        present(floatingPanelViewController, animated: true)
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension ManageCategoriesViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        completionHandler?()
    }
}
