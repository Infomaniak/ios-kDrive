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

import kDriveCore
import UIKit

protocol SearchFiltersDelegate: AnyObject {
    func didUpdateFilters(_ filters: Filters)
}

enum FilterType: CaseIterable {
    case date, type, categories

    var title: String {
        switch self {
        case .date:
            return "Date de modification"
        case .type:
            return "Type de fichier"
        case .categories:
            return "Catégories"
        }
    }
}

class SearchFiltersViewController: UITableViewController {
    var driveFileManager: DriveFileManager!
    var filters = Filters()

    weak var delegate: SearchFiltersDelegate?

    private let filterTypes = FilterType.allCases

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: LocationTableViewCell.self)
        tableView.register(cellView: ManageCategoriesTableViewCell.self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()
    }

    // MARK: - Actions

    @IBAction func closeButtonPressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return filterTypes.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let filterType = filterTypes[indexPath.section]
        switch filterType {
        case .date, .type:
            let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)

            let filterType = filterTypes[indexPath.section]
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.configure(with: filterType, filters: filters)

            return cell
        case .categories:
            let cell = tableView.dequeueReusableCell(type: ManageCategoriesTableViewCell.self, for: indexPath)

            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.configure(with: Array(filters.categories))

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let filterType = filterTypes[section]
        return HomeTitleView.instantiate(title: filterType.title)
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == tableView.numberOfSections - 1 {
            return UITableView.automaticDimension
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableView.numberOfSections - 1 {
            let footerView = FiltersFooterView.instantiate()
            footerView.delegate = self
            return footerView
        }
        return nil
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let filterType = filterTypes[indexPath.section]
        switch filterType {
        case .date:
            break
        case .type:
            break
        case .categories:
            let manageCategoriesViewController = ManageCategoriesViewController.instantiate(driveFileManager: driveFileManager)
            manageCategoriesViewController.canEdit = false
            manageCategoriesViewController.selectedCategories = Array(filters.categories)
            manageCategoriesViewController.delegate = self
            navigationController?.pushViewController(manageCategoriesViewController, animated: true)
        }
    }
}

// MARK: - Manage categories delegate

extension SearchFiltersViewController: ManageCategoriesDelegate {
    func didSelect(category: kDriveCore.Category) {
        filters.categories.insert(category)
        if let index = filterTypes.firstIndex(of: .categories) {
            tableView.reloadSections([index], with: .automatic)
        }
    }

    func didDeselect(category: kDriveCore.Category) {
        filters.categories.remove(category)
        if let index = filterTypes.firstIndex(of: .categories) {
            tableView.reloadSections([index], with: .automatic)
        }
    }
}

// MARK: - Footer delegate

extension SearchFiltersViewController: FiltersFooterDelegate {
    func clearButtonPressed() {
        filters.clearFilters()
        tableView.reloadData()
        delegate?.didUpdateFilters(filters)
    }

    func applyButtonPressed() {
        delegate?.didUpdateFilters(filters)
        dismiss(animated: true)
    }
}
