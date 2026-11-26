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
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

#if !ISEXTENSION
/// Tracks cross-drive file copies and reports their outcome to the user,
/// surviving app restarts until every import reaches a terminal state.
protocol CrossDriveImportTrackable: Sendable {
    func register(importId: Int, fileName: String, destinationDriveId: Int, destinationFolderId: Int, userId: Int) async
    func reconcilePendingImports() async
}

actor CrossDriveImportTracker: CrossDriveImportTrackable {
    private struct ImportKey: Hashable, Sendable {
        let importId: Int
        let userId: Int
    }

    private struct PendingImport: Codable, Equatable, Sendable {
        let importId: Int
        let fileName: String
        let destinationDriveId: Int
        let destinationFolderId: Int
        let userId: Int

        var key: ImportKey {
            ImportKey(importId: importId, userId: userId)
        }
    }

    private enum ImportOutcome {
        case success
        case failure
    }

    private static let pendingImportsKey = "crossDrivePendingImports"

    private var pendingImports: [ImportKey: PendingImport]
    private var notificationToken: (any NSObjectProtocol)?

    init() {
        pendingImports = Self.loadStoredPendingImports()
        notificationToken = NotificationCenter.default.addObserver(
            forName: .externalImportDidUpdate,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            Task {
                await self?.handleExternalImportUpdate(notification)
            }
        }
    }

    deinit {
        if let notificationToken {
            NotificationCenter.default.removeObserver(notificationToken)
        }
    }

    func register(importId: Int, fileName: String, destinationDriveId: Int, destinationFolderId: Int, userId: Int) async {
        let pendingImport = PendingImport(importId: importId,
                                          fileName: fileName,
                                          destinationDriveId: destinationDriveId,
                                          destinationFolderId: destinationFolderId,
                                          userId: userId)
        pendingImports[pendingImport.key] = pendingImport
        persistPendingImports()

        Task {
            await reconcilePendingImports()
        }
    }

    func reconcilePendingImports() async {
        guard !pendingImports.isEmpty else { return }
        await reconcilePendingImportsByDrive()
    }

    private func handleExternalImportUpdate(_ notification: Notification) async {
        guard let importId = notification.userInfo?["importId"] as? Int,
              let userId = notification.userInfo?["userId"] as? Int,
              let action = notification.userInfo?["action"] as? ExternalImportAction,
              action.isTerminal else {
            return
        }

        let key = ImportKey(importId: importId, userId: userId)
        guard pendingImports[key] != nil else { return }
        guard let outcome = outcome(for: action) else { return }
        let isApplicationActive = await MainActor.run { UIApplication.shared.applicationState == .active }
        guard isApplicationActive else { return }

        await finalizePendingImport(key: key, outcome: outcome)
    }

    private func outcome(for action: ExternalImportAction) -> ImportOutcome? {
        switch action {
        case .importFinish, .importFinished:
            return .success
        case .cancel, .importCanceled, .importErrored:
            return .failure
        default:
            return nil
        }
    }

    private func reconcilePendingImportsByDrive() async {
        @InjectService var accountManager: AccountManageable
        let pendingGroups = Dictionary(grouping: pendingImports.values) { pendingImport in
            "\(pendingImport.userId)-\(pendingImport.destinationDriveId)"
        }

        for pendingGroup in pendingGroups.values {
            await reconcile(pendingGroup: pendingGroup, accountManager: accountManager)
        }
    }

    private func reconcile(pendingGroup: [PendingImport], accountManager: AccountManageable) async {
        guard let firstPendingImport = pendingGroup.first,
              let driveFileManager = accountManager.getDriveFileManager(
                  for: firstPendingImport.destinationDriveId,
                  userId: firstPendingImport.userId
              ) else { return }

        let userId = firstPendingImport.userId
        var unlistedImportIds = Set(pendingGroup.map(\.importId))
        var scannedEveryPage = false
        var page = 1

        while !unlistedImportIds.isEmpty {
            guard let response = try? await driveFileManager.apiFetcher.externalImports(
                drive: driveFileManager.drive,
                page: page
            ) else {
                return
            }

            for serverImport in response.validApiResponse.data {
                guard let status = serverImport.status else { continue }
                unlistedImportIds.remove(serverImport.id)

                let key = ImportKey(importId: serverImport.id, userId: userId)
                guard pendingImports[key] != nil else { continue }

                switch status {
                case .done:
                    await finalizePendingImport(key: key, outcome: .success)
                case .failed, .canceled:
                    await finalizePendingImport(key: key, outcome: .failure)
                default:
                    break
                }
            }

            guard page < response.validApiResponse.pages ?? page else {
                scannedEveryPage = true
                break
            }
            page += 1
        }

        if scannedEveryPage {
            for importId in unlistedImportIds {
                pendingImports.removeValue(forKey: ImportKey(importId: importId, userId: userId))
            }
            persistPendingImports()
        }
    }

    private func finalizePendingImport(key: ImportKey, outcome: ImportOutcome) async {
        guard let pendingImport = pendingImports.removeValue(forKey: key) else {
            return
        }
        persistPendingImports()

        switch outcome {
        case .success:
            await UIConstants.showSnackBar(
                message: KDriveResourcesStrings.Localizable.copyToDriveDoneSnackbar(pendingImport.fileName)
            )
        case .failure:
            await UIConstants.showSnackBar(
                message: KDriveResourcesStrings.Localizable.copyToDriveErrorSnackbar(pendingImport.fileName)
            )
        }
    }

    private func persistPendingImports() {
        UserDefaults.standard.set(try? JSONEncoder().encode(Array(pendingImports.values)), forKey: Self.pendingImportsKey)
    }

    private static func loadStoredPendingImports() -> [ImportKey: PendingImport] {
        guard let data = UserDefaults.standard.data(forKey: pendingImportsKey),
              let storedImports = try? JSONDecoder().decode([PendingImport].self, from: data) else {
            return [:]
        }
        return storedImports.reduce(into: [ImportKey: PendingImport]()) { $0[$1.key] = $1 }
    }
}
#endif
