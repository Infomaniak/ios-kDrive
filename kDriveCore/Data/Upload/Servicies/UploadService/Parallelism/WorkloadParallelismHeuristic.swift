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

import Foundation
import InfomaniakCore
import InfomaniakDI
import UIKit

public enum ParallelismDefaults {
    static let highParallelism = 6

    static let mediumParallelism = 4

    static let reducedParallelism = 2

    static let serial = 1
}

/// Delegate protocol of UploadParallelismHeuristic
public protocol ParallelismHeuristicDelegate: AnyObject {
    /// This method is called with a new parallelism to apply each time to the uploadQueue
    /// - Parameter value: The new parallelism value to use
    func parallelismShouldChange(value: Int)
}

/// Something to maintain a coherent parallelism value for the Upload / Download Queue
///
/// Value can change depending on many factors, including thermal state battery or extension mode.
/// Scaling is achieved given the number of active cores available.
public final class WorkloadParallelismHeuristic {
    @LazyInjectService private var appContextService: AppContextServiceable

    private var computeTask: Task<Void, Never>?

    private let serialEventQueue = DispatchQueue(
        label: "com.infomaniak.drive.parallelism-heuristic.event",
        qos: .default
    )

    private weak var delegate: ParallelismHeuristicDelegate?

    init(delegate: ParallelismHeuristicDelegate) {
        self.delegate = delegate

        setupObservation()
    }

    private func setupObservation() {
        // Update on thermal change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computeParallelismInTask),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )

        // Update on low power mode
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computeParallelismInTask),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computeParallelismInTask),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computeParallelismInTask),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computeParallelismInTask),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computeParallelismInTask),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            guard let self else { return }
            self.computeParallelismInTask()
        }

        computeParallelismInTask()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func computeParallelismInTask() {
        serialEventQueue.async {
            self.computeTask?.cancel()

            let computeParallelismTask = Task {
                await self.computeParallelism()
            }

            self.computeTask = computeParallelismTask
        }
    }

    @MainActor private var appIsActive: Bool {
        UIApplication.shared.applicationState == .active
    }

    private func computeParallelism() async {
        let processInfo = ProcessInfo.processInfo

        // If the device is too hot we cool down now
        let thermalState = processInfo.thermalState
        guard thermalState != .critical else {
            currentParallelism = ParallelismDefaults.reducedParallelism
            return
        }

        // In low power mode, we reduce parallelism
        guard !processInfo.isLowPowerModeEnabled else {
            currentParallelism = ParallelismDefaults.reducedParallelism
            return
        }

        // In extension, to reduce memory footprint, we reduce drastically parallelism
        guard !appContextService.isExtension else {
            currentParallelism = ParallelismDefaults.reducedParallelism
            return
        }

        // In state .background or .inactive, to reduce memory footprint, we reduce drastically parallelism
        guard await appIsActive else {
            currentParallelism = ParallelismDefaults.reducedParallelism
            return
        }

        // Scaling with the number of activeProcessor to a point
        let parallelism = min(6, max(4, processInfo.activeProcessorCount))

        // Beginning with .serious state, we start reducing the load on the system
        guard thermalState != .serious else {
            currentParallelism = max(ParallelismDefaults.reducedParallelism, parallelism / 2)
            return
        }

        guard !Task.isCancelled else {
            return
        }

        currentParallelism = parallelism
    }

    public private(set) var currentParallelism = ParallelismDefaults.reducedParallelism {
        didSet {
            delegate?.parallelismShouldChange(value: currentParallelism)
        }
    }
}
