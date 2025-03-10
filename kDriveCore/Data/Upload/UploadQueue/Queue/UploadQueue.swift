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

public class UploadQueue: ParallelismHeuristicDelegate {
    private var memoryPressure: DispatchSourceMemoryPressure?

    @LazyInjectService(customTypeIdentifier: kDriveDBID.uploads) var uploadsDatabase: Transactionable
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var notificationHelper: NotificationsHelpable
    @LazyInjectService var appContextService: AppContextServiceable

    public static let backgroundBaseIdentifier = ".backgroundsession.upload"
    public static var backgroundIdentifier: String {
        return (Bundle.main.bundleIdentifier ?? "com.infomaniak.drive") + backgroundBaseIdentifier
    }

    public var pausedNotificationSent = false

    /// A serial queue to lock access to ivars an observations.
    let serialQueue: DispatchQueue = {
        @LazyInjectService var appContextService: AppContextServiceable
        let autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = appContextService.isExtension ? .workItem : .inherit

        return DispatchQueue(
            label: "com.infomaniak.drive.upload-sync",
            qos: .userInitiated,
            autoreleaseFrequency: autoreleaseFrequency
        )
    }()

    /// A concurrent queue.
    let concurrentQueue: DispatchQueue = {
        @LazyInjectService var appContextService: AppContextServiceable
        let autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = appContextService.isExtension ? .workItem : .inherit

        return DispatchQueue(label: "com.infomaniak.drive.upload-async",
                             qos: .userInitiated,
                             attributes: [.concurrent],
                             autoreleaseFrequency: autoreleaseFrequency)

    }()

    /// Something to track an operation for a File ID
    let keyedUploadOperations = KeyedUploadOperationable()

    /// Something to adapt the upload parallelism live
    var uploadParallelismHeuristic: WorkloadParallelismHeuristic?

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

    var fileUploadedCount = 0

    var bestSession: URLSession {
        return foregroundSession
    }

    /// Should suspend operation queue based on network status
    var shouldSuspendQueue: Bool {
        // Explicitly disable the upload queue from the share extension
        guard appContextService.context != .shareExtension else {
            return true
        }

        let status = ReachabilityListener.instance.currentStatus
        return status == .offline || (status != .wifi && UserDefaults.shared.isWifiOnly)
    }

    /// Should suspend operation queue based on explicit `suspendAllOperations()` call
    var forceSuspendQueue = false

    var observations = (
        didUploadFile: [UUID: (UploadFile, File?) -> Void](),
        didChangeUploadCountInParent: [UUID: (Int, Int) -> Void](),
        didChangeUploadCountInDrive: [UUID: (Int, Int) -> Void]()
    )

    public init() {
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("UploadQueue disabled in ShareExtension", level: .error)
            return
        }

        Log.uploadQueue("Starting up")

        uploadParallelismHeuristic = WorkloadParallelismHeuristic(delegate: self)

        concurrentQueue.async {
            // Initialize operation queue with files from Realm, and make sure it restarts
            self.rebuildUploadQueueFromObjectsInRealm()
            self.resumeAllOperations()
        }

        // Observe network state change
        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            guard let self else {
                return
            }

            let isSuspended = (shouldSuspendQueue || forceSuspendQueue)
            operationQueue.isSuspended = isSuspended
            Log.uploadQueue("observeNetworkChange :\(isSuspended)")
        }

        observeMemoryWarnings()

        Log.uploadQueue("UploadQueue parallelism is:\(operationQueue.maxConcurrentOperationCount)")
    }

    // MARK: - Memory warnings

    /// A critical memory warning in `FileProvider` context will reschedule, in order to transition uploads to Main App.
    private func observeMemoryWarnings() {
        guard appContextService.context == .fileProviderExtension else {
            return
        }

        let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
        memoryPressure = source
        source.setEventHandler {
            let event: DispatchSource.MemoryPressureEvent = source.data
            switch event {
            case DispatchSource.MemoryPressureEvent.normal:
                Log.uploadQueue("MemoryPressureEvent normal", level: .info)
            case DispatchSource.MemoryPressureEvent.warning:
                Log.uploadQueue("MemoryPressureEvent warning", level: .info)
            case DispatchSource.MemoryPressureEvent.critical:
                Log.uploadQueue("MemoryPressureEvent critical", level: .error)
                self.rescheduleRunningOperations()
            default:
                break
            }
        }
        source.resume()
    }

    // MARK: - ParallelismHeuristicDelegate

    func parallelismShouldChange(value: Int) {
        Log.uploadQueue("Upload queue new parallelism: \(value)", level: .info)
        operationQueue.maxConcurrentOperationCount = value
    }
}
