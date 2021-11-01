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

import Foundation
import kDriveCore

class HomeRecentActivitiesController: HomeRecentFilesController {
    private let mergeFileCreateDelay = 43_200 // 12h

    private var mergedActivities = [FileActivity]()

    required convenience init(driveFileManager: DriveFileManager, homeViewController: HomeViewController) {
        self.init(driveFileManager: driveFileManager,
                  homeViewController: homeViewController,
                  listCellType: RecentActivityCollectionViewCell.self, gridCellType: RecentActivityCollectionViewCell.self, emptyCellType: .noActivities,
                  title: KDriveStrings.Localizable.lastEditsTitle, selectorTitle: KDriveStrings.Localizable.fileDetailsActivitiesTitle,
                  listStyleEnabled: false)
    }

    override func restoreCachedPages() {
        homeViewController?.reloadWith(fetchedFiles: .fileActivity(mergedActivities), isEmpty: empty)
    }

    override func loadNextPage() {
        if forceRefresh {
            resetController()
            mergedActivities = []
        }

        guard !loading && moreComing else {
            return
        }
        invalidated = false
        loading = true

        driveFileManager.apiFetcher.getRecentActivity(driveId: driveFileManager.drive.id, page: page) { response, _ in
            self.loading = false
            if let activities = response?.data {
                self.empty = self.page == 1 && activities.isEmpty
                self.moreComing = activities.count == DriveApiFetcher.itemPerPage
                self.page += 1

                DispatchQueue.global(qos: .utility).async {
                    let mergedActivities = self.mergeAndClean(activities: activities)
                    self.mergedActivities.append(contentsOf: mergedActivities)

                    guard !self.invalidated else {
                        return
                    }
                    self.homeViewController?.reloadWith(fetchedFiles: .fileActivity(self.mergedActivities), isEmpty: self.empty)
                }
                // Update cache
                if self.page == 1 {
                    self.driveFileManager.setLocalRecentActivities(activities)
                }
            } else {
                DispatchQueue.global(qos: .utility).async {
                    let activities = self.driveFileManager.getLocalRecentActivities()
                    self.mergedActivities = self.mergeAndClean(activities: activities)

                    self.empty = self.mergedActivities.isEmpty
                    self.moreComing = false
                    guard !self.invalidated else {
                        return
                    }
                    self.homeViewController?.reloadWith(fetchedFiles: .fileActivity(self.mergedActivities), isEmpty: self.empty)
                }
            }
        }
    }

    private func mergeAndClean(activities: [FileActivity]) -> [FileActivity] {
        let activities = activities.filter { $0.user != nil }

        var resultActivities = [FileActivity]()
        var ignoredActivityIds = [Int]()

        for (index, activity) in activities.enumerated() {
            let ignoreActivity = !resultActivities.isEmpty && resultActivities.last?.user?.id == activity.user?.id && resultActivities.last?.action == activity.action && resultActivities.last?.file?.id == activity.file?.id
            if !ignoredActivityIds.contains(activity.id) && !ignoreActivity {
                var i = index + 1
                var mergedFilesTemp = [activity.fileId: activity.file]
                while i < activities.count && activity.createdAt - activities[i].createdAt <= mergeFileCreateDelay {
                    if activity.user?.id == activities[i].user?.id && activity.action == activities[i].action && activity.file?.type == activities[i].file?.type {
                        ignoredActivityIds.append(activities[i].id)
                        if mergedFilesTemp[activities[i].fileId] == nil {
                            activity.mergedFileActivities.append(activities[i])
                            mergedFilesTemp[activities[i].fileId] = activities[i].file
                        }
                    }
                    i += 1
                }
                resultActivities.append(activity)
            }
        }

        return resultActivities
    }

    override func getLayout(for style: ListStyle) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(200))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.boundarySupplementaryItems = [getHeaderLayout()]
        return section
    }

    override class func initInstance(driveFileManager: DriveFileManager, homeViewController: HomeViewController) -> Self {
        return Self(driveFileManager: driveFileManager, homeViewController: homeViewController)
    }
}
