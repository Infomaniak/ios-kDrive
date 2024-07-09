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
import kDriveResources
import UIKit

@MainActor
protocol SearchFiltersDelegate: AnyObject {
    func didUpdateFilters(_ filters: Filters)
}

enum FilterType: CaseIterable {
    case date, type, categories

    var title: String {
        switch self {
        case .date:
            return KDriveResourcesStrings.Localizable.modificationDateFilterTitle
        case .type:
            return KDriveResourcesStrings.Localizable.fileTypeFilterTitle
        case .categories:
            return KDriveResourcesStrings.Localizable.categoriesFilterTitle
        }
    }
}

extension ConvertedType: Selectable {
    var image: UIImage? {
        return icon
    }
}

class SearchFiltersViewController: UITableViewController, UITextFieldDelegate {
    var driveFileManager: DriveFileManager!
    var filters = Filters()

    weak var delegate: SearchFiltersDelegate?

    private let filterTypes = FilterType.allCases

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hideBackButtonText()

        clearsSelectionOnViewWillAppear = false

        tableView.register(cellView: LocationTableViewCell.self)
        tableView.register(cellView: ManageCategoriesTableViewCell.self)
        tableView.register(cellView: SelectTableViewCell.self)
        tableView.register(cellView: TextInputTableViewCell.self)

