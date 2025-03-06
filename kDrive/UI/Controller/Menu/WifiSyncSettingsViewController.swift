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

import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

protocol WifiSyncSettingsDelegate: AnyObject {
    func didSelectSyncMode(_ mode: SyncMode)
}

class WifiSyncSettingsViewController: BaseGroupedTableViewController {
    @LazyInjectService private var appNavigable: AppNavigable
    @LazyInjectService private var downloadQueue: DownloadQueueable

    private var tableContent: [SyncMode] = SyncMode.allCases
    private var selectedMode: SyncMode
    private var offlineSync: Bool
    weak var delegate: WifiSyncSettingsDelegate?

    init(selectedMode: SyncMode, offlineSync: Bool = false) {
        self.selectedMode = selectedMode
        self.offlineSync = offlineSync
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = KDriveResourcesStrings.Localizable.syncWifiSettingsTitle

        tableView.register(cellView: ParameterSyncTableViewCell.self)
        tableView.allowsMultipleSelection = false
    }

    static func instantiate(selectedMode: SyncMode) -> WifiSyncSettingsViewController {
        let viewController = WifiSyncSettingsViewController(selectedMode: selectedMode)
        return viewController
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
        let cell = tableView.dequeueReusableCell(type: ParameterSyncTableViewCell.self, for: indexPath)
        cell.initWithPositionAndShadow(isFirst: true, isLast: true)
        let currentMode = tableContent[indexPath.row]
        cell.syncTitleLabel.text = currentMode.title
        cell.syncDetailLabel.text = currentMode.selectionTitle
        if currentMode == selectedMode {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mode = tableContent[indexPath.row]
        MatomoUtils.track(eventWithCategory: .settings, name: "mod\(mode.rawValue.capitalized)")
        if !offlineSync {
            delegate?.didSelectSyncMode(mode)
        } else {
            UserDefaults.shared.syncOfflineMode = mode
        }

        downloadQueue.updateQueueSuspension()

        navigationController?.popViewController(animated: true)
    }
}
