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
    func addToQueue(uploadFile: UploadFile,
                    itemIdentifier: NSFileProviderItemIdentifier?) -> UploadOperation?

    func suspendAllOperations()

    func resumeAllOperations()

    /// Wait for all (started or not) enqueued operations to finish.
    func waitForCompletion(_ completionHandler: @escaping () -> Void)

    func cancelAllOperations(uploadingFilesIds: [String])

    /// Mark all running `UploadOperation` as rescheduled, and terminate gracefully
    ///
    /// Takes more time than `cancel`, yet prefer it over a `cancel` for the sake of consistency.
    /// Further uploads will start from the mail app
    func rescheduleRunningOperations()

    /// Cancel all running operations, regardless of state
    func cancelRunningOperations()

    func cancel(uploadFileId: String)

    func addToQueueIfNecessary(uploadFile: UploadFile, itemIdentifier: NSFileProviderItemIdentifier?)

    var operationCount: Int { get }

    var isSuspended: Bool { get }

    var uploadFileQuery: String? { get }
}
