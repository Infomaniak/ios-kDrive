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

class SearchFiltersViewController: UITableViewController {
    @LazyInjectService private var matomo: MatomoUtils

    var driveFileManager: DriveFileManager!
    var filters = Filters()

    weak var delegate: SearchFiltersDelegate?

    private let filterTypes = FilterType.allCases

    private let inputCellPath = IndexPath(row: 1, section: 1)

    private enum Section: CaseIterable {
        case date
        case type
        case categoryManagement
        case categoryBelongAll
        case categoryBelongOne

        var filterType: FilterType {
            switch self {
            case .date:
                return .date
            case .type:
                return .type
            default:
                return .categories
            }
        }

        var headerTitle: String? {
            switch self {
            case .date:
                return FilterType.date.title
            case .type:
                return FilterType.type.title
            case .categoryManagement:
                return FilterType.categories.title
            case .categoryBelongAll, .categoryBelongOne:
                return nil
            }
        }
    }

    private let sections = Section.allCases

    private enum SearchFiltersRowsInSection {
        static let type = 2
        static let typeSearchExtension = 1
        static let date = 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hideBackButtonText()

        clearsSelectionOnViewWillAppear = false

        tableView.register(cellView: LocationTableViewCell.self)
        tableView.register(cellView: ManageCategoriesTableViewCell.self)
        tableView.register(cellView: SelectTableViewCell.self)
        tableView.register(
            FileExtensionTextInputTableViewCell.self,
            forCellReuseIdentifier: "FileExtensionTextInputTableViewCell"
        )

        let categorySection = filters.belongToAllCategories ? 3 : 4
        tableView.selectRow(at: IndexPath(row: 0, section: categorySection), animated: false, scrollPosition: .none)
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

    // MARK: - Actions

    @IBAction func closeButtonPressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .categoryManagement, .categoryBelongAll, .categoryBelongOne:
            return 1
        case .type:
            // searchExtension has a second cell for input
            guard filters.fileType == .searchExtension else {
                return SearchFiltersRowsInSection.typeSearchExtension
            }
            return SearchFiltersRowsInSection.type
        case .date:
            return SearchFiltersRowsInSection.date
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .date:
            let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)

            let filterType = filterTypes[indexPath.section]
            cell.configure(with: filterType, filters: filters)

            return cell

        case .type:
            guard indexPath.row != 0,
                  filters.fileType == .searchExtension else {
                let cell = tableView.dequeueReusableCell(type: LocationTableViewCell.self, for: indexPath)

                let filterType = filterTypes[indexPath.section]
                cell.configure(with: filterType, filters: filters)

                return cell
            }

            let cell = tableView.dequeueReusableCell(type: FileExtensionTextInputTableViewCell.self, for: indexPath)
            cell.textField.text = filters.fileExtensionsRaw
            cell.textField.delegate = self
            cell.textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

            return cell

        case .categoryManagement:
            let cell = tableView.dequeueReusableCell(type: ManageCategoriesTableViewCell.self, for: indexPath)
            cell.configure(with: Array(filters.categories))
            return cell

        case .categoryBelongAll:
            let cell = tableView.dequeueReusableCell(type: SelectTableViewCell.self, for: indexPath)
            cell.label.text = KDriveResourcesStrings.Localizable.belongToAllCategoriesFilterDescription
            return cell

        case .categoryBelongOne:
            let cell = tableView.dequeueReusableCell(type: SelectTableViewCell.self, for: indexPath)
            cell.label.text = KDriveResourcesStrings.Localizable.belongToOneCategoryFilterDescription
            return cell
        }
    }

    override func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if sections[section].headerTitle == nil {
            return .zero
        }
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = sections[section].headerTitle else { return nil }
        return HomeTitleView.instantiate(
            title: title,
            insets: NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0)
        )
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
        switch sections[indexPath.section] {
        case .date:
            matomo.track(eventWithCategory: .search, name: "filterDate")
            let customDateOption: DateOption
            if let option = filters.date, case .custom = option {
                customDateOption = option
            } else {
                customDateOption = .custom(DateInterval(start: Date(), duration: 0))
            }
            let allCases: [DateOption] = [.today, .yesterday, .last7days, customDateOption]
            let sheetViewController = FloatingPanelSelectOptionViewController<DateOption>.instantiateSheet(
                options: allCases,
                selectedOption: filters.date,
                headerTitle: FilterType.date.title,
                delegate: self
            )
            present(sheetViewController, animated: true)
            return nil

        case .type:
            if indexPath.row == 0 {
                matomo.track(eventWithCategory: .search, name: "filterFileType")
                var fileTypes = ConvertedType.allCases
                fileTypes.removeAll { $0 == .font || $0 == .unknown || $0 == .url || $0 == .form }
                let sheetViewController = FloatingPanelSelectOptionViewController<ConvertedType>.instantiateSheet(
                    options: fileTypes,
                    selectedOption: filters.fileType,
                    headerTitle: FilterType.type.title,
                    delegate: self
                )
                present(sheetViewController, animated: true)
                return nil
            } else {
                return indexPath
            }

        case .categoryManagement:
            matomo.track(eventWithCategory: .search, name: "filterCategory")
            let manageCategoriesViewController = ManageCategoriesViewController
                .instantiate(driveFileManager: driveFileManager)
            manageCategoriesViewController.canEdit = false
            manageCategoriesViewController.selectedCategories = Array(filters.categories)
            manageCategoriesViewController.delegate = self
            navigationController?.pushViewController(manageCategoriesViewController, animated: true)
            return nil

        case .categoryBelongAll, .categoryBelongOne:
            return indexPath
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .date:
            break
        case .type:
            if indexPath.row != 0 {
                matomo.track(eventWithCategory: .search, name: "filterExtension")
                if let inputCell = getTextInputCell() {
                    inputCell.setSelected(true, animated: true)
                }
                return
            }
        case .categoryManagement:
            break
        case .categoryBelongAll:
            filters.belongToAllCategories = true
        case .categoryBelongOne:
            filters.belongToAllCategories = false
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

// MARK: - TextFieldDelegate

extension SearchFiltersViewController: UITextFieldDelegate {
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

    private func getTextInputCell() -> FileExtensionTextInputTableViewCell? {
        guard let inputCell = tableView(tableView, cellForRowAt: inputCellPath) as? FileExtensionTextInputTableViewCell else {
            return nil
        }

        return inputCell
    }
}
