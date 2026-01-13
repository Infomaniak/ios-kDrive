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

import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import RealmSwift
import SwiftRegex
import UIKit

public extension AppRouter {
    @discardableResult
    func processPublicShareLink(_ link: PublicShareLink) async -> Bool {
        let apiFetcher = PublicShareApiFetcher()
        do {
            let metadata = try await apiFetcher.getMetadata(driveId: link.driveId, shareLinkUid: link.shareLinkUid)

            return await processPublicShareMetadata(
                metadata,
                driveId: link.driveId,
                shareLinkUid: link.shareLinkUid,
                folderId: link.folderId,
                fileId: link.fileId,
                apiFetcher: apiFetcher
            )
        } catch {
            guard let apiError = error as? ApiError else {
                return false
            }

            guard let limitation = PublicShareLimitation(rawValue: apiError.code) else {
                return false
            }

            return await processPublicShareMetadataLimitation(limitation, publicShareURL: link.publicShareURL)
        }
    }

    private func processPublicShareMetadataLimitation(_ limitation: PublicShareLimitation,
                                                      publicShareURL: URL?) async -> Bool {
        @InjectService var appNavigable: AppNavigable
        @InjectService var matomo: MatomoUtils
        switch limitation {
        case .passwordProtected:
            guard let publicShareURL else {
                return false
            }
            matomo.track(eventWithCategory: .deeplink, name: "publicShareWithPassword")
            await appNavigable.presentPublicShareLocked(publicShareURL)
        case .expired:
            matomo.track(eventWithCategory: .deeplink, name: "publicShareExpired")
            await appNavigable.presentPublicShareExpired()
        }

        return true
    }

    private func processPublicShareMetadata(_ metadata: PublicShareMetadata,
                                            driveId: Int,
                                            shareLinkUid: String,
                                            folderId: Int?,
                                            fileId: Int?,
                                            apiFetcher: PublicShareApiFetcher) async -> Bool {
        @InjectService var accountManager: AccountManageable
        @InjectService var matomo: MatomoUtils

        matomo.track(eventWithCategory: .deeplink, name: "publicShare")

        if let driveFileManager = try? accountManager.getFirstMatchingDriveFileManager(for: accountManager.currentUserId, driveId: driveId) {
            try? await driveFileManager.switchDriveAndReloadUI()
            await showMainViewController(driveFileManager: driveFileManager, selectedIndex: MainTabBarIndex.files.rawValue)

            let fileActionsHelper = await FileActionsHelper()
            await fileActionsHelper.openFile(id: fileId ?? metadata.fileId, driveFileManager: driveFileManager, office: false)
        } else {
            guard let publicShareDriveFileManager = accountManager.getInMemoryDriveFileManager(
                for: shareLinkUid,
                driveId: driveId,
                metadata: metadata
            ) else {
                return false
            }

            openPublicShare(driveId: driveId,
                            linkUuid: shareLinkUid,
                            folderId: folderId,
                            fileId: fileId ?? metadata.fileId,
                            driveFileManager: publicShareDriveFileManager,
                            apiFetcher: apiFetcher)
        }

        return true
    }

    private func openPublicShare(driveId: Int,
                                 linkUuid: String,
                                 folderId: Int?,
                                 fileId: Int,
                                 driveFileManager: DriveFileManager,
                                 apiFetcher: PublicShareApiFetcher) {
        Task {
            do {
                let publicShare: File
                if let folderId {
                    publicShare = try await apiFetcher.getShareLinkFile(driveId: driveId,
                                                                        linkUuid: linkUuid,
                                                                        fileId: folderId)
                } else {
                    publicShare = try await apiFetcher.getShareLinkFileWithThumbnail(driveId: driveId,
                                                                                     linkUuid: linkUuid,
                                                                                     fileId: fileId)
                }

                @InjectService var appNavigable: AppNavigable
                let publicShareProxy = PublicShareProxy(driveId: driveId, fileId: fileId, shareLinkUid: linkUuid)

                if publicShare.isDirectory {
                    // Root folder must be in database for the FileListViewModel to work
                    try driveFileManager.database.writeTransaction { writableRealm in
                        writableRealm.add(publicShare, update: .modified)
                    }

                    let frozenRootFolder = publicShare.freeze()
                    await appNavigable.presentPublicShare(
                        frozenRootFolder: frozenRootFolder,
                        previewFileId: (folderId != nil) ? fileId : nil,
                        publicShareProxy: publicShareProxy,
                        driveFileManager: driveFileManager,
                        apiFetcher: apiFetcher
                    )
                } else {
                    let virtualRoot = File(id: DriveFileManager.constants.rootID,
                                           name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
                                           driveId: nil,
                                           visibility: nil)

                    virtualRoot.children.insert(publicShare)

                    // Folder structure must be in database
                    try driveFileManager.database.writeTransaction { writableRealm in
                        writableRealm.add(virtualRoot, update: .modified)
                        writableRealm.add(publicShare, update: .modified)
                    }

                    let frozenRootFolder = virtualRoot.freeze()
                    let frozenPublicShareFile = publicShare.freeze()
                    await appNavigable.presentPublicShare(
                        singleFrozenFile: frozenPublicShareFile,
                        virtualFrozenRootFolder: frozenRootFolder,
                        publicShareProxy: publicShareProxy,
                        driveFileManager: driveFileManager,
                        apiFetcher: apiFetcher
                    )
                }

            } catch {
                DDLogError(
                    "[AppRouter+PublicShare] Failed to get public folder [driveId:\(driveId) linkUuid:\(linkUuid) fileId:\(fileId)]: \(error)"
                )
                await UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
    }
}
