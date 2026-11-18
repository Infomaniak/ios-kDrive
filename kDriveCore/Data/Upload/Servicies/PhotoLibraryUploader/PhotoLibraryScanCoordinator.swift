/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

/// Owns scan tasks, draining previous work before a replacement can start.
actor PhotoLibraryScanCoordinator {
    private struct Worker {
        let id: UUID
        let task: Task<Void, Never>
    }

    private var worker: Worker?

    func run(_ operation: @escaping @Sendable () async -> Void) async {
        guard !Task.isCancelled else { return }

        let previous = worker
        previous?.task.cancel()

        let id = UUID()
        let task = Task {
            // Even a cancelled replacement must drain its predecessor so later work cannot overlap it.
            await previous?.task.value
            guard !Task.isCancelled else { return }
            await operation()
        }
        worker = Worker(id: id, task: task)

        await task.value
        clearWorker(id: id)
    }

    func cancel() async {
        guard let worker else { return }
        worker.task.cancel()
        await worker.task.value
        clearWorker(id: worker.id)
    }

    private func clearWorker(id: UUID) {
        guard worker?.id == id else { return }
        worker = nil
    }
}
