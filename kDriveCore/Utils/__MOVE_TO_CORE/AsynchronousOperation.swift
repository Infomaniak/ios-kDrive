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
            return stateQueue.sync { rawState }
        }
        set {
            willChangeValue(forKey: "state")
            stateQueue.sync(
                flags: .barrier) { rawState = newValue }
            didChangeValue(forKey: "state")
        }
    }

    override public final var isReady: Bool {
        return state == .ready && super.isReady
    }

    override public final var isExecuting: Bool {
        return state == .executing
    }

    override public final var isFinished: Bool {
        return state == .finished
    }

    override public final var isAsynchronous: Bool {
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

    /// Something to enqueue async await tasks in a serial manner.
    let asyncAwaitQueue = TaskQueue()

    override public final func start() {
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
    /// It will be dispatched to the underlaying serial execution queue.
    ///
    open func execute() async {
        fatalError("Subclasses must implement `execute`.")
    }

    /// Enqueue an async/await closure in the underlaying serial execution queue.
    /// - Parameter asap: The task will be scheduled ASAP in the queue
    /// - Parameter task: A closure with async await code to be dispatched
    public func enqueue(asap: Bool = false, _ task: @escaping () async throws -> Void) {
        Task {
            try await asyncAwaitQueue.enqueue(asap: asap) {
                try await task()
            }
        }
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
