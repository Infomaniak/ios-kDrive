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
            titleLabel.text = "Solo"
            descriptionLabel.text = "1 utilisateur maximum\n2 To de stockage"
            features = ["Personnalisation des liens de partage",
                        "Support du protocole WebDAV",
                        "Support 7/7j"]
        case .team:
            titleLabel.text = "Team"
            descriptionLabel.text = "6 utilisateurs inclus et au maximum\nDe 3 à 18 To de stockage"
            features = ["Tout ce qu’il y a dans l’offre Solo",
                        "Travail en collaboration avec plusieurs utilisateurs",
                        "Boîte de dépôt",
                        "Gestion simple des utilisateurs"]
        case .pro:
            titleLabel.text = "Pro"
            descriptionLabel.text = "Dès 3 utilisateurs\nDe 6 à 108 To de stockage"
            features = ["Tout ce qu’il y a dans l’offre Team",
                        "Gestion complète des utilisateurs",
                        "Transfert des données d’un utilisateur supprimé",
                        "Statistiques avancées"]
        }

        if let formattedPrice = item.product?.regularPrice, let subscriptionPeriod = item.product?.subscriptionPeriod {
            priceLabel.text = "\(formattedPrice) pour \(subscriptionPeriod.numberOfUnits) \(subscriptionPeriod.unit.localizedString)"
        } else {
            priceLabel.text = "Prix inconnu"
        }

        if currentPack == item.pack {
            selectButton.isEnabled = false
            selectButton.setTitle("Sélectionné", for: .normal)
        } else {
            selectButton.isEnabled = item.product != nil
            selectButton.setTitle("Sélectionner", for: .normal)
        }
    }

    @IBAction func selectButtonTapped(_ sender: Any) {
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
            return "jour"
        case .week:
            return "semaine"
        case .month:
            return "mois"
        case .year:
            return "an"
        @unknown default:
            return "période"
        }
    }
}
