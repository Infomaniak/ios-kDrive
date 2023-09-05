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

/// Delegation mechanism to notify the end of an `ExpiringActivity`
public protocol ExpiringActivityDelegate: AnyObject {
    /// Called when the system is requiring us to terminate an expiring activity
    ///
    /// Please make sure to return from this function once the final work is done.
    func backgroundActivityExpiring()
}

public protocol ExpiringActivityable {
    init(id: String, delegate: ExpiringActivityDelegate?)

    /// Register with the system an expiring activity
    func start()

    /// Terminate the expiring activity if needed.
    func end()
}

public final class ExpiringActivity: ExpiringActivityable {
    /// Keep track of the locks on blocks
    private var locks = [DispatchGroup]()

    /// For thread safety
    private let queue = DispatchQueue(label: "com.infomaniak.ExpiringActivity.sync")

    /// Something to identify the background activity in debug
    let id: String

    /// The delegate to notify we should terminate
    weak var delegate: ExpiringActivityDelegate?

    // MARK: Lifecycle

    public init(id: String, delegate: ExpiringActivityDelegate?) {
        self.id = id
        self.delegate = delegate
    }

    deinit {
        queue.sync {
            assert(locks.isEmpty, "please make sure to balance 'start()' and 'end()' before releasing this object")
        }
    }

    public func start() {
        let group = DispatchGroup()

        queue.sync {
            self.locks.append(group)
        }

        // Make sure to not lock an unexpected thread that would deinit()
        ProcessInfo.processInfo.performExpiringActivity(withReason: id) { [weak self] shouldTerminate in
            guard let self else {
                return
            }

            if shouldTerminate {
                delegate?.backgroundActivityExpiring()
            }

            group.enter()
            group.wait()
        }
    }

    public func end() {
        queue.sync {
            // Release locks, oldest first
            for group in locks.reversed() {
                group.leave()
            }
            locks.removeAll()
        }
    }
}
