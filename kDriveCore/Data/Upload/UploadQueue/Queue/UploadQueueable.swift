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

import FileProvider
import Foundation
import RealmSwift

public protocol UploadQueueable {
    func getOperation(forUploadFileId uploadFileId: String) -> UploadOperationable?

    @discardableResult
    func addToQueue(uploadFile: UploadFile, itemIdentifier: NSFileProviderItemIdentifier?) -> UploadOperation?

    func addToQueueIfNecessary(uploadFile: UploadFile, itemIdentifier: NSFileProviderItemIdentifier?)

    func suspendAllOperations()

    func resumeAllOperations()

    func waitForCompletion(_ completionHandler: @escaping () -> Void)

    func cancelAllOperations(uploadingFilesIds: [String])

    func rescheduleRunningOperations()

    func cancel(uploadFileId: String)

    var operationCount: Int { get }

    var isSuspended: Bool { get }

    var uploadFileQuery: String? { get }
}
