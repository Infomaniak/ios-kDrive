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

import StoreKit
import UIKit

class StoreViewController: UITableViewController {
    private enum Section: CaseIterable {
        case availableProducts, invalidProducts, purchased, restored

        var title: String {
            switch self {
            case .availableProducts:
                return "Available Products"
            case .invalidProducts:
                return "Invalid Products"
            case .purchased:
                return "Purchased"
            case .restored:
                return "Restored"
            }
        }
    }

    private let cellIdentifier = "cell"

    private var sections = Section.allCases
    private var availableProducts: [SKProduct] = []
    private var invalidProductIdentifiers: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.backgroundColor = KDriveAsset.backgroundColor.color

        title = "Store"

        StoreManager.shared.delegate = self
        StoreObserver.shared.delegate = self

        // Fetch product information
        fetchProductInformation()
    }

    private func fetchProductInformation() {
        guard StoreObserver.shared.isAuthorizedForPayments else {
            // Warn the user that they are not allowed to make purchases
            UIConstants.showSnackBar(message: "In-App Purchases are not allowed.")
            return
        }

        let resourceFile = ProductIdentifiers()
        guard let identifiers = resourceFile.identifiers else {
            // Warn the user that the resource file could not be found.
            UIConstants.showSnackBar(message: resourceFile.wasNotFound)
            return
        }

        if !identifiers.isEmpty {
            invalidProductIdentifiers = identifiers
            reload()

            // Fetch product information
            StoreManager.shared.startProductRequest(with: identifiers)
        } else {
            // Warn the user that the resource file does not contain anything
            UIConstants.showSnackBar(message: resourceFile.isEmpty)
        }
    }

    private func reload() {
        var sections = [Section]()
        if !availableProducts.isEmpty {
            sections.append(.availableProducts)
        }
        if !invalidProductIdentifiers.isEmpty {
            sections.append(.invalidProducts)
        }
        if !StoreObserver.shared.purchased.isEmpty {
            sections.append(.purchased)
        }
        if !StoreObserver.shared.restored.isEmpty {
            sections.append(.restored)
        }
        self.sections = sections
        tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .availableProducts:
            return availableProducts.count
        case .invalidProducts:
            return invalidProductIdentifiers.count
        case .purchased:
            return StoreObserver.shared.purchased.count
        case .restored:
            return StoreObserver.shared.restored.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)

        switch sections[indexPath.section] {
        case .availableProducts:
            let product = availableProducts[indexPath.row]
            cell.textLabel?.text = product.localizedTitle
            if let formattedPrice = product.regularPrice {
                cell.detailTextLabel?.text = formattedPrice
            }
        case .invalidProducts:
            cell.textLabel?.text = invalidProductIdentifiers[indexPath.row]
        case .purchased:
            let transaction = StoreObserver.shared.purchased[indexPath.row]
            cell.textLabel?.text = StoreManager.shared.title(matchingPaymentTransaction: transaction)
        case .restored:
            let transaction = StoreObserver.shared.restored[indexPath.row]
            cell.textLabel?.text = StoreManager.shared.title(matchingPaymentTransaction: transaction)
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = sections[indexPath.section]

        // Only available products can be bought
        if section == .availableProducts {
            let product = availableProducts[indexPath.row]

            // Attempt to purchase the tapped product
            StoreObserver.shared.buy(product)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Store manager delegate

extension StoreViewController: StoreManagerDelegate {
    func storeManagerDidReceiveResponse(_ response: StoreResponse) {
        availableProducts = response.availableProducts
        invalidProductIdentifiers = response.invalidProductIdentifiers
        reload()
    }

    func storeManagerDidReceiveMessage(_ message: String) {
        UIConstants.showSnackBar(message: message)
    }
}

// MARK: - Store observer delegate

extension StoreViewController: StoreObserverDelegate {
    func storeObserverRestoreDidSucceed() {
        // TODO: Do something
    }

    func storeObserverDidReceiveMessage(_ message: String) {
        UIConstants.showSnackBar(message: message)
    }
}
