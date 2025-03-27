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

public final class UploadParallelismOrchestrator {
    @LazyInjectService(customTypeIdentifier: UploadQueueID.global) private var globalUploadQueue: UploadQueueable
    @LazyInjectService(customTypeIdentifier: UploadQueueID.photo) private var photoUploadQueue: UploadQueueable
    @LazyInjectService private var appContextService: AppContextServiceable

    private let serialEventQueue = DispatchQueue(
        label: "com.infomaniak.drive.upload-parallelism-orchestrator.event",
        qos: .default
    )

    private var uploadParallelismHeuristic: WorkloadParallelismHeuristic?
    private var memoryPressureObserver: DispatchSourceMemoryPressure?

    private var availableParallelism: Int {
        guard let uploadParallelismHeuristic else {
            return ParallelismDefaults.reducedParallelism
        }
        return uploadParallelismHeuristic.currentParallelism
    }

    private lazy var allQueues = [globalUploadQueue, photoUploadQueue]

    public init() {
        setupObservation()
    }

    private func setupObservation() {
        serialEventQueue.async {
            self.observeMemoryWarnings()
            self.uploadParallelismHeuristic = WorkloadParallelismHeuristic(delegate: self)
        }
    }

    func observeMemoryWarnings() {
        guard appContextService.context == .fileProviderExtension else {
            return
        }

        let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
        memoryPressureObserver = source
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let event: DispatchSource.MemoryPressureEvent = source.data
            switch event {
            case DispatchSource.MemoryPressureEvent.normal:
                Log.uploadQueue("MemoryPressureEvent normal", level: .info)
            case DispatchSource.MemoryPressureEvent.warning:
                Log.uploadQueue("MemoryPressureEvent warning", level: .info)
            case DispatchSource.MemoryPressureEvent.critical:
                Log.uploadQueue("MemoryPressureEvent critical", level: .error)
                serialEventQueue.async {
                    @InjectService var uploadService: UploadServiceable
                    uploadService.rescheduleRunningOperations()
                }
            default:
                break
            }
        }
        source.resume()
    }

    private func computeUploadParallelismPerQueueAndApply() {
        serialEventQueue.async {
            let currentAvailableParallelism = self.availableParallelism
            Log.uploadQueue("Current total available upload parallelism :\(currentAvailableParallelism)")

            let activeQueues = self.allQueues.filter(\.isActive)
            let inactiveQueues = self.allQueues.filter { !$0.isActive }

            inactiveQueues.forEach { $0.parallelismShouldChange(value: ParallelismDefaults.serial) }

            Log.uploadQueue("Inactive queues:\(inactiveQueues.count) set to serial")
            guard !activeQueues.isEmpty else {
                Log.uploadQueue("No active queues")
                return
            }

            let parallelismPerActiveQueue = max(ParallelismDefaults.serial, currentAvailableParallelism / activeQueues.count)
            Log.uploadQueue("Active queues \(activeQueues.count) new parallelism:\(parallelismPerActiveQueue)")
            activeQueues.forEach { $0.parallelismShouldChange(value: parallelismPerActiveQueue) }
        }
    }
}

extension UploadParallelismOrchestrator: UploadQueueDelegate {
    public func operationQueueBecameEmpty(_ queue: UploadQueue) {
        computeUploadParallelismPerQueueAndApply()
    }

    public func operationQueueNoLongerEmpty(_ queue: UploadQueue) {
        computeUploadParallelismPerQueueAndApply()
    }
}

extension UploadParallelismOrchestrator: ParallelismHeuristicDelegate {
    public func parallelismShouldChange(value: Int) {
        computeUploadParallelismPerQueueAndApply()
    }
}
