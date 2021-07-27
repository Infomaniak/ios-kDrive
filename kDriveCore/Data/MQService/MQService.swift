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
import MQTTNIO

public class MQService {
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private var queue = DispatchQueue(label: "com.infomaniak.mqservice")

    private lazy var mqtt: MQTTClient = {
        var configuration = MQTTClient.Configuration(
            keepAliveInterval: .seconds(30),
            connectTimeout: .seconds(20),
            userName: "ips:ips-public",
            password: "8QC5EwBqpZ2Z",
            useSSL: true,
            useWebSockets: true,
            webSocketURLPath: "/ws"
        )

        let client = MQTTClient(
            host: "info-mq.infomaniak.com",
            port: 443,
            identifier: "MQTT",
            eventLoopGroupProvider: .createNew,
            configuration: configuration
        )

        return client
    }()

    private var currentToken: IPSToken?
    private var actionProgressObservers = [UUID: (ActionProgressNotification) -> Void]()

    public init() {}

    public func registerForNotifications(with token: IPSToken) {
        queue.async { [self] in
            if !mqtt.isActive() {
                do {
                    _ = try mqtt.connect().wait()
                } catch {
                    DDLogError("[MQService] Error while connecting \(error)")
                }
            }
            if let currentToken = currentToken {
                actionProgressObservers.removeAll()
                do {
                    try mqtt.unsubscribe(from: [topicFor(token: currentToken)]).wait()
                } catch {
                    DDLogError("[MQService] Error while unsubscribing \(error)")
                }
            }
            currentToken = token
            do {
                _ = try mqtt.subscribe(to: [MQTTSubscribeInfo(topicFilter: topicFor(token: token), qos: .exactlyOnce)]).wait()
                mqtt.addPublishListener(named: "Drive notifications listener") { result in
                    switch result {
                    case .success(let message):
                        var buffer = message.payload
                        if let data = buffer.readData(length: buffer.readableBytes) {
                            if let message = try? self.decoder.decode(ActionProgressNotification.self, from: data) {
                                for observer in self.actionProgressObservers.values {
                                    observer(message)
                                }
                            }
                        }
                    case .failure(let error):
                        DDLogError("[MQService] Error while listening \(error)")
                    }
                }
            } catch {
                DDLogError("[MQService] Error while subscribing \(error)")
            }
        }
    }

    private func topicFor(token: IPSToken) -> String {
        return "drive/\(token.uuid)"
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

            if action.progress.message == "done" {
                self?.actionProgressObservers.removeValue(forKey: key)
            }
        }

        return ObservationToken { [weak self] in
            self?.actionProgressObservers.removeValue(forKey: key)
        }
    }
}
