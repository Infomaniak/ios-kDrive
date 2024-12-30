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

import CocoaLumberjackSwift
import FileProvider
import Foundation
import InfomaniakCore
import InfomaniakDI

public final class DownloadPublicShareArchiveOperation: DownloadArchiveOperation {
    private let publicShareProxy: PublicShareProxy

    public init(archiveId: String,
                shareDrive: AbstractDrive,
                driveFileManager: DriveFileManager,
                urlSession: FileDownloadSession,
                publicShareProxy: PublicShareProxy) {
        self.publicShareProxy = publicShareProxy
        super.init(archiveId: archiveId, shareDrive: shareDrive, driveFileManager: driveFileManager, urlSession: urlSession)
    }

    override public init(archiveId: String,
                         shareDrive: AbstractDrive,
                         driveFileManager: DriveFileManager,
                         urlSession: FileDownloadSession) {
        fatalError("Unavailable")
    }

    override public func main() {
        publicShareDownload()
    }

    func publicShareDownload() {
        DDLogInfo(
            "[DownloadPublicShareArchiveOperation] Downloading Archive of public share files \(archiveId) with session \(urlSession.identifier)"
        )

        let url = Endpoint.downloadPublicShareArchive(
            drive: shareDrive,
            linkUuid: publicShareProxy.shareLinkUid,
            archiveUuid: archiveId
        ).url
        let request = URLRequest(url: url)

        task = urlSession.downloadTask(with: request, completionHandler: downloadCompletion)
        progressObservation = task?.progress.observe(\.fractionCompleted, options: .new) { _, value in
            guard let newValue = value.newValue else {
                return
            }
            DownloadQueue.instance.publishProgress(newValue, for: self.archiveId)
        }
        task?.resume()
    }
}
