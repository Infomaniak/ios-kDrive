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

import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import InfomaniakDI
import RealmSwift
import Sentry

/// An abstract NSOperation
public protocol Operationable: AnyObject {
    func start()
    func main()
    var isCancelled: Bool { get }
    func cancel()
    var isExecuting: Bool { get }
    var isFinished: Bool { get }
    var isConcurrent: Bool { get }
    var isAsynchronous: Bool { get }
    var isReady: Bool { get }
    func addDependency(_ op: Operation)
    func removeDependency(_ op: Operation)
    var dependencies: [Operation] { get }
    var queuePriority: Operation.QueuePriority { get set }
    var completionBlock: (() -> Void)? { get set }
    func waitUntilFinished()
    var threadPriority: Double { get }
    var qualityOfService: QualityOfService { get }
    var name: String? { get }
}

/// An abstract Upload Operation
extension Operation: Operationable {}

/// Something that can upload a file.
public protocol UploadOperationable: Operationable {
    /// init an UploadOperationable
    /// - Parameters:
    ///   - uploadFileId: the identifier of the UploadFile in base
    ///   - urlSession: the url session to use
    ///   - itemIdentifier: the itemIdentifier
    init(uploadFileId: String,
         urlSession: URLSession,
         itemIdentifier: NSFileProviderItemIdentifier?)

    /// Network completion handler
    func uploadCompletion(data: Data?, response: URLResponse?, error: Error?)

    /// Clean the local session and cancel running upload chunk operations.
    /// - Parameter file: An UploadFile within a transaction
    func cleanUploadFileSession(file: UploadFile?)

    /// Process errors and terminate the operation
    func end()

    var result: UploadCompletionResult { get }
}
