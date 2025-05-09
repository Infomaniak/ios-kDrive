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
    var isSuspended: Bool { get }

    var operationCount: Int { get }

    func blockingRebuildUploadQueue()

    func rebuildUploadQueue()

    func suspendAllOperations()

    func resumeAllOperations()

    func waitForCompletion(_ completionHandler: @escaping () -> Void)

    func retry(_ uploadFileId: String)

    func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int)

    func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int)

    func cancelAnyPhotoSync() async throws

    func rescheduleRunningOperations()

    @discardableResult func cancel(uploadFileId: String) -> Bool

    func cleanNetworkAndLocalErrorsForAllOperations()

    func updateQueueSuspension()
}
