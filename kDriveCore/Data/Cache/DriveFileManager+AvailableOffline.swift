/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

public extension DriveFileManager {
    func getAvailableOfflineFiles(sortType: SortType = .nameAZ) -> [File] {
        let offlineFiles = getRealm().objects(File.self)
            .filter(NSPredicate(format: "isAvailableOffline = true"))
            .sorted(by: [sortType.value.sortDescriptor]).freeze()

        return offlineFiles.map { $0.freeze() }
    }

    func updateAvailableOfflineFiles() async throws {
        let offlineFiles = getAvailableOfflineFiles()
        guard !offlineFiles.isEmpty else { return }
        let date = Date(timeIntervalSince1970: TimeInterval(UserDefaults.shared.lastSyncDateOfflineFiles))
        // Get activities
        let filesActivities = try await filesActivities(files: offlineFiles, from: date)
        for activities in filesActivities {
            guard let file = offlineFiles.first(where: { $0.id == activities.id }) else {
                continue
            }

            if activities.result {
                try applyActivities(activities, offlineFile: file)
            } else if let message = activities.message {
                handleError(message: message, offlineFile: file)
            }
        }
    }

    func filesActivities(files: [File], from date: Date) async throws -> [ActivitiesForFile] {
        let response = try await apiFetcher.filesActivities(drive: drive, files: files.map { $0.proxify() }, from: date)
        // Update last sync date
        if let responseAt = response.validApiResponse.responseAt {
            UserDefaults.shared.lastSyncDateOfflineFiles = responseAt
        }
        return response.validApiResponse.data
    }

    private func applyActivities(_ activities: ActivitiesForFile, offlineFile file: File) throws {
        // Update file in Realm & rename if needed
        if let newFile = activities.file {
            let realm = getRealm()
            keepCacheAttributesForFile(newFile: newFile, keepProperties: [.standard, .extras], using: realm)
            _ = try updateFileInDatabase(updatedFile: newFile, oldFile: file, using: realm)
        }
        // Apply activities to file
        var handledActivities = Set<FileActivityType>()
        for activity in activities.activities where activity.action != nil && !handledActivities.contains(activity.action!) {
            if activity.action == .fileUpdate {
                // Download new version
                DownloadQueue.instance.addToQueue(file: file, userId: drive.userId)
            }
            handledActivities.insert(activity.action!)
        }
    }
}
