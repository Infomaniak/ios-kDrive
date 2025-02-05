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
import UIKit

protocol FilesHeaderViewDelegate: AnyObject {
    func sortButtonPressed()
    func gridButtonPressed()
    func uploadCardSelected()
    func removeFilterButtonPressed(_ filter: Filterable)
    func multipleSelectionActionButtonPressed(_ button: SelectView.MultipleSelectionActionButton)
}

extension FilesHeaderViewDelegate {
    func uploadCardSelected() {}
}

class FilesHeaderView: UICollectionReusableView {
    @IBOutlet var containerStackView: UIStackView!
    @IBOutlet var commonDocumentsDescriptionLabel: UILabel!
    @IBOutlet var sortView: UIView!
    @IBOutlet var sortButton: UIButton!
    @IBOutlet var listOrGridButton: UIButton!
    @IBOutlet var uploadCardView: UploadCardView!
    @IBOutlet var filterView: FilterView!
    @IBOutlet var offlineView: UIView!
    @IBOutlet var activityListView: UIView!
    @IBOutlet var activityAvatar: UIImageView!
    @IBOutlet var activityLabel: UILabel!
    @IBOutlet var trashInformationView: UIView!
    @IBOutlet var trashInformationTitle: UILabel!
    @IBOutlet var trashInformationSubtitle: UILabel!
    @IBOutlet var trashInformationChip: UIView!
    var selectView: SelectView!

    weak var delegate: FilesHeaderViewDelegate? {
        didSet {
            selectView.delegate = delegate
            filterView.delegate = delegate
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Sort button
        let layoutDirection = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute)
        sortButton.semanticContentAttribute = layoutDirection == .rightToLeft ? .forceLeftToRight : .forceRightToLeft
        sortButton.imageView?.contentMode = .scaleAspectFit

        listOrGridButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonToggleDisplay
        if ReachabilityListener.instance.currentStatus == .offline {
            offlineView.isHidden = false
        }
        uploadCardView.iconView.isHidden = true
        uploadCardView.progressView.setInfomaniakStyle()
        uploadCardView.roundCorners(
            corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner],
            radius: 10
        )
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOnCard))
        uploadCardView.addGestureRecognizer(tapGestureRecognizer)

        setupTrashView()

        selectView = SelectView.instantiate()
        selectView.isHidden = true
        containerStackView.addArrangedSubview(selectView)
    }

    private func setupTrashView() {
        trashInformationView.isHidden = true

        trashInformationTitle.font = .systemFont(ofSize: 14)
        trashInformationTitle.textColor = KDriveResourcesAsset.headerTitleColor.color // "#556772"
        trashInformationSubtitle.font = .systemFont(ofSize: 14)
        trashInformationSubtitle.textColor = KDriveResourcesAsset.infomaniakColor.color // "#0098FF"

        // TODO: remove hardcoded text
        trashInformationTitle
            .text = "Trash is cleaned automatically every 30 days, Trash is cleaned automatically every 30 days !"
        trashInformationSubtitle.text = "Upgrade"

        let chipView = MyKSuiteChip.instantiateWhiteChip()
        chipView.translatesAutoresizingMaskIntoConstraints = false
        trashInformationChip.addSubview(chipView)

        NSLayoutConstraint.activate([
            chipView.leadingAnchor.constraint(greaterThanOrEqualTo: trashInformationChip.leadingAnchor),
            chipView.trailingAnchor.constraint(greaterThanOrEqualTo: trashInformationChip.trailingAnchor),
            chipView.topAnchor.constraint(equalTo: trashInformationChip.topAnchor),
            chipView.bottomAnchor.constraint(equalTo: trashInformationChip.bottomAnchor)
        ])
    }

    @objc private func didTapOnCard() {
        delegate?.uploadCardSelected()
    }

    @IBAction func filterButtonPressed(_ sender: UIButton) {
        delegate?.sortButtonPressed()
    }

    @IBAction func gridButtonPressed(_ sender: UIButton) {
        delegate?.gridButtonPressed()
    }
}
