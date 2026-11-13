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
protocol CrossDriveImportTrackable: AnyObject {
    func register(importId: Int, fileName: String, destinationDriveId: Int, destinationFolderId: Int, userId: Int)
    func reconcilePendingImports()
}

final class CrossDriveImportTracker: CrossDriveImportTrackable {
    private struct PendingImport: Codable, Equatable {
        let importId: Int
        let fileName: String
        let destinationDriveId: Int
        let destinationFolderId: Int
        let userId: Int
    }

    private enum ImportOutcome {
        case success
        case failure
    }

    private static let pendingImportsKey = "crossDrivePendingImports"
    private static let maxReconciliationPageCount = 5

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
            Task { @MainActor in
                self?.handleExternalImportUpdate(notification)
            }
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

    func reconcilePendingImports() {
        guard !pendingImports.isEmpty else { return }
        Task {
            await reconcilePendingImportsByDrive()
        }
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

        guard let outcome = outcome(for: action) else { return }
        finalizePendingImport(pendingImport: pendingImports[pendingIndex], outcome: outcome)
    }

    @MainActor private func outcome(for action: ExternalImportAction) -> ImportOutcome? {
        switch action {
        case .importFinish, .importFinished:
            return .success
        case .cancel, .importCanceled, .importErrored:
            return .failure
        default:
            return nil
        }
    }

    @MainActor private func reconcilePendingImportsByDrive() async {
        @InjectService var accountManager: AccountManageable
        let pendingGroups = Dictionary(grouping: pendingImports) { pendingImport in
            "\(pendingImport.userId)-\(pendingImport.destinationDriveId)"
        }

        for pendingGroup in pendingGroups.values {
            await reconcile(pendingGroup: pendingGroup, accountManager: accountManager)
        }
    }

    @MainActor private func reconcile(pendingGroup: [PendingImport], accountManager: AccountManageable) async {
        guard let firstPendingImport = pendingGroup.first,
              let driveFileManager = accountManager.getDriveFileManager(
                  for: firstPendingImport.destinationDriveId,
                  userId: firstPendingImport.userId
              ) else { return }

        var unlistedPendingImports = pendingGroup
        var listedImportIds = Set<Int>()
        var scannedEveryPage = false
        var page = 1

        while !unlistedPendingImports.isEmpty, page <= Self.maxReconciliationPageCount {
            guard let response = try? await driveFileManager.apiFetcher.externalImports(
                drive: driveFileManager.drive,
                page: page
            ) else {
                return
            }

            for serverImport in response.validApiResponse.data {
                guard let status = serverImport.status,
                      let pendingIndex = unlistedPendingImports
                      .firstIndex(where: { $0.importId == serverImport.id }) else { continue }
                listedImportIds.insert(serverImport.id)

                switch status {
                case .done:
                    finalizePendingImport(pendingImport: unlistedPendingImports[pendingIndex], outcome: .success)
                case .failed, .canceled:
                    finalizePendingImport(pendingImport: unlistedPendingImports[pendingIndex], outcome: .failure)
                default:
                    break
                }
            }
            unlistedPendingImports.removeAll { listedImportIds.contains($0.importId) }

            guard page < response.validApiResponse.pages ?? page else {
                scannedEveryPage = true
                break
            }
            page += 1
        }

        if scannedEveryPage {
            pendingImports.removeAll { unlistedPendingImports.contains($0) }
        }
    }

    @MainActor private func finalizePendingImport(pendingImport: PendingImport, outcome: ImportOutcome) {
        guard let index = pendingImports
            .firstIndex(where: { $0.importId == pendingImport.importId && $0.userId == pendingImport.userId }) else {
            return
        }
        pendingImports.remove(at: index)

        switch outcome {
        case .success:
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.copyToDriveDoneSnackbar(pendingImport.fileName))
        case .failure:
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.copyToDriveErrorSnackbar(pendingImport.fileName))
        }
    }
}
#endif
