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

import InfomaniakCore
import kDriveCore
import kDriveResources
import StoreKit
import UIKit

class StoreViewController: UICollectionViewController {
//    @IBOutlet weak var tableView: UITableView!
//    @IBOutlet weak var helpButton: IKRoundButton!

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
                return KDriveResourcesStrings.Localizable.storeMonthly
            case .yearly:
                return KDriveResourcesStrings.Localizable.storeYearly
            }
        }
    }

    private enum Section: CaseIterable {
        case segmentedControl, warning, offers, storage, nextButton
    }

    private var sections: [Section] = [.segmentedControl, .offers]

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
//        tableView.register(cellView: StoreControlTableViewCell.self)
//        tableView.register(cellView: AlertTableViewCell.self)
//        tableView.register(cellView: StoreOffersTableViewCell.self)
//        tableView.register(cellView: StoreStorageTableViewCell.self)
//        tableView.register(cellView: StoreNextTableViewCell.self)
//        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 92, right: 0)

        // Set up collection view
        collectionView.register(WrapperCollectionViewCell.self, forCellWithReuseIdentifier: "WrapperCollectionViewCell")
        collectionView.register(cellView: StoreCollectionViewCell.self)
        collectionView.collectionViewLayout = createLayout()
        collectionView.allowsSelection = false
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listFloatingButtonPaddingBottom, right: 0)

        // Set up delegates
        StoreManager.shared.delegate = self
        StoreObserver.shared.delegate = self

        let viewControllersCount = navigationController?.viewControllers.count ?? 0
        if presentingViewController != nil && viewControllersCount < 2 {
            // Show cancel button
            let closeButton = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
            closeButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
            navigationItem.leftBarButtonItem = closeButton
        }

        if #available(iOS 14.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: KDriveResourcesStrings.Localizable.buttonRedeemPromoCode, style: .plain, target: self, action: #selector(redeemButtonPressed))
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

    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { section, _ in
            switch self.sections[section] {
            case .offers:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(360))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 8
                section.contentInsets = .init(top: 0, leading: 24, bottom: 0, trailing: 24)
                return section
            default:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }
        }
    }

    private func fetchProductInformation() {
        guard StoreObserver.shared.isAuthorizedForPayments else {
            // Warn the user that they are not allowed to make purchases
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.storePaymentNotAuthorized)
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
        } else if !driveFileManager.drive.productIsInApp && StoreObserver.shared.hasInAppPurchaseReceipts {
            // If we already have a receipt but the product isn't an IAP, prevent user to make a new one
            showBlockingMessage(existingIAP: true)
            purchaseEnabled = false
        } else if !driveFileManager.drive.productIsInApp && driveFileManager.drive.pack != .free {
            // Show a warning message to inform that they have a different subscription method
            sections.insert(.warning, at: 1)
            purchaseEnabled = false
        }
    }

    private func updateOffers() {
        if let index = sections.firstIndex(of: .offers) {
            collectionView.reloadSections([index])
//            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
    }

    private func showBlockingMessage(existingIAP: Bool) {
        let title = existingIAP ? KDriveResourcesStrings.Localizable.storeExistingIAPTitle : KDriveResourcesStrings.Localizable.storeAccessDeniedTitle
        let message = existingIAP ? KDriveResourcesStrings.Localizable.storeExistingIAPDescription : KDriveResourcesStrings.Localizable.storeAccessDeniedDescription
        let alert = AlertTextViewController(title: title, message: message, action: KDriveResourcesStrings.Localizable.buttonClose, hasCancelButton: false) {
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
//        if let index = sections.firstIndex(of: .nextButton),
//           let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? StoreNextTableViewCell {
//            cell.button.setLoading(loading)
//        }
    }

    private func showSuccessView() {
        let successViewController = StoreSuccessViewController.instantiate()
        successViewController.modalPresentationStyle = .fullScreen
        present(successViewController, animated: true)
    }

    // MARK: - Collection view data source

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .offers:
            return displayedItems.count
        default:
            return 1
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .segmentedControl:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WrapperCollectionViewCell", for: indexPath) as! WrapperCollectionViewCell
            let tableCell = cell.initWith(cell: StoreControlTableViewCell.self)
            let selectedSegmentIndex = PeriodTab.allCases.firstIndex(of: selectedPeriod) ?? 0
            tableCell.segmentedControl.setSegments(PeriodTab.allCases.map(\.title), selectedSegmentIndex: selectedSegmentIndex)
            tableCell.onChange = { [weak self] index in
                if let period = PeriodTab(rawValue: index) {
                    self?.selectedPeriod = period
                }
            }
            return cell
        case .warning:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WrapperCollectionViewCell", for: indexPath) as! WrapperCollectionViewCell
            let tableCell = cell.initWith(cell: AlertTableViewCell.self)
            tableCell.configure(with: .warning, message: KDriveResourcesStrings.Localizable.storeBillingWarningDescription)
            return cell
        case .offers:
            let cell = collectionView.dequeueReusableCell(type: StoreCollectionViewCell.self, for: indexPath)
            let item = displayedItems[indexPath.row]
            cell.configure(with: item, currentPack: selectedPack, enabled: purchaseEnabled)
            cell.delegate = self
            return cell
        case .storage:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WrapperCollectionViewCell", for: indexPath) as! WrapperCollectionViewCell
            let tableCell = cell.initWith(cell: StoreStorageTableViewCell.self)
            tableCell.delegate = self
            return cell
        case .nextButton:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WrapperCollectionViewCell", for: indexPath) as! WrapperCollectionViewCell
            let tableCell = cell.initWith(cell: StoreNextTableViewCell.self)
            tableCell.delegate = self
            return cell
        }
    }

    // MARK: - Table view data source

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return driveFileManager == nil ? 1 : sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.row] {
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
            cell.configure(with: .warning, message: KDriveResourcesStrings.Localizable.storeBillingWarningDescription)
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
        if !sections.contains(.nextButton) {
            sections.append(.nextButton)
        }
        selectedPack = item.pack
//        tableView.reloadData()
//        tableView.scrollToRow(at: IndexPath(row: sections.count - 1, section: 0), at: .bottom, animated: true)
        collectionView.reloadData()
        collectionView.scrollToItem(at: IndexPath(row: 0, section: sections.count - 1), at: .bottom, animated: true)
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
