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

import InfomaniakCoreUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class WifiSyncSettingsViewController: BaseGroupedTableViewController {
    @LazyInjectService private var appNavigable: AppNavigable

    private var tableContent: [SyncMod] = SyncMod.allCases
    private var selectedMod: SyncMod!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = KDriveResourcesStrings.Localizable.themeSettingsTitle

        tableView.register(cellView: SelectionTableViewCell.self)
        tableView.allowsMultipleSelection = false

//        selectedMod = UserDefaults.shared.syncMod
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName, "SelectSyncMode"])
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableContent.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: SelectionTableViewCell.self, for: indexPath)
        let currentMod = tableContent[indexPath.row]
        if currentMod == selectedMod {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
        cell.label.text = currentMod.selectionTitle
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mod = tableContent[indexPath.row]
        MatomoUtils.track(eventWithCategory: .settings, name: "mod\(mod.rawValue.capitalized)")
        UserDefaults.shared.syncMod = mod
        navigationController?.popViewController(animated: true)
    }
}
