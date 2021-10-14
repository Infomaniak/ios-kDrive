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
import UIKit

protocol Selectable {
    var title: String { get }
}

protocol IconSelectable: Selectable {
    var icon: UIImage { get }
}

protocol SelectDelegate: AnyObject {
    func didSelect(option: Selectable)
}

class FloatingPanelSelectOptionViewController<T: Selectable & Equatable>: UITableViewController, FloatingPanelControllerDelegate {
    var headerTitle = ""
    var selectedOption: T?
    var options = [T]()

    weak var delegate: SelectDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: FloatingPanelSortOptionTableViewCell.self)
        tableView.separatorColor = .clear
        tableView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let selectedOption = selectedOption,
           let selectedIndex = options.firstIndex(of: selectedOption) {
            tableView.selectRow(at: IndexPath(row: selectedIndex + 1, section: 0), animated: false, scrollPosition: .none)
        }
    }

    static func instantiatePanel(options: [T], selectedOption: T? = nil, headerTitle: String, delegate: SelectDelegate? = nil) -> DriveFloatingPanelController {
        let floatingPanelViewController = DriveFloatingPanelController()
        let viewController = FloatingPanelSelectOptionViewController<T>()

        viewController.headerTitle = headerTitle
        viewController.options = options
        viewController.selectedOption = selectedOption
        viewController.delegate = delegate

        floatingPanelViewController.isRemovalInteractionEnabled = true
        floatingPanelViewController.delegate = viewController

        floatingPanelViewController.set(contentViewController: viewController)
        floatingPanelViewController.track(scrollView: viewController.tableView)
        return floatingPanelViewController
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: FloatingPanelSortOptionTableViewCell.self, for: indexPath)
        if indexPath.row == 0 {
            cell.titleLabel.text = headerTitle
            cell.isHeader = true
        } else {
            let option = options[indexPath.row - 1]
            cell.titleLabel.text = option.title
            cell.isHeader = false
            if let option = option as? IconSelectable {
                cell.iconImageView.image = option.icon
                cell.iconImageView.isHidden = false
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.row == 0 {
            return nil
        }
        return indexPath
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dismiss(animated: true)
        delegate?.didSelect(option: options[indexPath.row - 1])
    }

    func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout {
        return PlusButtonFloatingPanelLayout(height: min(58 * CGFloat(options.count + 1) + 20, UIScreen.main.bounds.size.height - 48))
    }
}
