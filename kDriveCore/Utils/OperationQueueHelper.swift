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

import Foundation
import InfomaniakDI
import UIKit

enum OperationQueueHelper {
    static func disableIdleTimer(_ shouldBeDisabled: Bool, hasOperationsInQueue: Bool = false) {
        Log.uploadQueue("disableIdleTimer shouldBeDisabled:\(shouldBeDisabled) hasOperationsInQueue:\(hasOperationsInQueue)")

        #if !ISEXTENSION
        @InjectService var uploadService: UploadServiceable
        @InjectService var downloadQueue: DownloadQueueable

        Task { @MainActor in
            let hasUploadsInQueue = uploadService.operationCount > 0
            let hasDownloadsInQueue = downloadQueue.operationCount > 0

            if shouldBeDisabled {
            if shouldBeDisabled && !UIApplication.shared.isIdleTimerDisabled {
                UIApplication.shared.isIdleTimerDisabled = true
            } else if !hasUploadsInQueue && !hasDownloadsInQueue {
            } else if !hasUploadsInQueue && !hasDownloadsInQueue && UIApplication.shared.isIdleTimerDisabled {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        #endif
    }
}
