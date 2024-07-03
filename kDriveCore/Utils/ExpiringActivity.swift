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
import InfomaniakCore

// TODO: User core 7.0.0 version ASAP
/// Delegation mechanism to notify the end of an `ExpiringActivity`
public protocol ExpiringActivityDelegate: AnyObject {
    /// Called when the system is requiring us to terminate an expiring activity
    func backgroundActivityExpiring()
}

/// Something that can perform arbitrary short background tasks, with a super simple API.
public protocol ExpiringActivityable {
    /// Common init method
    /// - Parameters:
    ///   - id: Something to identify the background activity in debug
    ///   - qos: QoS used by the underlying queues
    ///   - delegate: The delegate to notify we should terminate
    init(id: String, qos: DispatchQoS, delegate: ExpiringActivityDelegate?)

    /// init method
    /// - Parameters:
    ///   - id: Something to identify the background activity in debug
    ///   - delegate: The delegate to notify we should terminate
    init(id: String, delegate: ExpiringActivityDelegate?)

    /// Register with the system an expiring activity
    func start()

    /// Terminate all the expiring activities
    func endAll()

    /// True if the system asked to stop the background activity
    var shouldTerminate: Bool { get }
}

public final class ExpiringActivity: ExpiringActivityable {
    private let qos: DispatchQoS

    private let queue: DispatchQueue

    private let processInfo = ProcessInfo.processInfo

    var locks = [TolerantDispatchGroup]()

    let id: String

    public var shouldTerminate = false

    weak var delegate: ExpiringActivityDelegate?

    // MARK: Lifecycle

    public init(id: String, qos: DispatchQoS, delegate: ExpiringActivityDelegate?) {
        self.id = id
        self.qos = qos
        self.delegate = delegate
        queue = DispatchQueue(label: "com.infomaniak.ExpiringActivity.sync", qos: qos)
    }

    public convenience init(id: String = "\(#function)-\(UUID().uuidString)", delegate: ExpiringActivityDelegate? = nil) {
        self.init(id: id, qos: .userInitiated, delegate: delegate)
    }

    deinit {
        queue.sync {
            assert(locks.isEmpty, "please make sure to call 'endAll()' once explicitly before releasing this object")
        }
    }

    public func start() {
        let group = TolerantDispatchGroup(qos: qos)

        queue.sync {
            self.locks.append(group)
        }

        #if os(macOS)
        // We block a non cooperative queue that matches current QoS
        DispatchQueue.global(qos: qos.qosClass).async {
            self.processInfo.performActivity(options: .suddenTerminationDisabled, reason: self.id) {
                // No expiration handler as we are running on macOS
                group.enter()
                group.wait()
            }
        }
        #else
        // Make sure to not lock an unexpected thread that would deinit()
        processInfo.performExpiringActivity(withReason: id) { [weak self] shouldTerminate in
            guard let self else {
                return
            }

            if shouldTerminate {
                self.shouldTerminate = true
                delegate?.backgroundActivityExpiring()

                // At this point we should release the block, but we prefer to wait until the end 🫡⛵️🪦
                // There is a chance endAll() is called while we wait in should terminate
                group.wait()
                return
            }

            group.enter()
            group.wait()
        }
        #endif
    }

    public func endAll() {
        queue.sync {
            // Release locks, oldest first
            for group in locks.reversed() {
                group.leave()
            }
            locks.removeAll()
        }
    }
}
