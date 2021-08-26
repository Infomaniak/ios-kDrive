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

protocol StoreCellDelegate: AnyObject {
    func selectButtonTapped(item: StoreViewController.Item)
}

class StoreCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: IKLabel!
    @IBOutlet weak var descriptionLabel: IKLabel!
    @IBOutlet weak var priceLabel: IKLabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var selectButton: IKLargeButton!

    weak var delegate: StoreCellDelegate?

    private var item: StoreViewController.Item?
    private var features = [String]()

    override func awakeFromNib() {
        super.awakeFromNib()

        cornerRadius = UIConstants.cornerRadius
        backgroundColor = KDriveAsset.backgroundCardViewColor.color
        tableView.register(cellView: StoreFeatureTableViewCell.self)
    }

    func configure(with item: StoreViewController.Item, currentPack: DrivePack) {
        self.item = item

        switch item.pack {
        case .free:
            break
        case .solo:
            imageView.image = KDriveAsset.circleSolo.image
            titleLabel.text = "Solo"
            descriptionLabel.text = KDriveStrings.Localizable.storeOfferSoloDescription
            features = [KDriveStrings.Localizable.storeOfferSoloFeature1,
                        KDriveStrings.Localizable.storeOfferSoloFeature2,
                        KDriveStrings.Localizable.storeOfferSoloFeature3]
        case .team:
            imageView.image = KDriveAsset.circleTeam.image
            titleLabel.text = "Team"
            descriptionLabel.text = KDriveStrings.Localizable.storeOfferTeamDescription
            features = [KDriveStrings.Localizable.storeOfferTeamFeature1,
                        KDriveStrings.Localizable.storeOfferTeamFeature2,
                        KDriveStrings.Localizable.storeOfferTeamFeature3,
                        KDriveStrings.Localizable.storeOfferTeamFeature4]
        case .pro:
            imageView.image = KDriveAsset.circlePro.image
            titleLabel.text = "Pro"
            descriptionLabel.text = ""
            features = []
        }

        if let formattedPrice = item.product?.regularPrice, let subscriptionPeriod = item.product?.subscriptionPeriod {
            priceLabel.text = KDriveStrings.Localizable.storePricing(formattedPrice, "\(subscriptionPeriod.numberOfUnits) \(subscriptionPeriod.unit.localizedString)")
        } else {
            priceLabel.text = KDriveStrings.Localizable.storeRetrieving
        }

        selectButton.isSelected = currentPack == item.pack
        selectButton.isEnabled = item.product != nil || currentPack == item.pack

        tableView.reloadData()
    }

    @IBAction func selectButtonTapped(_ sender: Any) {
        selectButton.isSelected = true
        if let item = item {
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
            return KDriveStrings.Localizable.storePeriodDay
        case .week:
            return KDriveStrings.Localizable.storePeriodWeek
        case .month:
            return KDriveStrings.Localizable.storePeriodMonth
        case .year:
            return KDriveStrings.Localizable.storePeriodYear
        @unknown default:
            return KDriveStrings.Localizable.storePeriodUnknown
        }
    }
}
