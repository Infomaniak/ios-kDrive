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
import StoreKit
import UIKit

class StoreViewController: UITableViewController {
    struct Item {
        let pack: DrivePack
        let identifier: String
        let period: PeriodTab
        var product: SKProduct?

        static let allItems = [
            Item(pack: .solo, identifier: "com.infomaniak.drive.iap.solo", period: .monthly),
            Item(pack: .team, identifier: "com.infomaniak.drive.iap.team", period: .monthly),
            Item(pack: .pro, identifier: "com.infomaniak.drive.iap.pro", period: .monthly),
            Item(pack: .solo, identifier: "com.infomaniak.drive.iap.solo.yearly", period: .yearly),
            Item(pack: .team, identifier: "com.infomaniak.drive.iap.team.yearly", period: .yearly),
            Item(pack: .pro, identifier: "com.infomaniak.drive.iap.pro.yearly", period: .yearly)
        ]
    }

    enum PeriodTab: Int, CaseIterable {
        case monthly, yearly

        var title: String {
            switch self {
            case .monthly:
                return "Mensuel"
            case .yearly:
                return "Annuel"
            }
        }
    }

    private enum Row: CaseIterable {
        case segmentedControl, offers, storage, nextButton
    }

    private var rows: [Row] = [.segmentedControl, .offers]

    var driveFileManager: DriveFileManager!

    private var items = Item.allItems
    private lazy var selectedPack = driveFileManager.drive.pack
    private var selectedStorage = 1
    private var selectedPeriod = PeriodTab.monthly {
        didSet { updateOffers() }
    }

    private var displayedItems: [Item] {
        return items.filter { $0.period == selectedPeriod }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up table view
        tableView.register(cellView: StoreControlTableViewCell.self)
        tableView.register(cellView: StoreOffersTableViewCell.self)
        tableView.register(cellView: StoreStorageTableViewCell.self)
        tableView.register(cellView: StoreNextTableViewCell.self)

        // Set up delegates
        StoreManager.shared.delegate = self
        StoreObserver.shared.delegate = self

        if presentingViewController != nil {
            // Show cancel button
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
        }

        // Fetch product information
        fetchProductInformation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()
    }

    @objc func closeButtonPressed() {
        dismiss(animated: true)
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
            // Fetch product information
            StoreManager.shared.startProductRequest(with: identifiers)
        } else {
            // Warn the user that the resource file does not contain anything
            UIConstants.showSnackBar(message: resourceFile.isEmpty)
        }
    }

    private func updateOffers() {
        if let index = rows.firstIndex(of: .offers) {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
    }

    private func showSuccessView() {
        let successViewController = StoreSuccessViewController.instantiate()
        successViewController.modalPresentationStyle = .fullScreen
        present(successViewController, animated: true)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return driveFileManager == nil ? 1 : rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .segmentedControl:
            let cell = tableView.dequeueReusableCell(type: StoreControlTableViewCell.self, for: indexPath)
            cell.segmentedControl.setSegments(PeriodTab.allCases.map(\.title))
            cell.onChange = { [weak self] index in
                if let period = PeriodTab(rawValue: index) {
                    self?.selectedPeriod = period
                }
            }
            return cell
        case .offers:
            let cell = tableView.dequeueReusableCell(type: StoreOffersTableViewCell.self, for: indexPath)
            cell.selectedPack = selectedPack
            cell.items = displayedItems
            cell.cellDelegate = self
            cell.collectionView.reloadData()
            DispatchQueue.main.async {
                // Scroll to current pack
                if let index = self.items.firstIndex(where: { $0.pack == self.selectedPack }) {
                    cell.collectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .centeredHorizontally, animated: false)
                }
            }
            return cell
        case .storage:
            let cell = tableView.dequeueReusableCell(type: StoreStorageTableViewCell.self, for: indexPath)
            cell.delegate = self
            return cell
        case .nextButton:
            let cell = tableView.dequeueReusableCell(type: StoreNextTableViewCell.self, for: indexPath)
            cell.delegate = self
            return cell
        }
    }

    static func instantiate(driveFileManager: DriveFileManager) -> StoreViewController {
        let viewController = Storyboard.menu.instantiateViewController(withIdentifier: "StoreViewController") as! StoreViewController
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        guard let driveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
        updateOffers()
    }
}

// MARK: - Cell delegates

extension StoreViewController: StoreCellDelegate, StoreStorageDelegate, StoreNextCellDelegate {
    func selectButtonTapped(item: StoreViewController.Item) {
        if item.pack == .team {
            rows = [.segmentedControl, .offers, .storage, .nextButton]
        } else {
            rows = [.segmentedControl, .offers, .nextButton]
        }
        selectedPack = item.pack
        tableView.reloadData()
        tableView.scrollToRow(at: IndexPath(row: rows.count - 1, section: 0), at: .bottom, animated: true)
    }

    func storageDidChange(_ newValue: Int) {
        selectedStorage = newValue
    }

    func nextButtonTapped() {
        if let product = displayedItems.first(where: { $0.pack == selectedPack })?.product {
            // Attempt to purchase the tapped product
            StoreObserver.shared.buy(product, userId: AccountManager.instance.currentUserId, driveId: driveFileManager.drive.id)
        }
    }
}

// MARK: - Store manager delegate

extension StoreViewController: StoreManagerDelegate {
    func storeManagerDidReceiveResponse(_ response: StoreResponse) {
        // Update items product
        for i in 0 ..< items.count {
            items[i].product = response.availableProducts.first { $0.productIdentifier == items[i].identifier }
        }
        updateOffers()
    }

    func storeManagerDidReceiveMessage(_ message: String) {
        UIConstants.showSnackBar(message: message)
    }
}

// MARK: - Store observer delegate

extension StoreViewController: StoreObserverDelegate {
    func storeObserverPurchaseDidSucceed(transaction: SKPaymentTransaction, receiptString: String) {
        // Send receipt to the server
        let body = ReceiptInfo(latestReceipt: receiptString,
                               userId: AccountManager.instance.currentUserId,
                               itemId: driveFileManager.drive.id,
                               productId: transaction.payment.productIdentifier,
                               transactionId: transaction.transactionIdentifier ?? "",
                               bundleId: Bundle.main.bundleIdentifier ?? "")
        StoreRequest.shared.sendReceipt(body: body)
        // Show success view controller
        showSuccessView()
    }

    func storeObserverRestoreDidSucceed() {
        // TODO: Do something
    }

    func storeObserverDidReceiveMessage(_ message: String) {
        UIConstants.showSnackBar(message: message)
    }
}
