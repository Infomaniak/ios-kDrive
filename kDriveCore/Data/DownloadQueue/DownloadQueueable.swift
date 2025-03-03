//
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

import FileProvider
import Foundation
import InfomaniakCore
import RealmSwift
import UIKit

public typealias DownloadedFileId = Int
public typealias DownloadedArchiveId = String

public protocol DownloadQueueable {
    func addPublicShareToQueue(file: File,
                               driveFileManager: DriveFileManager,
                               publicShareProxy: PublicShareProxy,
                               itemIdentifier: NSFileProviderItemIdentifier?,
                               onOperationCreated: ((DownloadPublicShareOperation?) -> Void)?,
                               completion: ((DriveError?) -> Void)?)

    func addToQueue(file: File,
                    userId: Int,
                    itemIdentifier: NSFileProviderItemIdentifier?)

    func addPublicShareArchiveToQueue(archiveId: String,
                                      driveFileManager: DriveFileManager,
                                      publicShareProxy: PublicShareProxy)

    func addToQueue(archiveId: String, driveId: Int, userId: Int)

    func temporaryDownload(file: File,
                           userId: Int,
                           onOperationCreated: ((DownloadAuthenticatedOperation?) -> Void)?,
                           completion: @escaping (DriveError?) -> Void)

    func suspendAllOperations()

    func resumeAllOperations()

    func cancelAllOperations()

    func cancelArchiveOperation(for archiveId: String)

    func cancelFileOperation(for fileId: Int)

    func operation(for fileId: Int) -> DownloadFileOperationable?

    func archiveOperation(for archiveId: String) -> DownloadArchiveOperation?

    func hasOperation(for fileId: Int) -> Bool

    func observeFileDownloaded<T: AnyObject>(_ observer: T,
                                             fileId: Int?,
                                             using closure: @escaping (DownloadedFileId, DriveError?) -> Void) -> ObservationToken

    func observeArchiveDownloaded<T: AnyObject>(_ observer: T,
                                                archiveId: String?,
                                                using closure: @escaping (DownloadedArchiveId, URL?, DriveError?) -> Void) -> ObservationToken

    func observeFileDownloadProgress<T: AnyObject>(_ observer: T,
                                                   fileId: Int?,
                                                   using closure: @escaping (DownloadedFileId, Double) -> Void) -> ObservationToken

    func publishProgress(_ progress: Double, for archiveId: String)

    func publishProgress(_ progress: Double, for fileId: Int)

    func observeArchiveDownloadProgress<T: AnyObject>(
        _ observer: T,
        archiveId: String?,
        using closure: @escaping (String, Double) -> Void
    )
        -> ObservationToken
}