        let index = filters.belongToAllCategories ? 1 : 2
        tableView.selectRow(at: IndexPath(row: index, section: 2), animated: false, scrollPosition: .none)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()
    }

    static func instantiate(driveFileManager: DriveFileManager) -> SearchFiltersViewController {
        let viewController = Storyboard.search
            .instantiateViewController(withIdentifier: "SearchFiltersViewController") as! SearchFiltersViewController
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    static func instantiateInNavigationController(driveFileManager: DriveFileManager) -> UINavigationController {
        let viewController = instantiate(driveFileManager: driveFileManager)
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    private func reloadSection(_ filterType: FilterType) {
        if let index = filterTypes.firstIndex(of: filterType) {
            let selectedIndexPath = tableView.indexPathForSelectedRow
            tableView.reloadSections([index], with: .none)
            if let selectedIndexPath {
                tableView.selectRow(at: selectedIndexPath, animated: false, scrollPosition: .none)
            }
        }
    }

    // MARK: - TextFieldDelegate

    @objc func textFieldDidChange(_ textField: UITextField) {
        filters.fileExtensionsRaw = textField.text
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        filters.fileExtensionsRaw = textField.text
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        filters.fileExtensionsRaw = nil
        return true
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        tableView.selectRow(at: inputCellPath, animated: true, scrollPosition: .none)
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        tableView.deselectRow(at: inputCellPath, animated: true)
        return true
    }

    private let inputCellPath = IndexPath(row: 1, section: 1)

    private func getTextInputCell() -> TextInputTableViewCell? {
        guard let inputCell = tableView(tableView, cellForRowAt: inputCellPath) as? TextInputTableViewCell else {
            return nil
        }

        return inputCell
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
        switch filterTypes[section] {
        case .categories:
            return 3
        case .type:
            // searchExtension has a second cell for input
            guard filters.fileType == .searchExtension else {
                return 1
            }
            return 2
        default:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let filterType = filterTypes[indexPath.section]
        switch filterType {
        case .date:
            let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)

            let filterType = filterTypes[indexPath.section]
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.configure(with: filterType, filters: filters)

            return cell
        case .type:
            guard indexPath.row != 0,
                  filters.fileType == .searchExtension else {
                let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)

                let filterType = filterTypes[indexPath.section]
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.configure(with: filterType, filters: filters)

                return cell
            }

            let cell = tableView.dequeueReusableCell(type: TextInputTableViewCell.self, for: indexPath)
            cell.textField.delegate = self
            cell.textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

            return cell

        case .categories:
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(type: ManageCategoriesTableViewCell.self, for: indexPath)

                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.configure(with: Array(filters.categories))

                return cell
            } else {
                let cell = tableView.dequeueReusableCell(type: SelectTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                switch indexPath.row {
                case 1:
                    cell.label.text = KDriveResourcesStrings.Localizable.belongToAllCategoriesFilterDescription
                case 2:
                    cell.label.text = KDriveResourcesStrings.Localizable.belongToOneCategoryFilterDescription
                default:
                    cell.label.text = ""
                }
                return cell
            }
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let filterType = filterTypes[section]
        return HomeTitleView.instantiate(title: filterType.title)
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

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let filterType = filterTypes[indexPath.section]
        switch filterType {
        case .date:
            MatomoUtils.track(eventWithCategory: .search, name: "filterDate")
            let customDateOption: DateOption
            if let option = filters.date, case .custom = option {
                customDateOption = option
            } else {
                customDateOption = .custom(DateInterval(start: Date(), duration: 0))
            }
            let allCases: [DateOption] = [.today, .yesterday, .last7days, customDateOption]
            let floatingPanelController = FloatingPanelSelectOptionViewController<DateOption>.instantiatePanel(
                options: allCases,
                selectedOption: filters.date,
                headerTitle: filterType.title,
                delegate: self
            )
            present(floatingPanelController, animated: true)
            return nil
        case .type:

            switch indexPath.row {
            case 0:
                MatomoUtils.track(eventWithCategory: .search, name: "filterFileType")
                var fileTypes = ConvertedType.allCases
                fileTypes.removeAll { $0 == .font || $0 == .unknown || $0 == .url }
                let floatingPanelController = FloatingPanelSelectOptionViewController<ConvertedType>.instantiatePanel(
                    options: fileTypes,
                    selectedOption: filters.fileType,
                    headerTitle: filterType.title,
                    delegate: self
                )
                present(floatingPanelController, animated: true)
                return nil
            default:
                return indexPath
            }

        case .categories:
            if indexPath.row == 0 {
                MatomoUtils.track(eventWithCategory: .search, name: "filterCategory")
                let manageCategoriesViewController = ManageCategoriesViewController
                    .instantiate(driveFileManager: driveFileManager)
                manageCategoriesViewController.canEdit = false
                manageCategoriesViewController.selectedCategories = Array(filters.categories)
                manageCategoriesViewController.delegate = self
                navigationController?.pushViewController(manageCategoriesViewController, animated: true)
                return nil
            } else {
                return indexPath
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let filterType = filterTypes[indexPath.section]
        switch filterType {
        case .date:
            break
        case .type:
            switch indexPath.row {
            case 0:
                break
            default:
                // TODO: Matomo?
                if let inputCell = getTextInputCell() {
                    inputCell.setSelected(true, animated: true)
                }
                return
            }
        case .categories:
            if indexPath.row > 0 {
                filters.belongToAllCategories = indexPath.row == 1
            }
        }
    }
}

// MARK: - Select delegate

extension SearchFiltersViewController: SelectDelegate {
    func didSelect(option: Selectable) {
        if let dateOption = option as? DateOption {
            if case .custom = dateOption {
                let startDate = Calendar.current.date(from: DateComponents(year: 2000, month: 01, day: 01))!
                let endDate = Date()
                let floatingPanelController = DateRangePickerViewController
                    .instantiatePanel(visibleDateRange: startDate ... endDate) { [weak self] dateInterval in
                        self?.filters.date = .custom(dateInterval)
                        self?.reloadSection(.date)
                    }
                present(floatingPanelController, animated: true)
            } else {
                filters.date = dateOption
                reloadSection(.date)
            }
        } else if let fileType = option as? ConvertedType {
            filters.fileType = fileType
            reloadSection(.type)

            if fileType == .searchExtension {
                tableView.selectRow(at: inputCellPath, animated: true, scrollPosition: .none)
            }
        }
    }
}

// MARK: - Manage categories delegate

extension SearchFiltersViewController: ManageCategoriesDelegate {
    func didSelect(category: kDriveCore.Category) {
        filters.categories.insert(category)
        reloadSection(.categories)
    }

    func didDeselect(category: kDriveCore.Category) {
        filters.categories.remove(category)
        reloadSection(.categories)
    }
}

// MARK: - Footer delegate

extension SearchFiltersViewController: FiltersFooterDelegate {
    func clearButtonPressed() {
        filters.clearFilters()
        let selectedIndexPath = tableView.indexPathForSelectedRow
        tableView.reloadData()
        if let selectedIndexPath {
            tableView.selectRow(at: selectedIndexPath, animated: false, scrollPosition: .none)
        }
        delegate?.didUpdateFilters(filters)
    }

    func applyButtonPressed() {
        delegate?.didUpdateFilters(filters)
        dismiss(animated: true)
    }
}
