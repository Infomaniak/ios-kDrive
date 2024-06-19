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

import InfomaniakCoreUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import StoreKit
import UIKit

final class StoreViewController: UICollectionViewController {
    @LazyInjectService var accountManager: AccountManageable

    struct Item {
        let packId: DrivePackId
        let identifier: String
        let period: PeriodTab
        var product: SKProduct?

        static let allItems = [
            Item(packId: .solo, identifier: "com.infomaniak.drive.iap.solo.monthly", period: .monthly),
            Item(packId: .team, identifier: "com.infomaniak.drive.iap.team.monthly", period: .monthly),
            // Item(packId: .pro, identifier: "com.infomaniak.drive.iap.pro", period: .monthly),
            Item(packId: .solo, identifier: "com.infomaniak.drive.iap.solo.yearly", period: .yearly),
            Item(packId: .team, identifier: "com.infomaniak.drive.iap.team.yearly", period: .yearly)
            // Item(packId: .pro, identifier: "com.infomaniak.drive.iap.pro.yearly", period: .yearly)
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
        case warning, offers, storage, nextButton
    }

    private var sections: [Section] = [.offers]

    var driveFileManager: DriveFileManager!

    private var purchaseEnabled = true
    private var items = Item.allItems
    private lazy var selectedPackId = DrivePackId(rawValue: driveFileManager.drive.pack.id)
    private var selectedStorage = 1
    private var selectedPeriod = PeriodTab.yearly {
        didSet { updateOffers() }
    }

    private var displayedItems: [Item] {
        return items.filter { $0.period == selectedPeriod }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up collection view
        collectionView.register(WrapperCollectionViewCell.self, forCellWithReuseIdentifier: "WrapperCollectionViewCell")
        collectionView.register(cellView: StoreCollectionViewCell.self)
        collectionView.register(cellView: StoreNextCollectionViewCell.self)
        collectionView.register(supplementaryView: StoreControlCollectionReusableView.self, forSupplementaryViewOfKind: .header)
        collectionView.register(supplementaryView: StoreHelpFooter.self, forSupplementaryViewOfKind: .footer)
        collectionView.collectionViewLayout = createLayout()
        collectionView.allowsSelection = false
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)

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
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: KDriveResourcesStrings.Localizable.buttonRedeemPromoCode,
                style: .plain,
                target: self,
                action: #selector(redeemButtonPressed)
            )
        }

        checkDriveFileManager()

        // Fetch product information
        fetchProductInformation()

        // State restoration must have access to windowScene that is not available yet
        Task { @MainActor in
            saveSceneState()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.store.displayName])
    }

    @objc func closeButtonPressed() {
        dismiss(animated: true)
    }

    @available(iOS 14.0, *)
    @objc func redeemButtonPressed() {
        SKPaymentQueue.default().presentCodeRedemptionSheet()
    }

    private func createLayout() -> UICollectionViewLayout {
        let headerFooterSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerFooterSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        header.pinToVisibleBounds = true
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerFooterSize,
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 24
        config.boundarySupplementaryItems = [header, footer]

        return UICollectionViewCompositionalLayout(sectionProvider: { section, _ in
            switch self.sections[section] {
            case .offers:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(360))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 10
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
                return section
            default:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }
        }, configuration: config)
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
        } else if !driveFileManager.drive.isInAppSubscription && StoreObserver.shared.hasInAppPurchaseReceipts {
            // If we already have a receipt but the product isn't an IAP, prevent user to make a new one
            showBlockingMessage(existingIAP: true)
            purchaseEnabled = false
        } else if !driveFileManager.drive.isInAppSubscription && !driveFileManager.drive.isFreePack {
            // Show a warning message to inform that they have a different subscription method
            sections.insert(.warning, at: 1)
            purchaseEnabled = false
        }
    }

    private func updateOffers() {
        if let sectionIndex = sections.firstIndex(of: .offers) {
            collectionView.reloadSections([sectionIndex])
        }
    }

    private func showBlockingMessage(existingIAP: Bool) {
        let title = existingIAP ? KDriveResourcesStrings.Localizable.storeExistingIAPTitle : KDriveResourcesStrings.Localizable
            .storeAccessDeniedTitle
        let message = existingIAP ? KDriveResourcesStrings.Localizable.storeExistingIAPDescription : KDriveResourcesStrings
            .Localizable.storeAccessDeniedDescription
        let alert = AlertTextViewController(
            title: title,
            message: message,
            action: KDriveResourcesStrings.Localizable.buttonClose,
            hasCancelButton: false
        ) {
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
        if let index = sections.firstIndex(of: .nextButton),
           let cell = collectionView.cellForItem(at: IndexPath(item: 0, section: index)) as? StoreNextCollectionViewCell {
            cell.button.setLoading(loading)
        }
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
        case .warning:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "WrapperCollectionViewCell",
                for: indexPath
            ) as! WrapperCollectionViewCell
            let tableCell = cell.reuse(withCellType: AlertTableViewCell.self)
            tableCell.configure(with: .warning, message: KDriveResourcesStrings.Localizable.storeBillingWarningDescription)
            return cell
        case .offers:
            let cell = collectionView.dequeueReusableCell(type: StoreCollectionViewCell.self, for: indexPath)
            let item = displayedItems[indexPath.row]
            cell.configure(with: item, currentPackId: selectedPackId, enabled: purchaseEnabled)
            cell.delegate = self
            return cell
        case .storage:
            // Will need to convert this to collection view cell when we actually use it
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "WrapperCollectionViewCell",
                for: indexPath
            ) as! WrapperCollectionViewCell
            let tableCell = cell.reuse(withCellType: StoreStorageTableViewCell.self)
            tableCell.delegate = self
            return cell
        case .nextButton:
            let cell = collectionView.dequeueReusableCell(type: StoreNextCollectionViewCell.self, for: indexPath)
            cell.delegate = self
            return cell
        }
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                view: StoreControlCollectionReusableView.self,
                for: indexPath
            )
            let selectedSegmentIndex = PeriodTab.allCases.firstIndex(of: selectedPeriod) ?? 0
            headerView.segmentedControl.setSegments(PeriodTab.allCases.map(\.title), selectedSegmentIndex: selectedSegmentIndex)
            headerView.onChange = { [weak self] index in
                if let period = PeriodTab(rawValue: index) {
                    self?.selectedPeriod = period
                }
            }
            return headerView
        } else {
            let footerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                view: StoreHelpFooter.self,
                for: indexPath
            )
            footerView.delegate = self
            return footerView
        }
    }

    static func instantiate(driveFileManager: DriveFileManager) -> StoreViewController {
        let viewController = Storyboard.menu
            .instantiateViewController(withIdentifier: "StoreViewController") as! StoreViewController
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

    // TODO: Extend UIViewController
    private var currentUserActivity: NSUserActivity {
        let activity: NSUserActivity
        if let currentUserActivity = view.window?.windowScene?.userActivity {
            activity = currentUserActivity
        } else {
            activity = NSUserActivity(activityType: SceneDelegate.MainSceneActivityType)
        }
        return activity
    }

    // TODO: Abstract to prot to test
    func saveSceneState() {
        print("•• saveSceneState")
        let currentUserActivity = currentUserActivity
        let metadata: [AnyHashable: Any] = [
            SceneRestorationKeys.lastViewController.rawValue: SceneRestorationScreens.StoreViewController.rawValue,
            SceneRestorationValues.DriveId.rawValue: driveFileManager.drive.id
        ]
        currentUserActivity.addUserInfoEntries(from: metadata)

        guard let scene = view.window?.windowScene else {
            fatalError("no scene")
        }

        scene.userActivity = currentUserActivity
    }

    // TODO: Remove
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
    }

    // TODO: Remove
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        guard let driveFileManager = accountManager.getDriveFileManager(for: driveId,
                                                                        userId: accountManager.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
        checkDriveFileManager()
        updateOffers()
    }
}

