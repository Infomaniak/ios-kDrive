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
import InfomaniakCore
import MQTTNIO

public class MQService {
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let queue = DispatchQueue(label: "com.infomaniak.drive.mqservice")
    private static let environment = ApiEnvironment.current
    private static let configuration = MQTTClient.Configuration(
        keepAliveInterval: .seconds(30),
        connectTimeout: .seconds(20),
        userName: "ips:ips-public",
        password: environment.mqttPass,
        useSSL: true,
        useWebSockets: true,
        webSocketURLPath: "/ws"
    )
    private let client = MQTTClient(
        host: environment.mqttHost,
        port: 443,
        identifier: generateClientIdentifier(),
        eventLoopGroupProvider: .createNew,
        configuration: configuration
    )

    private let initialReconnectionTimeout: Double = 1
    private let maxReconnectionTimeout: Double = 300

    private var currentToken: IPSToken?
    private var reconnections = 0
    private var actionProgressObservers = [UUID: (ActionProgressNotification) -> Void]()

    private var reconnectionDelay: Double {
        reconnections += 1
        return min(initialReconnectionTimeout * Double(2 * reconnections), maxReconnectionTimeout)
    }

    public init() {}

    public func registerForNotifications(with token: IPSToken) {
        queue.async { [self] in
            if !client.isActive() {
                do {
                    _ = try client.connect().wait()
                    DDLogInfo("[MQService] Connection successful")
                } catch {
                    DDLogError("[MQService] Error while connecting: \(error)")
                }
            }
            if let currentToken = currentToken {
                actionProgressObservers.removeAll()
                do {
                    try client.unsubscribe(from: [topic(for: currentToken)]).wait()
                } catch {
                    DDLogError("[MQService] Error while unsubscribing: \(error)")
                }
            }
            currentToken = token
            do {
                _ = try client.subscribe(to: [MQTTSubscribeInfo(topicFilter: topic(for: token), qos: .atMostOnce)]).wait()
                client.addPublishListener(named: "Drive notifications listener") { result in
                    switch result {
                    case .success(let message):
                        var buffer = message.payload
                        if let data = buffer.readData(length: buffer.readableBytes) {
                            if let message = try? self.decoder.decode(ActionProgressNotification.self, from: data) {
                                for observer in self.actionProgressObservers.values {
                                    observer(message)
                                }
                            } else if let notification = try? self.decoder.decode(ActionNotification.self, from: data) {
                                handleNotification(notification)
                            }
                        }
                    case .failure(let error):
                        DDLogError("[MQService] Error while listening: \(error)")
                    }
                }
                client.addCloseListener(named: "Drive close listener") { _ in
                    DDLogWarn("[MQService] Connection closed")
                    reconnect()
                }
            } catch {
                DDLogError("[MQService] Error while subscribing: \(error)")
            }
        }
    }

    func reconnect() {
        queue.asyncAfter(deadline: .now() + reconnectionDelay) {
            guard !self.client.isActive() else { return }
            DDLogInfo("[MQService] Reconnecting…")
            do {
                _ = try self.client.connect(cleanSession: false).wait()
                DDLogInfo("[MQService] Connection successful")
                self.reconnections = 0
            } catch {
                DDLogError("[MQService] Error while connecting: \(error)")
                self.reconnect()
            }
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

    private static func generateClientIdentifier() -> String {
        let length = 10
        let prefix = "mqttios_kdrive_"
        let letters = "abcdefghijklmnopqrstuvwxyz"
        return prefix + String((0 ..< length).map { _ in letters.randomElement()! })
    }
}

// MARK: - Observation

public extension MQService {
    typealias ActionId = String

    @discardableResult
    func observeActionProgress<T: AnyObject>(_ observer: T, actionId: ActionId?, using closure: @escaping (ActionProgressNotification) -> Void)
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
