/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import kDriveResources
import UIKit

#if !ISEXTENSION
protocol CrossDriveImportTrackable: AnyObject {
    func register(importId: Int, fileName: String, destinationDriveId: Int, destinationFolderId: Int, userId: Int)
}

final class CrossDriveImportTracker: CrossDriveImportTrackable {
    private struct PendingImport: Codable {
        let importId: Int
        let fileName: String
        let destinationDriveId: Int
        let destinationFolderId: Int
        let userId: Int
    }

    private static let pendingImportsKey = "crossDrivePendingImports"

    private var pendingImports: [PendingImport] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.pendingImportsKey) else { return [] }
            return (try? JSONDecoder().decode([PendingImport].self, from: data)) ?? []
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: Self.pendingImportsKey)
        }
    }

    init() {
        NotificationCenter.default.addObserver(
            forName: .externalImportDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleExternalImportUpdate(notification)
        }
    }

    func register(importId: Int, fileName: String, destinationDriveId: Int, destinationFolderId: Int, userId: Int) {
        let pendingImport = PendingImport(importId: importId,
                                          fileName: fileName,
                                          destinationDriveId: destinationDriveId,
                                          destinationFolderId: destinationFolderId,
                                          userId: userId)
        pendingImports.append(pendingImport)
    }

    @MainActor private func handleExternalImportUpdate(_ notification: Notification) {
        guard let importId = notification.userInfo?["importId"] as? Int,
              let userId = notification.userInfo?["userId"] as? Int,
              let action = notification.userInfo?["action"] as? ExternalImportAction,
              action.isTerminal,
              let pendingIndex = pendingImports
              .firstIndex(where: { $0.importId == importId && $0.userId == userId }) else {
            return
        }

        guard UIApplication.shared.applicationState == .active else { return }

        let pendingImport = pendingImports[pendingIndex]
        pendingImports.remove(at: pendingIndex)
        switch action {
        case .importFinish, .importFinished:
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.copyToDriveDoneSnackbar(pendingImport.fileName))
        case .cancel, .importCanceled, .importErrored:
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.copyToDriveErrorSnackbar(pendingImport.fileName))
        default:
            break
        }
    }
}
#endif
