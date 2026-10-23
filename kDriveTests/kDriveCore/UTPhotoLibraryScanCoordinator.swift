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

@testable import kDriveCore
import Testing

@Suite
struct UTPhotoLibraryScanCoordinator {
    @Test func replacementDrainsPreviousWorkerAndSurvivesStaleCompletion() async {
        let coordinator = PhotoLibraryScanCoordinator()
        let first = ScanWorker()
        let second = ScanWorker()

        let firstRequest = Task { await coordinator.run { await first.run() } }
        await first.started.wait()
        let secondRequest = Task { await coordinator.run { await second.run() } }
        await first.cancelled.wait()

        #expect(await second.started.isOpen == false)
        await first.finish.open()
        await firstRequest.value
        await second.started.wait()

        let cancellation = Task { await coordinator.cancel() }
        await second.cancelled.wait()
        await second.finish.open()
        await cancellation.value
        await secondRequest.value
    }

    @Test func cancellationDrainsWorkerAndAllowsAnotherScan() async {
        let coordinator = PhotoLibraryScanCoordinator()
        let worker = ScanWorker()
        let cancellationFinished = ScanGate()
        let request = Task { await coordinator.run { await worker.run() } }
        await worker.started.wait()

        let cancellation = Task {
            await coordinator.cancel()
            await cancellationFinished.open()
        }
        await worker.cancelled.wait()
        #expect(await cancellationFinished.isOpen == false)

        await worker.finish.open()
        await cancellation.value
        await request.value

        let nextScan = ScanGate()
        await coordinator.run { await nextScan.open() }
        #expect(await nextScan.isOpen)
    }

    @Test func cancelledCallerDoesNotReplaceRunningScan() async {
        let coordinator = PhotoLibraryScanCoordinator()
        let worker = ScanWorker()
        let request = Task { await coordinator.run { await worker.run() } }
        await worker.started.wait()

        let admission = ScanGate()
        let replacementStarted = ScanGate()
        let replacement = Task {
            await admission.wait()
            await coordinator.run { await replacementStarted.open() }
        }
        replacement.cancel()
        await admission.open()
        await replacement.value
        #expect(await replacementStarted.isOpen == false)
        #expect(await worker.cancelled.isOpen == false)

        await worker.finish.open()
        await request.value
    }
}

private struct ScanWorker: Sendable {
    let started = ScanGate()
    let cancelled = ScanGate()
    let finish = ScanGate()

    func run() async {
        await withTaskCancellationHandler {
            await started.open()
            await finish.wait()
        } onCancel: {
            Task { await cancelled.open() }
        }
    }
}

private actor ScanGate {
    private(set) var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }
}
