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
@testable import kDriveCore
import Testing

@Suite
@MainActor
struct UTDynamicIslandTaskCompletion {
    enum TestError: Error {
        case upload
        case expiration
    }

    @Test func successBeforeInstallationIsReplayed() async throws {
        let completion = DynamicIslandTaskCompletion()
        completion.complete(with: .success(()))

        try await withCheckedThrowingContinuation { continuation in
            completion.install(continuation)
        }
        guard case .success = completion.result else {
            Issue.record("Expected successful completion")
            return
        }
    }

    @Test(arguments: [TestError.upload, .expiration])
    func failureBeforeInstallationIsReplayed(error: TestError) async {
        let completion = DynamicIslandTaskCompletion()
        completion.complete(with: .failure(error))
        completion.complete(with: .success(()))

        await #expect(throws: error) {
            try await withCheckedThrowingContinuation { continuation in
                completion.install(continuation)
            }
        }
    }

    @Test(arguments: [TestError.upload, .expiration])
    func firstFailureWinsAfterInstallation(error: TestError) async {
        let completion = DynamicIslandTaskCompletion()

        await #expect(throws: error) {
            try await withCheckedThrowingContinuation { continuation in
                completion.install(continuation)
                completion.complete(with: .failure(error))
                completion.complete(with: .success(()))
                completion.complete(with: .failure(TestError.expiration))
            }
        }
    }

    @Test func successIgnoresLaterFailures() async throws {
        let completion = DynamicIslandTaskCompletion()

        try await withCheckedThrowingContinuation { continuation in
            completion.install(continuation)
            completion.complete(with: .success(()))
            completion.complete(with: .failure(TestError.upload))
            completion.complete(with: .failure(TestError.expiration))
        }
    }

    @Test func concurrentCallbacksCompleteOnceOnMain() async {
        let completion = DynamicIslandTaskCompletion()

        await #expect(throws: TestError.upload) {
            try await withCheckedThrowingContinuation { continuation in
                completion.install(continuation)
                completion.complete(with: .failure(TestError.upload))
                DispatchQueue.concurrentPerform(iterations: 100) { index in
                    DispatchQueue.main.async {
                        completion.complete(with: index.isMultiple(of: 2) ? .success(()) : .failure(TestError.expiration))
                    }
                }
            }
        }
        // Drain the queued callbacks before checking the retained terminal result.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        guard case .failure(let error) = completion.result else {
            Issue.record("Expected the first failure to be retained")
            return
        }
        #expect(error as? TestError == .upload)
    }

    @Test func staleCompletionDoesNotAffectNextTask() async throws {
        let previous = DynamicIslandTaskCompletion()
        previous.complete(with: .failure(TestError.expiration))
        let queueCompletion = { previous.complete(with: .success(())) }
        let next = DynamicIslandTaskCompletion()

        try await withCheckedThrowingContinuation { continuation in
            next.install(continuation)
            queueCompletion()
            #expect(next.result == nil)
            next.complete(with: .success(()))
        }
    }
}
