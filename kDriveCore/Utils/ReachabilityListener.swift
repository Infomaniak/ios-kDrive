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

import Foundation
import Network
import UIKit

public class ReachabilityListener {
    public enum NetworkStatus {
        case undefined
        case offline
        case wifi
        case cellular
    }

    private var eventQueue = DispatchQueue(label: "com.infomaniak.drive.network", autoreleaseFrequency: .workItem)
    private var networkMonitor: NWPathMonitor
    private var didChangeNetworkStatus = [UUID: (NetworkStatus) -> Void]()
    public private(set) var currentStatus: NetworkStatus
    public static let instance = ReachabilityListener()

    private init() {
        networkMonitor = NWPathMonitor()
        currentStatus = .undefined
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else {
                return
            }

            let newStatus = self.pathToStatus(path)
            var inBackground = false
            if !Constants.isInExtension {
                DispatchQueue.main.sync {
                    inBackground = UIApplication.shared.applicationState == .background
                }
            }
            if newStatus != self.currentStatus && !inBackground {
                self.currentStatus = newStatus
                self.didChangeNetworkStatus.values.forEach { closure in
                    closure(self.currentStatus)
                }
            }
        }
        networkMonitor.start(queue: eventQueue)
    }

    private func pathToStatus(_ path: NWPath) -> NetworkStatus {
        switch path.status {
        case .satisfied:
            if path.usesInterfaceType(.cellular) {
                return .cellular
            } else {
                return .wifi
            }
        default:
            return .offline
        }
    }
}

// MARK: - Observation

public extension ReachabilityListener {
    @discardableResult
    func observeNetworkChange<T: AnyObject>(_ observer: T, using closure: @escaping (NetworkStatus) -> Void)
        -> ObservationToken {
        let key = UUID()
        didChangeNetworkStatus[key] = { [weak self, weak observer] status in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.didChangeNetworkStatus.removeValue(forKey: key)
                return
            }

            closure(status)
        }

        return ObservationToken { [weak self] in
            self?.didChangeNetworkStatus.removeValue(forKey: key)
        }
    }
}
