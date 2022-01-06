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
import kDriveCore
import kDriveResources
import UIKit

protocol Selectable {
    var title: String { get }
    var image: UIImage? { get }
    var tintColor: UIColor? { get }
}

extension Selectable {
    var image: UIImage? { return nil }
    var tintColor: UIColor? { return nil }
}

protocol SelectDelegate: AnyObject {
    func didSelect(option: Selectable)
}

class TableFloatingPanelViewController: UITableViewController {
    weak var floatingPanelController: FloatingPanelController?

    private var contentSizeObservation: NSKeyValueObservation?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        contentSizeObservation = tableView.observe(\.contentSize) { [weak self] _, _ in
            self?.updateLayout(size: UIScreen.main.bounds.size)
        }
    }

    deinit {
        contentSizeObservation?.invalidate()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateLayout(size: size)
    }

    func updateLayout(size: CGSize) {
        floatingPanelController?.layout = PlusButtonFloatingPanelLayout(height: min(tableView.contentSize.height + view.safeAreaInsets.bottom, size.height - 48))
        floatingPanelController?.invalidateLayout()
    }
}

class FloatingPanelSelectOptionViewController<T: Selectable & Equatable>: TableFloatingPanelViewController {
    var headerTitle = ""
    var selectedOption: T?
    var options = [T]()

    weak var delegate: SelectDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: FloatingPanelSortOptionTableViewCell.self)
        tableView.separatorColor = .clear
        tableView.alwaysBounceVertical = false
        tableView.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
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
        viewController.floatingPanelController = floatingPanelViewController

        floatingPanelViewController.isRemovalInteractionEnabled = true

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
            cell.iconImageView.image = option.image
            cell.iconImageView.tintColor = option.tintColor
            cell.iconImageView.isHidden = option.image == nil
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
}
