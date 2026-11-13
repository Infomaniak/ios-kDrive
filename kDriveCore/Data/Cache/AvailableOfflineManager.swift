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
import InfomaniakCore
import InfomaniakDI

public protocol AvailableOfflineManageable {
    func updateAvailableOfflineFiles(status: ReachabilityListener.NetworkStatus)
}

public class AvailableOfflineManager: AvailableOfflineManageable {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var driveInfosManager: DriveInfosManager

    public init() {}

    public func updateAvailableOfflineFiles(status: ReachabilityListener.NetworkStatus) {
        Log.appDelegate("updateAvailableOfflineFiles")

        let wifiSyncOnly = UserDefaults.shared.syncOfflineMode == .onlyWifi
        guard status != .offline && (!wifiSyncOnly || status == .wifi) else {
            return
        }

        let userId = accountManager.currentUserId
        let regularDrives = Array(driveInfosManager.getDrives(for: userId, sharedWithMe: false))
        updateAvailableOfflineFiles(for: regularDrives)
        updateAvailableOfflineFiles(for: Array(driveInfosManager.getDrives(for: userId, sharedWithMe: true)))
        updateAvailableOfflineFiles(for: regularDrives, sharedContext: true)
    }

    private func updateAvailableOfflineFiles(for drives: [Drive], sharedContext: Bool = false) {
        for drive in drives {
            let frozenDrive = drive.freezeIfNeeded()
            guard let driveFileManager = accountManager.getDriveFileManager(for: frozenDrive.id, userId: drive.userId) else {
                continue
            }
            let targetManager = sharedContext ? driveFileManager.instanceWith(context: .sharedWithMe) : driveFileManager
            Task {
                do {
                    try await targetManager.updateAvailableOfflineFiles()
                } catch {
                    // Silently handle error
                    Log.appDelegate(
                        "Error while fetching offline files activities in [\(frozenDrive.id) - \(frozenDrive.name)]: \(error)",
                        level: .error
                    )
                }
            }
        }
    }
}
