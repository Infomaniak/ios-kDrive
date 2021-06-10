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
import InfomaniakCore
import kDriveCore

class RecentActivityTableViewCell: InsetTableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var avatarImage: UIImageView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewFlowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!

    weak var delegate: RecentActivityDelegate?

    var activity: FileActivity?
    var activities: [FileActivity] {
        if let activity = activity {
            return [activity] + activity.mergedFileActivities
        } else {
            return []
        }
    }
    var isLoading = false
    let bottomViewCellHeight: CGFloat = 26

    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(cellView: RecentActivityCollectionViewCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellView: RecentActivityBottomTableViewCell.self)
        avatarImage.cornerRadius = avatarImage.frame.width / 2
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isLoading = false
        activity = nil
        titleLabel.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        detailLabel.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if isLoading {
            contentInsetView.backgroundColor = KDriveAsset.loaderDefaultColor.color
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if isLoading {
            contentInsetView.backgroundColor = KDriveAsset.loaderDefaultColor.color
        }
    }

    func configureLoading() {
        isLoading = true
        activity = nil
        titleLabel.text = " "
        let titleLayer = CALayer()
        titleLayer.anchorPoint = .zero
        titleLayer.bounds = CGRect(x: 0, y: 0, width: 100, height: 10)
        titleLayer.backgroundColor = KDriveAsset.loaderDarkerDefaultColor.color.cgColor
        titleLabel.layer.addSublayer(titleLayer)
        detailLabel.text = " "
        let detailLayer = CALayer()
        detailLayer.anchorPoint = .zero
        detailLayer.bounds = CGRect(x: 0, y: 0, width: 80, height: 10)
        detailLayer.backgroundColor = KDriveAsset.loaderDarkerDefaultColor.color.cgColor
        detailLabel.layer.addSublayer(detailLayer)
        timeLabel.text = nil
        avatarImage.image = KDriveAsset.placeholderAvatar.image
        tableViewHeight.constant = bottomViewCellHeight
    }

    func configureWith(recentActivity: FileActivity) {
        activity = recentActivity
        // activity?.file = recentActivity.file?.freeze()
        let count = activities.count
        let isDirectory = activity?.file?.isDirectory ?? false
        switch recentActivity.action {
        case .fileCreate:
            detailLabel.text = isDirectory ? KDriveStrings.Localizable.fileActivityFolderCreate(count) : KDriveStrings.Localizable.fileActivityFileCreate(count)
        case .fileTrash:
            detailLabel.text = isDirectory ? KDriveStrings.Localizable.fileActivityFolderTrash(count) : KDriveStrings.Localizable.fileActivityFileTrash(count)
        case .fileUpdate:
            detailLabel.text = KDriveStrings.Localizable.fileActivityFileUpdate(count)
        case .commentCreate:
            detailLabel.text = KDriveStrings.Localizable.fileActivityCommentCreate(count)
        case .fileRestore:
            detailLabel.text = isDirectory ? KDriveStrings.Localizable.fileActivityFolderRestore(count) : KDriveStrings.Localizable.fileActivityFileRestore(count)
        default:
            detailLabel.text = KDriveStrings.Localizable.fileActivityUnknown(count)
        }

        tableViewHeight.constant = CGFloat(min(activities.count, 3)) * bottomViewCellHeight

        avatarImage.image = KDriveAsset.placeholderAvatar.image

        if let user = activity?.user {
            titleLabel.text = user.displayName
            timeLabel.text = Constants.formatTimestamp(TimeInterval(activity?.createdAt ?? 0), relative: true)

            user.getAvatar { image in
                self.avatarImage.image = image.withRenderingMode(.alwaysOriginal)
            }
        }
    }

    @IBAction func bottomViewTap() {
        delegate?.didSelectActivity(index: 0, activities: [activity].compactMap { $0 })
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionViewFlowLayout.invalidateLayout()
    }

    // MARK: - Collection view data source

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isLoading ? 3 : min(activities.count, 3)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: RecentActivityCollectionViewCell.self, for: indexPath)
        if isLoading {
            cell.configureLoading()
        } else {
            let activity = activities[indexPath.item]
            let more = indexPath.item == 2 && activities.count > 3 ? activities.count - 2: nil
            if let file = activity.file, file.hasThumbnail && (file.convertedType == .image || file.convertedType == .video) {
                cell.configureWithPreview(file: file, more: more)
            } else {
                cell.configureWithoutPreview(file: activity.file, more: more)
            }
        }
        return cell
    }

    // MARK: - Collection view delegate

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return !isLoading
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return !isLoading
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectActivity(index: indexPath.row, activities: activities)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = collectionView.frame.height
        let itemQuantity = CGFloat(isLoading ? 3 : min(activities.count, 3))
        let width = (collectionView.frame.width - collectionViewFlowLayout.minimumInteritemSpacing * (itemQuantity - 1)) / itemQuantity
        return CGSize(width: width, height: height)
    }

}

// MARK: - Table view delegate & Data Source
extension RecentActivityTableViewCell: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isLoading ? 1 : min(activities.count, 3)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: RecentActivityBottomTableViewCell.self, for: indexPath)
        if isLoading {
            cell.configureLoading()
        } else {
            let more = indexPath.item == 2 && activities.count > 3 ? activities.count - 2: nil
            cell.configureWith(recentActivity: activities[indexPath.row], more: more)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.didSelectActivity(index: indexPath.row, activities: activities)
    }
}

protocol RecentActivityDelegate: AnyObject {
    func didSelectActivity(index: Int, activities: [FileActivity])
}
