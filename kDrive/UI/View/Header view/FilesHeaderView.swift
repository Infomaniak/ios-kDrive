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

import UIKit
import kDriveCore

protocol FilesHeaderViewDelegate: AnyObject {
    func sortButtonPressed()
    func gridButtonPressed()
    func uploadCardSelected()
    func removeFileTypeButtonPressed()
    func moveButtonPressed()
    func deleteButtonPressed()
    func menuButtonPressed()
}

extension FilesHeaderViewDelegate {
    func uploadCardSelected() { }
    func moveButtonPressed() { }
    func deleteButtonPressed() { }
    func menuButtonPressed() { }
}

class FilesHeaderView: UICollectionReusableView {

    @IBOutlet weak var sortView: UIView!
    @IBOutlet weak var sortButton: UIButton!
    @IBOutlet weak var listOrGridButton: UIButton!
    @IBOutlet weak var uploadCardView: UploadCardView!
    @IBOutlet weak var selectView: SelectView!
    @IBOutlet weak var fileTypeFilterView: FilterFileTypeView!
    @IBOutlet weak var offlineView: UIView!
    @IBOutlet weak var activityListView: UIView!
    @IBOutlet weak var activityAvatar: UIImageView!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var moveButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    weak var delegate: FilesHeaderViewDelegate? {
        didSet {
            selectView.delegate = delegate
            fileTypeFilterView.delegate = delegate
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        // Sort button
        let layoutDirection = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute)
        sortButton.semanticContentAttribute = layoutDirection == .rightToLeft ? .forceLeftToRight : .forceRightToLeft
        sortButton.imageView?.contentMode = .scaleAspectFit

        listOrGridButton.accessibilityLabel = KDriveStrings.Localizable.buttonToggleDisplay
        if ReachabilityListener.instance.currentStatus == .offline {
            offlineView.isHidden = false
        }
        uploadCardView.iconView.isHidden = true
        uploadCardView.progressView.trackTintColor = KDriveAsset.secondaryTextColor.color.withAlphaComponent(0.2)
        uploadCardView.progressView.progressTintColor = KDriveAsset.infomaniakColor.color
        uploadCardView.progressView.thicknessRatio = 0.15
        uploadCardView.progressView.indeterminateProgress = 0.75
        uploadCardView.roundCorners(corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner], radius: 10)
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOnCard))
        uploadCardView.addGestureRecognizer(tapGestureRecognizer)
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