// MARK: - Cell delegates

extension StoreViewController: StoreCellDelegate, StoreStorageDelegate, StoreNextCellDelegate, StoreHelpFooterDelegate {
    func selectButtonTapped(item: StoreViewController.Item) {
        guard selectedPackId != item.packId else { return }
        if !sections.contains(.nextButton) {
            sections.append(.nextButton)
        }
        selectedPackId = item.packId
        collectionView.reloadData()
        collectionView.scrollToItem(at: IndexPath(item: 0, section: sections.count - 1), at: .bottom, animated: true)
    }

    func storageDidChange(_ newValue: Int) {
        selectedStorage = newValue
    }

    func nextButtonTapped(_ button: IKLargeButton) {
        if let product = displayedItems.first(where: { $0.packId == selectedPackId })?.product {
            // Attempt to purchase the tapped product
            StoreObserver.shared.buy(product,
                                     userId: accountManager.currentUserId,
                                     driveId: driveFileManager.drive.id)
            button.setLoading(true)
        }
    }

    func helpButtonTapped() {
        UIApplication.shared.open(URLConstants.faqIAP.url)
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
        // Scroll to current pack
        if let sectionIndex = sections.firstIndex(of: .offers),
           let index = displayedItems.firstIndex(where: { $0.packId == self.selectedPackId }) {
            collectionView.scrollToItem(
                at: IndexPath(item: index, section: sectionIndex),
                at: .centeredVertically,
                animated: false
            )
        }
    }

    func storeManagerDidReceiveMessage(_ message: String) {
        UIConstants.showSnackBar(message: message)
    }
}

// MARK: - Store observer delegate

extension StoreViewController: StoreObserverDelegate {
    func storeObserverPurchaseDidSucceed(transaction: SKPaymentTransaction, receiptString: String) {
        MatomoUtils.track(eventWithCategory: .inApp, name: "buy")
        // Send receipt to the server
        let body = ReceiptInfo(latestReceipt: receiptString,
                               userId: accountManager.currentUserId,
                               itemId: driveFileManager.drive.id,
                               productId: transaction.payment.productIdentifier,
                               transactionId: transaction.transactionIdentifier ?? "",
                               bundleId: Bundle.main.bundleIdentifier ?? "")
        StoreRequest.shared.sendReceipt(body: body)
        // Show success view controller
        showSuccessView()
    }

    func storeObserverRestoreDidSucceed() {
        // META: keep SonarCloud happy
    }

    func storeObserverDidReceiveMessage(_ message: String) {
        UIConstants.showSnackBar(message: message)
        setNextButtonLoading(false)
    }

    func storeObserverPaymentCancelled() {
        setNextButtonLoading(false)
    }
}
