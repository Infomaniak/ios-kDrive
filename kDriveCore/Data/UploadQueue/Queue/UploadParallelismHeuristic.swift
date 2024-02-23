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

protocol ParallelismHeuristicDelegate: AnyObject {
    func parallelismShouldChange(value: Int)
}

final class UploadParallelismHeuristic {
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

    @objc private func computeParallelism() {
        let processInfo = ProcessInfo.processInfo

        // if the device is too hot we allow it to cool down
        let state = processInfo.thermalState
        guard state != .critical else {
            currentParallelism = 2
            return
        }

        // if the device is in low power mode, we reduce parallelism
        guard !processInfo.isLowPowerModeEnabled else {
            currentParallelism = 2
            return
        }

        // In extension to reduce memory footprint, we reduce drastically parallelism
        let parallelism: Int
        if Bundle.main.isExtension {
            parallelism = 2 // With 2 Operations max, and a chuck of 1MiB max, the UploadQueue can spike to max 4MiB.
        } else {
            parallelism = max(4, processInfo.activeProcessorCount)
        }

        currentParallelism = parallelism
    }

    public var currentParallelism = 0 {
        didSet {
            delegate?.parallelismShouldChange(value: currentParallelism)
        }
    }
}
