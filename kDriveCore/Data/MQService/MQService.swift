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
import InfomaniakCore
import InfomaniakDI
import MQTT
import OSLog

public final class MQService {
    private static let logger = Logger(category: "MQService")

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static let environment = ApiEnvironment.current
    private let client: MQTTClient.V3

    private var currentToken: IPSToken?
    private var actionProgressObservers = [UUID: (ActionProgressNotification) -> Void]()

    public init() {
        let endpoint = Endpoint.wss(
            host: Self.environment.mqttHost,
            port: 443,
            path: "/ws"
        )
        client = MQTTClient.V3(endpoint)
        client.config.keepAlive = 30
        client.config.pingTimeout = 5
        client.config.pingEnabled = true
        client.config.connectTimeout = 20
        client.delegate = self

        client.startMonitor()
        client.startRetrier()
    }

    deinit {
        client.stopMonitor()
        client.stopRetrier()
        client.close()
    }

    public func registerForNotifications(with token: IPSToken) {
        Task {
            if let currentToken {
                await unsubscribe(from: currentToken)
            }

            currentToken = token

            do {
                if !client.isOpened {
                    let identity = Identity(
                        Self.generateClientIdentifier(),
                        username: "ips:ips-public",
                        password: Self.environment.mqttPass
                    )

                    try await client.open(identity, cleanStart: false).wait()
                    Self.logger.info("Connection successful")

                    try await client.subscribe(to: topic(for: token), qos: .atMostOnce).wait()
                } else {
                    try await client.subscribe(to: topic(for: token), qos: .atMostOnce).wait()
                }
                Self.logger.info("Subscription successful")
            } catch {
                Self.logger.error("Error while connecting/subscribing: \(error)")
            }
        }
    }

    private func unsubscribe(from currentToken: IPSToken) async {
        actionProgressObservers.removeAll()
        do {
            try await client.unsubscribe(from: topic(for: currentToken)).wait()
        } catch {
            Self.logger.error("Error while unsubscribing: \(error)")
        }
    }

    private func topic(for token: IPSToken) -> String {
        return "drive/\(token.uuid)"
    }

    private func handleNotification(_ notification: ActionNotification) {
        if notification.action == .reload {
            NotificationCenter.default.post(name: .reloadDrive, object: nil, userInfo: ["driveId": notification.driveId as Any])
        }
    }

    private func handleExternalImportNotification(_ notification: ExternalImportNotification) {
        @InjectService var accountManager: AccountManageable
        guard let driveFileManager = accountManager.getDriveFileManager(for: notification.driveId,
                                                                        userId: notification.userId)
        else { return }
        driveFileManager.updateExternalImport(id: notification.importId, action: notification.action)
    }

    private static func generateClientIdentifier() -> String {
        let length = 10
        let prefix = "mqttios_kdrive_"
        let letters = "abcdefghijklmnopqrstuvwxyz"
        return prefix + String((0 ..< length).map { _ in letters.randomElement()! })
    }
}

// MARK: - MQTTDelegate

extension MQService: MQTTDelegate {
    public func mqtt(_ mqtt: MQTTClient, didUpdate status: Status, prev: Status) {
        if case .closed = status {
            Self.logger.warning("Connection closed (was: \(prev))")
        }
    }

    public func mqtt(_ mqtt: MQTTClient, didReceive error: any Error) {
        Self.logger.error("Error: \(error)")
    }

    public func mqtt(_ mqtt: MQTTClient, didReceive message: Message) {
        if let notification = try? decoder.decode(ActionProgressNotification.self, from: message.payload) {
            for observer in actionProgressObservers.values {
                observer(notification)
            }
        } else if let notification = try? decoder.decode(ActionNotification.self, from: message.payload) {
            handleNotification(notification)
        } else if let notification = try? decoder.decode(ExternalImportNotification.self, from: message.payload) {
            handleExternalImportNotification(notification)
        }
    }
}

// MARK: - Observation

public extension MQService {
    typealias ActionId = String

    @discardableResult
    func observeActionProgress<T: AnyObject>(
        _ observer: T,
        actionId: ActionId?,
        using closure: @escaping (ActionProgressNotification) -> Void
    )
        -> ObservationToken {
        let key = UUID()
        actionProgressObservers[key] = { [weak self, weak observer] action in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.actionProgressObservers.removeValue(forKey: key)
                return
            }

            if actionId == action.actionUuid {
                closure(action)
            }

            if action.progress.message == .done || action.progress.message == .canceled {
                self?.actionProgressObservers.removeValue(forKey: key)
            }
        }

        return ObservationToken { [weak self] in
            self?.actionProgressObservers.removeValue(forKey: key)
        }
    }
}
