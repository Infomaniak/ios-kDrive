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

import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import StoreKit
import UIKit

protocol StoreCellDelegate: AnyObject {
    func selectButtonTapped(item: StoreViewController.Item)
}

final class StoreCollectionViewCell: UICollectionViewCell {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var titleLabel: IKLabel!
    @IBOutlet var descriptionLabel: IKLabel!
    @IBOutlet var priceLabel: IKLabel!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var selectButton: IKLargeButton!

    weak var delegate: StoreCellDelegate?

    private var item: StoreViewController.Item?
    private var features = [String]()

    override func awakeFromNib() {
        super.awakeFromNib()

        cornerRadius = UIConstants.cornerRadius
        backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        tableView.register(cellView: StoreFeatureTableViewCell.self)
    }

    func configure(with item: StoreViewController.Item, currentPackId: DrivePackId?, enabled: Bool) {
        self.item = item

        switch item.packId {
        case .solo:
            imageView.image = KDriveResourcesAsset.circleSolo.image
            titleLabel.text = "Solo"
            descriptionLabel.text = KDriveResourcesStrings.Localizable.storeOfferSoloDescription
            features = [KDriveResourcesStrings.Localizable.storeOfferSoloFeature1,
                        KDriveResourcesStrings.Localizable.storeOfferSoloFeature2,
                        KDriveResourcesStrings.Localizable.storeOfferSoloFeature3]
        case .team:
            imageView.image = KDriveResourcesAsset.circleTeam.image
            titleLabel.text = "Team"
            descriptionLabel.text = KDriveResourcesStrings.Localizable.storeOfferTeamDescription
            features = [KDriveResourcesStrings.Localizable.storeOfferTeamFeature1,
                        KDriveResourcesStrings.Localizable.storeOfferTeamFeature2,
                        KDriveResourcesStrings.Localizable.storeOfferTeamFeature3,
                        KDriveResourcesStrings.Localizable.storeOfferTeamFeature4]
        case .pro:
            imageView.image = KDriveResourcesAsset.circlePro.image
            titleLabel.text = "Pro"
            descriptionLabel.text = ""
            features = []
        default:
            break
        }

        if let formattedPrice = item.product?.regularPrice, let subscriptionPeriod = item.product?.subscriptionPeriod {
            priceLabel.text = KDriveResourcesStrings.Localizable.storePricing(
                formattedPrice,
                "\(subscriptionPeriod.numberOfUnits) \(subscriptionPeriod.unit.localizedString)"
            )
        } else {
            priceLabel.text = KDriveResourcesStrings.Localizable.storeRetrieving
        }

        selectButton.isSelected = currentPackId == item.packId
        selectButton.isEnabled = item.product != nil && enabled

        tableView.reloadData()
    }

    @IBAction func selectButtonTapped(_ sender: Any) {
        selectButton.isSelected = true
        if let item {
            delegate?.selectButtonTapped(item: item)
        }
    }
}

// MARK: - Table view data source

extension StoreCollectionViewCell: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return features.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: StoreFeatureTableViewCell.self, for: indexPath)

        cell.label.text = features[indexPath.row]

        return cell
    }
}

extension SKProduct.PeriodUnit {
    var localizedString: String {
        switch self {
        case .day:
            return KDriveResourcesStrings.Localizable.storePeriodDay
        case .week:
            return KDriveResourcesStrings.Localizable.storePeriodWeek
        case .month:
            return KDriveResourcesStrings.Localizable.storePeriodMonth
        case .year:
            return KDriveResourcesStrings.Localizable.storePeriodYear
        @unknown default:
            return KDriveResourcesStrings.Localizable.storePeriodUnknown
        }
    }
}
