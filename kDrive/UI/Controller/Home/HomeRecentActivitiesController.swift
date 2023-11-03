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
import InfomaniakCore
import kDriveCore
import kDriveResources
import UIKit

class HomeRecentActivitiesController: HomeRecentFilesController {
    private let mergeFileCreateDelay = 43200.0 // 12h

    private var mergedActivities = [FileActivity]()

    required convenience init(driveFileManager: DriveFileManager, homeViewController: HomeViewController) {
        self.init(driveFileManager: driveFileManager,
                  homeViewController: homeViewController,
                  listCellType: RecentActivityCollectionViewCell.self, gridCellType: RecentActivityCollectionViewCell.self,
                  emptyCellType: .noActivities,
                  title: KDriveResourcesStrings.Localizable.lastEditsTitle,
                  selectorTitle: KDriveResourcesStrings.Localizable.fileDetailsActivitiesTitle,
                  listStyleEnabled: false)
    }

    override func restoreCachedPages() {
        invalidated = false
        homeViewController?.reloadWith(fetchedFiles: .fileActivity(mergedActivities), isEmpty: empty)
    }

    override func loadNextPage(forceRefresh: Bool = false) {
        if forceRefresh {
            resetController()
            mergedActivities = []
        }

        invalidated = false
        guard !loading && moreComing else {
            return
        }
        loading = true

        Task {
            do {
                let activitiesResponse = try await driveFileManager.apiFetcher.recentActivity(drive: driveFileManager.drive,
                                                                                              cursor: nextCursor)
                self.empty = self.nextCursor == nil && activitiesResponse.data.isEmpty
                self.moreComing = activitiesResponse.response.hasMore

                display(activities: activitiesResponse.data)
                // Update cache
                if nextCursor == nil {
                    self.driveFileManager.setLocalRecentActivities(activitiesResponse.data)
                }
                self.nextCursor = activitiesResponse.response.cursor
            } catch {
                let activities = self.driveFileManager.getLocalRecentActivities()
                self.empty = activities.isEmpty
                self.moreComing = false

                display(activities: activities)
            }
        }
    }

    private func display(activities: [FileActivity]) {
        DispatchQueue.global(qos: .utility).async {
            let pagedActivities = self.mergeAndClean(activities: activities)
            self.mergedActivities.append(contentsOf: pagedActivities)

            guard !self.invalidated else {
                self.loading = false
                return
            }
            Task { [activities = self.mergedActivities] in
                self.homeViewController?.reloadWith(fetchedFiles: .fileActivity(activities), isEmpty: self.empty)
                self.loading = false
            }
        }
    }

    private func mergeAndClean(activities: [FileActivity]) -> [FileActivity] {
        let activities = activities.filter { $0.user != nil }

        var resultActivities = [FileActivity]()
        var ignoredActivityIds = [Int]()

        for (index, activity) in activities.enumerated() {
            let ignoreActivity = !resultActivities.isEmpty && resultActivities.last?.userId == activity.userId && resultActivities
                .last?.action == activity.action && resultActivities.last?.file?.id == activity.file?.id
            if !ignoredActivityIds.contains(activity.id) && !ignoreActivity {
                var i = index + 1
                var mergedFilesTemp = [activity.fileId: activity.file]
                while i < activities.count && activities[i].createdAt.distance(to: activity.createdAt) <= mergeFileCreateDelay {
                    if activity.userId == activities[i].userId && activity.action == activities[i].action && activity.file?
                        .type == activities[i].file?.type {
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

    override func getLayout(for style: ListStyle, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
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
