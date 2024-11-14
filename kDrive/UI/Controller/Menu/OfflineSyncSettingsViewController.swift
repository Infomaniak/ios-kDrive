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

class OfflineSyncSettingsViewController: BaseGroupedTableViewController {
    private var tableContent: [SyncMode] = SyncMode.allCases
    private var selectedOfflineMod: SyncMode!

    weak var delegate: SelectPhotoFormatDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: ParameterSyncTableViewCell.self)
        selectedOfflineMod = UserDefaults.shared.syncOfflineMod
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName, "selectOfflineMod"])
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableContent.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: ParameterSyncTableViewCell.self, for: indexPath)
        cell.initWithPositionAndShadow(isFirst: true, isLast: true)
        let currentMod = tableContent[indexPath.row]
        cell.syncTitleLabel.text = currentMod.title
        cell.syncDetailLabel.text = currentMod.selectionTitle
        if currentMod == selectedOfflineMod {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mod = tableContent[indexPath.row]
        MatomoUtils.track(eventWithCategory: .settings, name: "mod\(mod.rawValue.capitalized)")
        UserDefaults.shared.syncOfflineMod = mod
        if mod == .onlyWifi {
            UserDefaults.shared.isWifiOnly = true
        } else {
            UserDefaults.shared.isWifiOnly = false
        }
        navigationController?.popViewController(animated: true)
    }
}
