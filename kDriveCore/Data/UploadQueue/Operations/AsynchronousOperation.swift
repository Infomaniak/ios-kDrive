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
// https://gist.github.com/calebd/93fa347397cec5f88233#file-asynchronousoperation-swift

import Foundation

/// An abstract class that makes building simple asynchronous operations easy.
/// Subclasses must implement `execute()` to perform any work and call
/// `finish()` when they are done. All `NSOperation` work will be handled
/// automatically.
open class AsynchronousOperation: Operation {
    // MARK: - Properties

    private let stateQueue = DispatchQueue(
        label: "com.infomaniak.drive.async-operation-state",
        attributes: .concurrent)

    private var rawState = OperationState.ready

    @objc private dynamic var state: OperationState {
        get {
            return stateQueue.sync(execute: { rawState })
        }
        set {
            willChangeValue(forKey: "state")
            stateQueue.sync(
                flags: .barrier,
                execute: { rawState = newValue })
            didChangeValue(forKey: "state")
        }
    }

    public final override var isReady: Bool {
        return state == .ready && super.isReady
    }

    public final override var isExecuting: Bool {
        return state == .executing
    }

    public final override var isFinished: Bool {
        return state == .finished
    }
    
    public final override var isAsynchronous: Bool {
        return true
    }

    // MARK: - NSObject

    @objc private dynamic class func keyPathsForValuesAffectingIsReady() -> Set<String> {
        return ["state"]
    }

    @objc private dynamic class func keyPathsForValuesAffectingIsExecuting() -> Set<String> {
        return ["state"]
    }

    @objc private dynamic class func keyPathsForValuesAffectingIsFinished() -> Set<String> {
        return ["state"]
    }

    // MARK: - Foundation.Operation

    /// Something to enqueue async await job
    let asyncAwaitQueue = TaskQueue(concurrency: 0)
    
    public override final func start() {
        super.start()

        if isCancelled {
            finish()
            return
        }

        state = .executing
        
        Task {
            try await asyncAwaitQueue.enqueue {
                await self.execute()
            }
        }
    }

    // MARK: - Public

    /// Subclasses must implement this to perform their work and they must not
    /// call `super`. The default implementation of this function throws an
    /// exception.
    ///
    /// Making this function `async` allows for the seamless integration of modern swift async code.
    ///
    open func execute() async {
        fatalError("Subclasses must implement `execute`.")
    }

    /// Call this function after any work is done or after a call to `cancel()`
    /// to move the operation into a completed state.
    public final func finish() {
        state = .finished
    }
}

@objc private enum OperationState: Int {
    case ready
    case executing
    case finished
}


public actor TaskQueue {
    private let concurrency: Int
    private var running: Int = 0
    private var queue = [CheckedContinuation<Void, Error>]()

    public init(concurrency: Int) {
        self.concurrency = concurrency
    }

    deinit {
        for continuation in queue {
            continuation.resume(throwing: CancellationError())
        }
    }

    public func enqueue<T>(operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try Task.checkCancellation()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.append(continuation)
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
