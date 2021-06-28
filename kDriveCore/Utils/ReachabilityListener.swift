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

public class ReachabilityListener {

    public enum NetworkStatus {
        case undefined
        case offline
        case wifi
        case cellular
    }

    private var networkMonitor: NWPathMonitor
    private var didChangeNetworkStatus = [UUID: (NetworkStatus) -> Void]()
    public private(set) var currentStatus: NetworkStatus
    public static let instance = ReachabilityListener()

    init() {
        networkMonitor = NWPathMonitor()
        currentStatus = .undefined
        networkMonitor.pathUpdateHandler = { path in
            let newStatus = self.pathToStatus(path)
            if newStatus != self.currentStatus {
                self.currentStatus = newStatus
                self.didChangeNetworkStatus.values.forEach { closure in
                    closure(self.currentStatus)
                }
            }
        }
        networkMonitor.start(queue: .main)
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
extension ReachabilityListener {
    @discardableResult
    public func observeNetworkChange<T: AnyObject>(_ observer: T, using closure: @escaping (NetworkStatus) -> Void)
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
