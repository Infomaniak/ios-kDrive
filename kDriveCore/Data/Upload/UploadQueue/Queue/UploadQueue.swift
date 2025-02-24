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

public protocol UploadQueueDelegate: AnyObject {
    func operationQueueBecameEmpty(_ queue: UploadQueue)
    func operationQueueNoLongerEmpty(_ queue: UploadQueue)
}

public class UploadQueue: ParallelismHeuristicDelegate {
    @LazyInjectService var appContextService: AppContextServiceable
    @LazyInjectService var uploadPublisher: UploadPublishable

    private var queueObserver: UploadQueueObserver?

    weak var delegate: UploadQueueDelegate?

    /// Something to track an operation for a File ID
    let keyedUploadOperations = KeyedUploadOperationable()

    public lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "kDrive upload queue"
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
        return URLSession(configuration: urlSessionConfiguration, delegate: nil, delegateQueue: nil)
    }()

    /// Should suspend operation queue based on network status
    var shouldSuspendQueue: Bool {
        // Explicitly disable the upload queue from the share extension
        guard appContextService.context != .shareExtension else {
            return true
        }

        let status = ReachabilityListener.instance.currentStatus
        let shouldBeSuspended = status == .offline || (status != .wifi && UserDefaults.shared.isWifiOnly)
        return shouldBeSuspended
    }

    /// Should suspend operation queue based on explicit `suspendAllOperations()` call
    var forceSuspendQueue = false

    public init(delegate: UploadQueueDelegate?) {
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("UploadQueue disabled in ShareExtension", level: .error)
            return
        }

        self.delegate = delegate

        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            guard let self else { return }

            let isSuspended = (shouldSuspendQueue || forceSuspendQueue)
            operationQueue.isSuspended = isSuspended
            Log.uploadQueue("observeNetworkChange :\(isSuspended)")
        }

        queueObserver = UploadQueueObserver(uploadQueue: self, delegate: delegate)
    }

    // MARK: - ParallelismHeuristicDelegate

    public func parallelismShouldChange(value: Int) {
        Log.uploadQueue("Upload queue new parallelism: \(value)", level: .info)
        operationQueue.maxConcurrentOperationCount = value
    }
}
