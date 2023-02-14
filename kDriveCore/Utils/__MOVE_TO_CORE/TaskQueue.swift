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

/// A queue of AsyncAwait tasks. Serial by default.
public actor TaskQueue {
    private let concurrency: Int
    private var running: Int = 0
    private var queue = [CheckedContinuation<Void, Error>]()
    
    /// Init function
    /// - Parameter concurrency: execution depth
    public init(concurrency: Int = 1 /* serial by default */) {
        assert(concurrency > 0, "zero concurrency locks execution")
        self.concurrency = concurrency
    }

    deinit {
        for continuation in queue {
            continuation.resume(throwing: CancellationError())
        }
    }
    
    /// Enqueue some work.
    /// - Parameters:
    ///   - asap: if `true`, the task will be added on top of the execution stack
    ///   - operation: an async await task to be schedulled in the queue
    public func enqueue<T>(asap: Bool = false, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try Task.checkCancellation()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if asap == true {
                queue.insert(continuation, at: 0)
            } else {
                queue.append(continuation)
            }
            tryRunEnqueued()
        }

        defer {
            running -= 1
            tryRunEnqueued()
        }
        try Task.checkCancellation()
        return try await operation()
    }

    private func tryRunEnqueued() {
        guard !queue.isEmpty else { return }
        guard running < concurrency else { return }

        running += 1
        let continuation = queue.removeFirst()
        continuation.resume()
    }
}
