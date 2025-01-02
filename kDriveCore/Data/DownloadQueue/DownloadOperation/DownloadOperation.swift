/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

import InfomaniakDI
import UIKit

public class DownloadOperation: Operation, @unchecked Sendable {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var appContextService: AppContextServiceable

    var task: URLSessionDownloadTask?
    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    var progressObservation: NSKeyValueObservation?

    public var error: DriveError?

    init(task: URLSessionDownloadTask? = nil) {
        self.task = task
    }

    var _executing = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }

    var _finished = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }

    override public var isExecuting: Bool {
        return _executing
    }

    override public var isFinished: Bool {
        return _finished
    }

    override public var isAsynchronous: Bool {
        return true
    }

    override public func cancel() {
        super.cancel()
        task?.cancel()
    }

    func endBackgroundTaskObservation() {
        progressObservation?.invalidate()
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }

        _executing = false
        _finished = true
    }
}
