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

import CocoaLumberjackSwift
import Foundation

public class Mutex {
    let semaphore = DispatchSemaphore(value: 1)

    @discardableResult
    public func locked<T>(_ block: () -> T) -> T {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        return block()
    }
}

/** Throttle wraps a block with throttling logic, guaranteeing that the block will never be called (by enqueuing
 asynchronously on `queue`) more than once each `interval` seconds. If the wrapper callback is called more than once
 in an interval, it will use the most recent call's parameters when eventually calling the wrapped block (after `interval`
 has elapsed since the last call to the wrapped function) - i.e. calls are not queued and may get 'lost' by being superseded
 by a newer call. */
public class Throttler<T> {
    public typealias Handler = (T) -> Void

    public var handler: Handler?

    private let timeInterval: TimeInterval
    private let queue: DispatchQueue
    private let mutex = Mutex()

    private var lastExecutionTime: TimeInterval = 0
    private var scheduledExecutionParameters: T?

    public init(timeInterval: TimeInterval, queue: DispatchQueue) {
        self.timeInterval = timeInterval
        self.queue = queue
    }

    public func call(_ p: T) {
        mutex.locked { [weak self] in
            let currentTime = Date().timeIntervalSinceReferenceDate

            if currentTime - lastExecutionTime > timeInterval {
                // The last execution was more than interval ago, or it's the first execution. Execute now.
                queue.async { [weak self] in
                    self?.lastExecutionTime = currentTime
                    self?.handler?(p)
                }
            } else {
                // Last execution was less than interval ago
                if scheduledExecutionParameters != nil {
                    // Another execution was already planned, just make sure it will use latest parameters
                    scheduledExecutionParameters = p
                } else {
                    // Schedule execution
                    scheduledExecutionParameters = p
                    let scheduleDelay = lastExecutionTime + timeInterval - currentTime

                    queue.asyncAfter(deadline: .now() + scheduleDelay) { [weak self] in
                        guard let self = self else { return }
                        // Delayed execution
                        let p = self.mutex.locked { [weak self] () -> T? in
                            let params = self?.scheduledExecutionParameters!
                            self?.scheduledExecutionParameters = nil
                            return params
                        }
                        guard let p = p else { return }
                        self.lastExecutionTime = currentTime
                        self.handler?(p)
                    }
                }
            }
        }
    }
}
