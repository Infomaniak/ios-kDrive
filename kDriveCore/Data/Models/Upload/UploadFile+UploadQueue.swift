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

extension UploadFile {
    @InjectService(customTypeIdentifier: UploadQueueID.photo) static var photoUploadQueue: UploadQueueable
    @InjectService(customTypeIdentifier: UploadQueueID.global) static var globalUploadQueue: UploadQueueable

    var uploadQueue: UploadQueueable {
        if isPhotoSyncUpload {
            return Self.photoUploadQueue
        } else {
            return Self.globalUploadQueue
        }
    }
}
