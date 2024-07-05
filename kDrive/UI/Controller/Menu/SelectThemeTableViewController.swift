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

class SelectThemeTableViewController: GenericGroupedTableViewController {
    @LazyInjectService private var appNavigable: AppNavigable

    private var tableContent: [Theme] = Theme.allCases
    private var selectedTheme: Theme!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = KDriveResourcesStrings.Localizable.themeSettingsTitle

        tableView.register(cellView: SelectionTableViewCell.self)
        tableView.allowsMultipleSelection = false

        selectedTheme = UserDefaults.shared.theme
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName, "SelectTheme"])
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableContent.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: SelectionTableViewCell.self, for: indexPath)
        let currentTheme = tableContent[indexPath.row]
        if currentTheme == selectedTheme {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
        cell.label.text = currentTheme.selectionTitle
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let theme = tableContent[indexPath.row]
        MatomoUtils.track(eventWithCategory: .settings, name: "theme\(theme.rawValue.capitalized)")
        UserDefaults.shared.theme = theme
        appNavigable.updateTheme()
        navigationController?.popViewController(animated: true)
    }
}
