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

class RecentActivitySharedController: RecentActivityDelegate {

    let driveFileManager: DriveFileManager
    let filePresenter: FilePresenter

    var recentActivities = [FileActivity]()
    var nextPage = 1
    var hasNextPage = true
    var isLoading = true

    var shouldLoadMore: Bool {
        return hasNextPage && !isLoading
    }

    private let mergeFileCreateDelay = 43_200 // 12h
    private var isInvalidated = false

    init(driveFileManager: DriveFileManager, filePresenter: FilePresenter) {
        self.driveFileManager = driveFileManager
        self.filePresenter = filePresenter
    }

    func invalidate() {
        isInvalidated = true
    }

    func prepareForReload() {
        nextPage = 1
        hasNextPage = true
        recentActivities.removeAll()
    }

    func loadLocalRecentActivities(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let activities = self.driveFileManager.getLocalRecentActivities()
            self.recentActivities = self.mergeAndClean(activities: activities)
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    func loadNextRecentActivities(completion: @escaping (Error?) -> Void) {
        isLoading = true
        let replace = nextPage == 1
        driveFileManager.apiFetcher.getRecentActivity(page: nextPage) { (response, error) in
            guard !self.isInvalidated else {
                return
            }

            if let activities = response?.data {
                DispatchQueue.global(qos: .utility).async {
                    let mergedActivities = self.mergeAndClean(activities: activities)
                    if replace {
                        self.recentActivities = mergedActivities
                    } else {
                        self.recentActivities += mergedActivities
                    }
                    DispatchQueue.main.async {
                        // Update page info
                        self.nextPage += 1
                        self.hasNextPage = activities.count == DriveApiFetcher.itemPerPage
                        self.isLoading = false
                        completion(nil)
                    }
                }
                // Update cache
                if self.nextPage == 1 {
                    self.driveFileManager.setLocalRecentActivities(activities)
                }
            } else {
                self.loadLocalRecentActivities {
                    completion(nil)
                }
            }
        }
    }

    private func mergeAndClean(activities: [FileActivity]) -> [FileActivity] {
        let activities = activities.filter { $0.user != nil }

        var resultActivities = [FileActivity]()
        var ignoredActivityIds = [Int]()

        for (index, activity) in activities.enumerated() {
            let ignoreActivity = resultActivities.count > 0 && resultActivities.last?.user?.id == activity.user?.id && resultActivities.last?.action == activity.action && resultActivities.last?.file?.id == activity.file?.id
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

    // MARK: - Recent activity delegate

    func didSelectActivity(index: Int, activities: [FileActivity]) {
        let activity = activities[index]
        guard let file = activity.file else {
            UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorPreviewDeleted)
            return
        }

        if activities.count > 3 && index > 1 {
            let nextVC = RecentActivityFilesViewController.instantiate(activities: activities, driveFileManager: driveFileManager)
            filePresenter.navigationController?.pushViewController(nextVC, animated: true)
        } else {
            filePresenter.present(driveFileManager: driveFileManager, file: file, files: activities.compactMap(\.file), normalFolderHierarchy: false)
        }
    }
}
