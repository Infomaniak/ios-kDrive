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

class StoreViewController: UIViewController {
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

    @IBOutlet weak var segmentedControl: IKSegmentedControl!
    @IBOutlet weak var collectionView: UICollectionView!

    private let headerIdentifier = "TabsHeader"

    var driveFileManager: DriveFileManager!

    private var items = Item.allItems
    private var selectedPeriod = PeriodTab.monthly {
        didSet { collectionView.reloadData() }
    }

    private var displayedItems: [Item] {
        return items.filter { $0.period == selectedPeriod }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(cellView: StoreCollectionViewCell.self)
        collectionView.allowsSelection = false
        collectionView.decelerationRate = .fast

        // Set up delegates
        StoreManager.shared.delegate = self
        StoreObserver.shared.delegate = self

        // Set up segmented control
        segmentedControl.setSegments(PeriodTab.allCases.map(\.title))

        // Fetch product information
        fetchProductInformation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()
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

    @IBAction func periodChanged(_ sender: Any) {
        if let period = PeriodTab(rawValue: segmentedControl.selectedSegmentIndex) {
            selectedPeriod = period
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
        collectionView.reloadData()
    }
}

// MARK: - Collection view data source

extension StoreViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return driveFileManager == nil ? 0 : displayedItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: StoreCollectionViewCell.self, for: indexPath)
        let item = displayedItems[indexPath.row]
        cell.configure(with: item, currentPack: driveFileManager.drive.pack)
        cell.delegate = self
        return cell
    }
}

// MARK: - Scroll view delegate

extension StoreViewController: UIScrollViewDelegate {
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let itemWidth = collectionView.bounds.size.width - 48 + 10
        let inertialTargetX = targetContentOffset.pointee.x
        let offsetFromPreviousPage = (inertialTargetX + collectionView.contentInset.left).truncatingRemainder(dividingBy: itemWidth)

        // Snap to nearest page
        let pagedX: CGFloat
        if offsetFromPreviousPage > itemWidth / 2 {
            pagedX = inertialTargetX + (itemWidth - offsetFromPreviousPage)
        } else {
            pagedX = inertialTargetX - offsetFromPreviousPage
        }

        let point = CGPoint(x: pagedX, y: targetContentOffset.pointee.y)
        targetContentOffset.pointee = point
    }
}

// MARK: - Collection view flow delegate

extension StoreViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.size.width - 48, height: 360)
    }
}

// MARK: - Store cell delegate

extension StoreViewController: StoreCellDelegate {
    func selectButtonTapped(item: Item) {
        if let product = item.product {
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
        collectionView.reloadData()
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
