/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

enum PHAssetUploadError: Error {
    case unableToFetch
    case unableToGetURL
}

extension UploadOperation {
    func getPhAssetIfNeeded() async throws {
        Log.uploadOperation("getPhAssetIfNeeded ufid:\(uploadFileId)")
        try checkCancelation()
        let file = try readOnlyFile()

        guard file.type == .phAsset else {
            // This UploadFile is not a PHAsset, return silently
            return
        }

        guard let asset = file.getPHAsset() else {
            Log.uploadOperation(
                "Unable to fetch PHAsset ufid:\(uploadFileId) assetLocalIdentifier:\(String(describing: file.assetLocalIdentifier)) ",
                level: .error
            )
            SentryDebug.capturePHAssetResourceManagerError(PHAssetUploadError.unableToFetch)
            // This UploadFile is not a PHAsset, return silently
            return
        }

        // Check if we are not restarting a session for an already imported asset
        if let existingFileURL = file.pathURL,
           fileManager.fileExists(atPath: existingFileURL.path) {
            return
        }

        // Async load the url of the asset
        guard let url = await photoLibraryUploader.getUrl(for: asset) else {
            Log.uploadOperation("Failed to get photo asset URL ufid:\(uploadFileId)", level: .error)
            SentryDebug.capturePHAssetResourceManagerError(PHAssetUploadError.unableToGetURL)
            return
        }

        // Save asset file URL to DB
        Log.uploadOperation("Got photo asset, writing URL:\(url) ufid:\(uploadFileId)")
        try transactionWithFile { file in
            file.pathURL = url
        }
    }

    func checkForRestrictedUploadOverDataMode() throws {
        let file = try readOnlyFile()

        guard file.isPhotoSyncUpload else {
            return
        }

        let status = ReachabilityListener.instance.currentStatus
        let canUpload = !(status == .cellular && photoLibraryUploader.isWifiOnly)

        guard !canUpload else {
            return
        }
        throw ErrorDomain.uploadOverDataRestrictedError
    }
}
