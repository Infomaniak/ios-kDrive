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
import InfomaniakDI

/// Delegate protocol of UploadParallelismHeuristic
protocol ParallelismHeuristicDelegate: AnyObject {
    /// This method is called with a new parallelism to apply each time to the uploadQueue
    /// - Parameter value: The new parallelism value to use
    func parallelismShouldChange(value: Int)
}

/// Something to maintain a coherent parallelism value for the Upload / Download Queue
///
/// Value can change depending on many factors, including thermal state battery or extension mode.
/// Scaling is achieved given the number of active cores available.
final class WorkloadParallelismHeuristic {
    /// With 2 Operations max, and a chuck of 1MiB max, the UploadQueue can spike to max 4MiB memory usage.
    private static let reducedParallelism = 2

    @LazyInjectService private var appContextService: AppContextServiceable

    private weak var delegate: ParallelismHeuristicDelegate?

    init(delegate: ParallelismHeuristicDelegate) {
        self.delegate = delegate

        // Update on thermal change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computeParallelism),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )

        // Update on low power mode
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(computeParallelism),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )

        // Update the value a first time
        computeParallelism()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)
    }

    @objc private func computeParallelism() {
        let processInfo = ProcessInfo.processInfo

        // If the device is too hot we cool down now
        let thermalState = processInfo.thermalState
        guard thermalState != .critical else {
            currentParallelism = Self.reducedParallelism
            return
        }

        // In low power mode, we reduce parallelism
        guard !processInfo.isLowPowerModeEnabled else {
            currentParallelism = Self.reducedParallelism
            return
        }

        // In extension, to reduce memory footprint, we reduce drastically parallelism
        guard !appContextService.isExtension else {
            currentParallelism = Self.reducedParallelism
            return
        }

        // Scaling with the number of activeProcessor
        let parallelism = max(4, processInfo.activeProcessorCount)

        // Beginning with .serious state, we start reducing the load on the system
        guard thermalState != .serious else {
            currentParallelism = max(Self.reducedParallelism, parallelism / 2)
            return
        }

        currentParallelism = parallelism
    }

    public private(set) var currentParallelism = 0 {
        didSet {
            delegate?.parallelismShouldChange(value: currentParallelism)
        }
    }
}
