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

import kDriveResources
import UIKit
import kDriveCore

class AboutTableViewController: UITableViewController {
    private enum AboutRow: CaseIterable {
        case privacy, sourceCode, license, version

        var url: URL? {
            switch self {
            case .privacy:
                return URLConstants.rgpd.url
            case .sourceCode:
                return URLConstants.sourceCode.url
            case .license:
                return URLConstants.gpl.url
            default:
                return nil
            }
        }
    }

    private let rows = AboutRow.allCases
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    private let maxCount = 10

    private var counter = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: ParameterAboutTableViewCell.self)
        tableView.register(cellView: AboutDetailTableViewCell.self)
        navigationController?.navigationBar.sizeToFit()

        navigationItem.hideBackButtonText()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName, "About"])
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let isFirst = indexPath.row == 0
        let isLast = indexPath.row == rows.count - 1
        switch rows[indexPath.row] {
        case .privacy:
            let cell = tableView.dequeueReusableCell(type: ParameterAboutTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: isFirst, isLast: isLast)
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.aboutPrivacyTitle
            return cell
        case .sourceCode:
            let cell = tableView.dequeueReusableCell(type: ParameterAboutTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: isFirst, isLast: isLast)
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.aboutSourceCodeTitle
            return cell
        case .license:
            let cell = tableView.dequeueReusableCell(type: AboutDetailTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: isFirst, isLast: isLast)
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.aboutLicenseTitle
            cell.detailLabel.text = KDriveResourcesStrings.Localizable.aboutLicenseDescription
            return cell
        case .version:
            let cell = tableView.dequeueReusableCell(type: AboutDetailTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: isFirst, isLast: isLast)
            cell.accessoryImageView.isHidden = true
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.aboutAppVersionTitle
            cell.detailLabel.text = "v\(appVersion ?? "1.0.0")" + (counter == maxCount ? " (\(buildNumber ?? "--"))" : "")
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        switch row {
        case .privacy, .sourceCode, .license:
            if let url = row.url {
                UIApplication.shared.open(url)
            }
        case .version:
            if counter < maxCount {
                counter += 1
                if counter == maxCount {
                    tableView.reloadRows(at: [indexPath], with: .fade)
                }
            }
        }
    }
}
