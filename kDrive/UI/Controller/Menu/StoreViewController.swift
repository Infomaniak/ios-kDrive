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

class StoreViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var helpButton: IKRoundButton!

    struct Item {
        let pack: DrivePack
        let identifier: String
        let period: PeriodTab
        var product: SKProduct?

        static let allItems = [
            Item(pack: .solo, identifier: "com.infomaniak.drive.iap.solo.monthly", period: .monthly),
            Item(pack: .team, identifier: "com.infomaniak.drive.iap.team.monthly", period: .monthly),
            // Item(pack: .pro, identifier: "com.infomaniak.drive.iap.pro", period: .monthly),
            Item(pack: .solo, identifier: "com.infomaniak.drive.iap.solo.yearly", period: .yearly),
            Item(pack: .team, identifier: "com.infomaniak.drive.iap.team.yearly", period: .yearly)
            // Item(pack: .pro, identifier: "com.infomaniak.drive.iap.pro.yearly", period: .yearly)
        ]
    }

    enum PeriodTab: Int, CaseIterable {
        case monthly, yearly

        var title: String {
            switch self {
            case .monthly:
                return KDriveStrings.Localizable.storeMonthly
            case .yearly:
                return KDriveStrings.Localizable.storeYearly
            }
        }
    }

    private enum Row: CaseIterable {
        case segmentedControl, warning, offers, storage, nextButton
    }

    private var rows: [Row] = [.segmentedControl, .offers]

    var driveFileManager: DriveFileManager!

    private var purchaseEnabled = true
    private var items = Item.allItems
    private lazy var selectedPack = driveFileManager.drive.pack
    private var selectedStorage = 1
    private var selectedPeriod = PeriodTab.yearly {
        didSet { updateOffers() }
    }

    private var displayedItems: [Item] {
        return items.filter { $0.period == selectedPeriod }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up table view
        tableView.register(cellView: StoreControlTableViewCell.self)
        tableView.register(cellView: AlertTableViewCell.self)
        tableView.register(cellView: StoreOffersTableViewCell.self)
        tableView.register(cellView: StoreStorageTableViewCell.self)
        tableView.register(cellView: StoreNextTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 92, right: 0)

        // Set up delegates
        StoreManager.shared.delegate = self
        StoreObserver.shared.delegate = self

        let viewControllersCount = navigationController?.viewControllers.count ?? 0
        if presentingViewController != nil && viewControllersCount < 2 {
            // Show cancel button
            let closeButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
            closeButton.accessibilityLabel = KDriveStrings.Localizable.buttonClose
            navigationItem.leftBarButtonItem = closeButton
        }

        if #available(iOS 14.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: KDriveStrings.Localizable.buttonRedeemPromoCode, style: .plain, target: self, action: #selector(redeemButtonPressed))
        }

        checkDriveFileManager()

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

    @IBAction func helpButtonPressed(_ sender: Any) {
        guard let url = URL(string: "https://faq.infomaniak.com/2631") else { return }
        UIApplication.shared.open(url)
    }

    @available(iOS 14.0, *)
    @objc func redeemButtonPressed() {
        SKPaymentQueue.default().presentCodeRedemptionSheet()
    }

    private func fetchProductInformation() {
        guard StoreObserver.shared.isAuthorizedForPayments else {
            // Warn the user that they are not allowed to make purchases
            UIConstants.showSnackBar(message: KDriveStrings.Localizable.storePaymentNotAuthorized)
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

    private func checkDriveFileManager() {
        guard driveFileManager != nil else { return }

        if !driveFileManager.drive.accountAdmin {
            showBlockingMessage(existingIAP: false)
            purchaseEnabled = false
        } else if !driveFileManager.drive.productIsInApp && StoreObserver.shared.getReceipt() != nil {
            // If we already have a receipt but the product isn't an IAP, prevent user to make a new one
            showBlockingMessage(existingIAP: true)
            purchaseEnabled = false
        } else if !driveFileManager.drive.productIsInApp && driveFileManager.drive.pack != .free {
            // Show a warning message to inform that they have a different subscription method
            rows.insert(.warning, at: 1)
            purchaseEnabled = false
        }
    }

    private func updateOffers() {
        if let index = rows.firstIndex(of: .offers) {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
    }

    private func showBlockingMessage(existingIAP: Bool) {
        let title = existingIAP ? KDriveStrings.Localizable.storeExistingIAPTitle : KDriveStrings.Localizable.storeAccessDeniedTitle
        let message = existingIAP ? KDriveStrings.Localizable.storeExistingIAPDescription : KDriveStrings.Localizable.storeAccessDeniedDescription
        let alert = AlertTextViewController(title: title, message: message, action: KDriveStrings.Localizable.buttonClose, hasCancelButton: false) {
            let viewControllersCount = self.navigationController?.viewControllers.count ?? 0
            if self.presentingViewController != nil && viewControllersCount < 2 {
                self.dismiss(animated: true)
            } else {
                self.navigationController?.popViewController(animated: true)
            }
        }
        present(alert, animated: true)
    }

    private func setNextButtonLoading(_ loading: Bool) {
        if let index = rows.firstIndex(of: .nextButton),
           let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? StoreNextTableViewCell {
            cell.button.setLoading(loading)
        }
    }

    private func showSuccessView() {
        let successViewController = StoreSuccessViewController.instantiate()
        successViewController.modalPresentationStyle = .fullScreen
        present(successViewController, animated: true)
    }

    // MARK: - Table view data source

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return driveFileManager == nil ? 1 : rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .segmentedControl:
            let cell = tableView.dequeueReusableCell(type: StoreControlTableViewCell.self, for: indexPath)
            let selectedSegmentIndex = PeriodTab.allCases.firstIndex(of: selectedPeriod) ?? 0
            cell.segmentedControl.setSegments(PeriodTab.allCases.map(\.title), selectedSegmentIndex: selectedSegmentIndex)
            cell.onChange = { [weak self] index in
                if let period = PeriodTab(rawValue: index) {
                    self?.selectedPeriod = period
                }
            }
            return cell
        case .warning:
            let cell = tableView.dequeueReusableCell(type: AlertTableViewCell.self, for: indexPath)
            cell.configure(with: .warning, message: KDriveStrings.Localizable.storeBillingWarningDescription)
            return cell
        case .offers:
            let cell = tableView.dequeueReusableCell(type: StoreOffersTableViewCell.self, for: indexPath)
            cell.purchaseEnabled = purchaseEnabled
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

    static func instantiateInNavigationController(driveFileManager: DriveFileManager) -> UINavigationController {
        let viewController = instantiate(driveFileManager: driveFileManager)
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
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
        checkDriveFileManager()
        updateOffers()
    }
}

// MARK: - Cell delegates

extension StoreViewController: StoreCellDelegate, StoreStorageDelegate, StoreNextCellDelegate {
    func selectButtonTapped(item: StoreViewController.Item) {
        guard selectedPack != item.pack else { return }
        if !rows.contains(.nextButton) {
            rows.append(.nextButton)
        }
        selectedPack = item.pack
        tableView.reloadData()
        tableView.scrollToRow(at: IndexPath(row: rows.count - 1, section: 0), at: .bottom, animated: true)
    }

    func storageDidChange(_ newValue: Int) {
        selectedStorage = newValue
    }

    func nextButtonTapped(_ button: IKLargeButton) {
        if let product = displayedItems.first(where: { $0.pack == selectedPack })?.product {
            // Attempt to purchase the tapped product
            StoreObserver.shared.buy(product, userId: AccountManager.instance.currentUserId, driveId: driveFileManager.drive.id)
            button.setLoading(true)
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

    func storeObserverRestoreDidSucceed() {}

    func storeObserverDidReceiveMessage(_ message: String) {
        UIConstants.showSnackBar(message: message)
        setNextButtonLoading(false)
    }

    func storeObserverPaymentCancelled() {
        setNextButtonLoading(false)
    }
}
