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

import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import InfomaniakDI
import kDriveResources
import SwiftRegex
import UIKit

public enum UniversalLinksHelper {
    private struct Link {
        let regex: Regex
        let displayMode: DisplayMode

        /// Matches a private share link
        static let privateShareLink = Link(
            regex: Regex(pattern: #"^/app/drive/([0-9]+)/redirect/([0-9]+)$"#)!,
            displayMode: .file
        )

        /// Matches a directory list link
        static let directoryLink = Link(regex: Regex(pattern: #"^/app/drive/([0-9]+)/files/([0-9]+)$"#)!, displayMode: .file)

        /// Matches a file preview link
        static let filePreview = Link(
            regex: Regex(pattern: #"^/app/drive/([0-9]+)/files/([0-9]+/)?preview/[a-z]+/([0-9]+)$"#)!,
            displayMode: .file
        )

        /// Matches an office file link
        static let officeLink = Link(regex: Regex(pattern: #"^/app/office/([0-9]+)/([0-9]+)$"#)!, displayMode: .office)

        static let all = [privateShareLink, directoryLink, filePreview, officeLink]
    }

    private enum DisplayMode {
        case office, file
    }

    @discardableResult
    public static func handleURL(_ url: URL) async -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            DDLogError("[UniversalLinksHelper] Failed to process url:\(url)")
            return false
        }

        let path = components.path
        DDLogInfo("[UniversalLinksHelper] Trying to open link with path: \(path)")

        if let publicShare = await PublicShareLink(publicShareURL: url),
           await processPublicShareLink(publicShare) {
            return true
        }

        // Common regex
        for link in Link.all {
            let matches = link.regex.matches(in: path)
            if processRegex(matches: matches, displayMode: link.displayMode) {
                return true
            }
        }

        DDLogWarn("[UniversalLinksHelper] Unable to process link with path: \(path)")
        return false
    }

    public static func processPublicShareLink(_ link: PublicShareLink) async -> Bool {
        @InjectService var deeplinkService: DeeplinkServiceable
        deeplinkService.setLastPublicShare(link)

        let apiFetcher = PublicShareApiFetcher()
        do {
            let metadata = try await apiFetcher.getMetadata(driveId: link.driveId, shareLinkUid: link.shareLinkUid)

            return await processPublicShareMetadata(
                metadata,
                driveId: link.driveId,
                shareLinkUid: link.shareLinkUid,
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

    private static func processPublicShareMetadataLimitation(_ limitation: PublicShareLimitation,
                                                             publicShareURL: URL?) async -> Bool {
        @InjectService var appNavigable: AppNavigable
        switch limitation {
        case .passwordProtected:
            guard let publicShareURL else {
                return false
            }
            MatomoUtils.trackDeeplink(name: "publicShareWithPassword")
            await appNavigable.presentPublicShareLocked(publicShareURL)
        case .expired:
            MatomoUtils.trackDeeplink(name: "publicShareExpired")
            await appNavigable.presentPublicShareExpired()
        }

        return true
    }

    private static func processPublicShareMetadata(_ metadata: PublicShareMetadata,
                                                   driveId: Int,
                                                   shareLinkUid: String,
                                                   apiFetcher: PublicShareApiFetcher) async -> Bool {
        @InjectService var accountManager: AccountManageable

        MatomoUtils.trackDeeplink(name: "publicShare")

        guard let publicShareDriveFileManager = accountManager.getInMemoryDriveFileManager(
            for: shareLinkUid,
            driveId: driveId,
            rootFileId: metadata.fileId
        ) else {
            return false
        }

        openPublicShare(driveId: driveId,
                        linkUuid: shareLinkUid,
                        fileId: metadata.fileId,
                        driveFileManager: publicShareDriveFileManager,
                        apiFetcher: apiFetcher)

        return true
    }

    private static func processRegex(matches: [[String]], displayMode: DisplayMode) -> Bool {
        @InjectService var accountManager: AccountManageable

        guard let firstMatch = matches.first,
              firstMatch.count > 2,
              let driveId = Int(firstMatch[1]),
              let last = firstMatch.last,
              let uploadFileId = Int(last),
              let driveFileManager = accountManager.getDriveFileManager(for: driveId,
                                                                        userId: accountManager.currentUserId)
        else { return false }

        openFile(id: uploadFileId, driveFileManager: driveFileManager, office: displayMode == .office)

        return true
    }

    private static func openPublicShare(driveId: Int,
                                        linkUuid: String,
                                        fileId: Int,
                                        driveFileManager: DriveFileManager,
                                        apiFetcher: PublicShareApiFetcher) {
        Task {
            do {
                let rootFolder = try await apiFetcher.getShareLinkFile(driveId: driveId,
                                                                       linkUuid: linkUuid,
                                                                       fileId: fileId)
                // Root folder must be in database for the FileListViewModel to work
                try driveFileManager.database.writeTransaction { writableRealm in
                    writableRealm.add(rootFolder)
                }

                let frozenRootFolder = rootFolder.freeze()

                @InjectService var appNavigable: AppNavigable
                let publicShareProxy = PublicShareProxy(driveId: driveId, fileId: fileId, shareLinkUid: linkUuid)
                await appNavigable.presentPublicShare(
                    frozenRootFolder: frozenRootFolder,
                    publicShareProxy: publicShareProxy,
                    driveFileManager: driveFileManager,
                    apiFetcher: apiFetcher
                )
            } catch {
                DDLogError(
                    "[UniversalLinksHelper] Failed to get public folder [driveId:\(driveId) linkUuid:\(linkUuid) fileId:\(fileId)]: \(error)"
                )
                await UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
    }

    private static func openFile(id: Int, driveFileManager: DriveFileManager, office: Bool) {
        Task {
            do {
                let file = try await driveFileManager.file(id: id)
                @InjectService var appNavigable: AppNavigable
                await appNavigable.present(file: file, driveFileManager: driveFileManager, office: office)
            } catch {
                DDLogError("[UniversalLinksHelper] Failed to get file [\(driveFileManager.drive.id) - \(id)]: \(error)")
                await UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
    }
}
