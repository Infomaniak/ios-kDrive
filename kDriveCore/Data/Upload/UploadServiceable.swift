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

public enum UploadQueueID {
    public static let global = "global"
    public static let photo = "photo"
}

public protocol UploadServiceable {
    /// True if all upload queues are suspended
    var isSuspended: Bool { get }

    /// Sum of all operations in all the queues
    var operationCount: Int { get }

    /// Read database to enqueue all non finished upload tasks.
    func rebuildUploadQueueFromObjectsInRealm()

    func suspendAllOperations()

    func resumeAllOperations()

    /// Wait for all (started or not) enqueued operations to finish.
    func waitForCompletion(_ completionHandler: @escaping () -> Void)

    // Retry to upload a specific file, this re-enqueue the task.
    func retry(_ uploadFileId: String)

    // Retry all uploads within a specified graph, this re-enqueue the tasks.
    func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int)

    func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int)

    /// Mark all running `UploadOperation` as rescheduled, and terminate gracefully
    ///
    /// Takes more time than `cancel`, yet prefer it over a `cancel` for the sake of consistency.
    /// Further uploads will start from the mail app
    func rescheduleRunningOperations()

    /// Cancel all running operations, regardless of state
    func cancelRunningOperations()

    /// Cancel an upload from an UploadFile.id. The UploadFile is removed and a matching operation is removed.
    /// - Parameter uploadFileId: the upload file id to cancel.
    /// - Returns: true if fileId matched
    @discardableResult func cancel(uploadFileId: String) -> Bool

    /// Clean errors linked to any upload operation in base. Does not restart the operations.
    ///
    /// Also make sure that UploadFiles initiated in FileManager will restart at next retry.
    func cleanNetworkAndLocalErrorsForAllOperations()
}
