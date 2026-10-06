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
import InfomaniakCore
import InfomaniakCoreDB
import InfomaniakDI
import RealmSwift
import Sentry

/// Receives notifications about upload queue emptiness and suspension.
///
/// Queue observers notify `UploadQueue`, which forwards each notification to its `queueCoordinationDelegate`.
/// The coordination delegate uses these notifications to redistribute upload parallelism and update Dynamic Island activity.
public protocol UploadQueueStateDelegate: AnyObject {
    func operationQueueBecameEmpty()
    func operationQueueNoLongerEmpty()
    func operationQueueBecameSuspended()
    func operationQueueNoLongerSuspended()
}

public class UploadQueue: ParallelismHeuristicDelegate {
    @LazyInjectService var appContextService: AppContextServiceable
    @LazyInjectService var uploadPublisher: UploadPublishable

    private var queueObserver: UploadQueueObserver?
    private var queueSuspensionObserver: UploadQueueSuspensionObserver?

    public var fileUploadedCount = 0
    public var fileUploadFailedCount = 0

    let serialEventQueue: DispatchQueue = {
        @InjectService var appContextService: AppContextServiceable
        let autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = appContextService.isExtension ? .workItem : .inherit

        return DispatchQueue(
            label: "com.infomaniak.drive.upload-service.event",
            qos: .default,
            autoreleaseFrequency: autoreleaseFrequency
        )
    }()

    static let silentErrors: [DriveError] =
        [.taskRescheduled, .taskCancelled, .uploadOverDataRestrictedError, .uploadNotTerminatedError, .uploadNotTerminated]

    private weak var queueCoordinationDelegate: UploadQueueStateDelegate?

    public var name: String {
        "kDrive base upload queue"
    }

    /// Something to track an operation for a File ID
    let keyedUploadOperations = KeyedUploadOperationable()

    public lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = self.name
        queue.qualityOfService = .userInitiated
        queue.isSuspended = shouldSuspendQueue
        return queue
    }()

    lazy var foregroundSession: URLSession = {
        let urlSessionConfiguration = URLSessionConfiguration.default
        urlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = true
        urlSessionConfiguration.allowsCellularAccess = true
        urlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        urlSessionConfiguration
            .httpMaximumConnectionsPerHost = 4 // This limit is not really respected because we are using http/2
        urlSessionConfiguration.timeoutIntervalForRequest = 60 * 2 // 2 minutes before timeout
        urlSessionConfiguration.networkServiceType = .default
        urlSessionConfiguration.httpAdditionalHeaders = ["User-Agent": Constants.userAgent]
        return URLSession(configuration: urlSessionConfiguration, delegate: nil, delegateQueue: nil)
    }()

    /// Should suspend operation queue based on network status
    var shouldSuspendQueue: Bool {
        // Explicitly disable the upload queue from the share extension
        guard appContextService.context != .shareExtension else {
            return true
        }

        let status = ReachabilityListener.instance.currentStatus
        let shouldBeSuspended = status == .offline
        return shouldBeSuspended
    }

    /// Should suspend operation queue based on explicit `suspendAllOperations()` call
    var forceSuspendQueue = false

    public init(queueCoordinationDelegate: UploadQueueStateDelegate?) {
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(self) disabled in ShareExtension", level: .error)
            return
        }

        self.queueCoordinationDelegate = queueCoordinationDelegate

        queueObserver = UploadQueueObserver(uploadQueue: self, queueStateDelegate: self)
        queueSuspensionObserver = UploadQueueSuspensionObserver(uploadQueue: self, queueStateDelegate: self)
    }

    // MARK: - ParallelismHeuristicDelegate

    public func parallelismShouldChange(value: Int) {
        Log.uploadQueue("\(self) new parallelism: \(value)", level: .info)
        operationQueue.maxConcurrentOperationCount = value
    }
}

extension UploadQueue: UploadQueueStateDelegate {
    public func operationQueueBecameEmpty() {
        queueCoordinationDelegate?.operationQueueBecameEmpty()
    }

    public func operationQueueNoLongerEmpty() {
        queueCoordinationDelegate?.operationQueueNoLongerEmpty()
    }

    public func operationQueueBecameSuspended() {
        queueCoordinationDelegate?.operationQueueBecameSuspended()
    }

    public func operationQueueNoLongerSuspended() {
        queueCoordinationDelegate?.operationQueueNoLongerSuspended()
    }
}
