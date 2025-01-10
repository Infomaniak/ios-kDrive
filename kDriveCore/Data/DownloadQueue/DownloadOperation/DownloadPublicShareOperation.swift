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
import InfomaniakCoreDB
import InfomaniakDI
import InfomaniakLogin

public final class DownloadPublicShareOperation: DownloadAuthenticatedOperation, @unchecked Sendable {
    private let publicShareProxy: PublicShareProxy

    override public init(
        file: File,
        driveFileManager: DriveFileManager,
        urlSession: FileDownloadSession,
        itemIdentifier: NSFileProviderItemIdentifier? = nil
    ) {
        fatalError("Unavailable")
    }

    public init(
        file: File,
        driveFileManager: DriveFileManager,
        urlSession: FileDownloadSession,
        publicShareProxy: PublicShareProxy,
        itemIdentifier: NSFileProviderItemIdentifier? = nil
    ) {
        self.publicShareProxy = publicShareProxy
        super.init(file: file,
                   driveFileManager: driveFileManager,
                   urlSession: urlSession,
                   itemIdentifier: itemIdentifier)
    }

    override public func main() {
        DDLogInfo("[DownloadPublicShareOperation] Start for \(file.id) with session \(urlSession.identifier)")

        downloadPublicShareFile(publicShareProxy: publicShareProxy)
    }

    private func downloadPublicShareFile(publicShareProxy: PublicShareProxy) {
        DDLogInfo("[DownloadPublicShareOperation] Downloading publicShare \(file.id) with session \(urlSession.identifier)")

        let url = Endpoint.download(file: file, publicShareProxy: publicShareProxy).url

        // Add download task to Realm
        let downloadTask = DownloadTask(
            fileId: file.id,
            isDirectory: file.isDirectory,
            driveId: file.driveId,
            userId: driveFileManager.drive.userId,
            sessionId: urlSession.identifier,
            sessionUrl: url.absoluteString
        )

        try? uploadsDatabase.writeTransaction { writableRealm in
            writableRealm.add(downloadTask, update: .modified)
        }

        let request = URLRequest(url: url)
        downloadRequest(request)
    }
}
