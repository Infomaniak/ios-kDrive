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
import UIKit

class RecentActivityCollectionViewCell: InsetCollectionViewCell, UICollectionViewDelegate, UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {
    @IBOutlet var avatarImage: UIImageView!
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var titleLabel: IKLabel!
    @IBOutlet var detailLabel: UILabel!
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var collectionViewFlowLayout: UICollectionViewFlowLayout!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var tableViewHeight: NSLayoutConstraint!

    weak var delegate: RecentActivityDelegate?

    private var activity: FileActivity?
    private var activities = [FileActivity]()

    private var isLoading = false
    private let bottomViewCellHeight = 26.0

    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.register(cellView: RecentActivityPreviewCollectionViewCell.self)
        collectionView.delegate = self
        collectionView.dataSource = self
        tableView.register(cellView: RecentActivityBottomTableViewCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        avatarImage.cornerRadius = avatarImage.frame.width / 2
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isLoading = false
        activity = nil
        activities = []
        contentInsetView.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        titleLabel.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        detailLabel.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        collectionView.reloadData()
        tableView.reloadData()
    }

    override func initWithPositionAndShadow(
        isFirst: Bool = false,
        isLast: Bool = false,
        elevation: Double = 0,
        radius: CGFloat = 6
    ) {
        contentInsetView.cornerRadius = radius
    }

    func configureLoading() {
        isLoading = true
        activity = nil
        titleLabel.text = " "
        let titleLayer = CALayer()
        titleLayer.anchorPoint = .zero
        titleLayer.bounds = CGRect(x: 0, y: 0, width: 100, height: 10)
        titleLayer.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color.cgColor
        titleLabel.layer.addSublayer(titleLayer)
        detailLabel.text = " "
        let detailLayer = CALayer()
        detailLayer.anchorPoint = .zero
        detailLayer.bounds = CGRect(x: 0, y: 0, width: 80, height: 10)
        detailLayer.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color.cgColor
        detailLabel.layer.addSublayer(detailLayer)
        timeLabel.text = nil
        avatarImage.image = KDriveResourcesAsset.placeholderAvatar.image
        tableViewHeight.constant = bottomViewCellHeight
        collectionView.reloadData()
        tableView.reloadData()
        contentInsetView.backgroundColor = KDriveResourcesAsset.loaderDefaultColor.color
    }

    func configureWith(recentActivity: FileActivity) {
        activity = recentActivity
        activities = [recentActivity] + recentActivity.mergedFileActivities
        let count = activities.count
        let isDirectory = activity?.file?.isDirectory ?? false
        switch recentActivity.action {
        case .fileCreate:
            detailLabel.text = isDirectory ? KDriveResourcesStrings.Localizable
                .fileActivityFolderCreate(count) : KDriveResourcesStrings.Localizable.fileActivityFileCreate(count)
        case .fileTrash:
            detailLabel.text = isDirectory ? KDriveResourcesStrings.Localizable
                .fileActivityFolderTrash(count) : KDriveResourcesStrings.Localizable.fileActivityFileTrash(count)
        case .fileUpdate:
            detailLabel.text = KDriveResourcesStrings.Localizable.fileActivityFileUpdate(count)
        case .commentCreate:
            detailLabel.text = KDriveResourcesStrings.Localizable.fileActivityCommentCreate(count)
        case .fileRestore:
            detailLabel.text = isDirectory ? KDriveResourcesStrings.Localizable
                .fileActivityFolderRestore(count) : KDriveResourcesStrings.Localizable.fileActivityFileRestore(count)
        default:
            detailLabel.text = KDriveResourcesStrings.Localizable.fileActivityUnknown(count)
        }

        tableViewHeight.constant = CGFloat(min(activities.count, 3)) * bottomViewCellHeight

        avatarImage.image = KDriveResourcesAsset.placeholderAvatar.image

        if let user = recentActivity.user {
            titleLabel.text = user.displayName
            timeLabel.text = Constants.formatDate(recentActivity.createdAt, relative: true)

            user.getAvatar { [weak self] image in
                self?.avatarImage.image = image.withRenderingMode(.alwaysOriginal)
            }
        }
        collectionView.reloadData()
        tableView.reloadData()
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
        let cell = collectionView.dequeueReusableCell(type: RecentActivityPreviewCollectionViewCell.self, for: indexPath)
        if isLoading {
            cell.configureLoading()
        } else {
            let activity = activities[indexPath.item]
            let more = indexPath.item == 2 && activities.count > 3 ? activities.count - 2 : nil
            if let file = activity.file,
               file.supportedBy.contains(.thumbnail) && (file.convertedType == .image || file.convertedType == .video) {
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

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let height = collectionView.frame.height
        let itemQuantity = CGFloat(isLoading ? 3 : min(activities.count, 3))
        let width = (collectionView.frame.width - collectionViewFlowLayout.minimumInteritemSpacing * (itemQuantity - 1)) /
            itemQuantity
        return CGSize(width: width, height: height)
    }
}

// MARK: - Table view delegate & Data Source

extension RecentActivityCollectionViewCell: UITableViewDelegate, UITableViewDataSource {
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
            let more = indexPath.row == 2 && activities.count > 3 ? activities.count - 2 : nil
            cell.configureWith(recentActivity: activities[indexPath.row], more: more)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isLoading else { return }
        delegate?.didSelectActivity(index: indexPath.row, activities: activities)
    }
}

protocol RecentActivityDelegate: AnyObject {
    func didSelectActivity(index: Int, activities: [FileActivity])
}
