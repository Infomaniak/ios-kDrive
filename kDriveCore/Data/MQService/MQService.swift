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

import CocoaMQTT
import CocoaMQTTWebSocket
import Foundation

public class MQService {
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private lazy var webSocket: CocoaMQTTWebSocket = {
        let webSocket = CocoaMQTTWebSocket(uri: "/ws")
        webSocket.enableSSL = true
        return webSocket
    }()

    private lazy var mqtt: CocoaMQTT = {
        let mqtt = CocoaMQTT(clientID: "", host: "info-mq.infomaniak.com", port: 443, socket: webSocket)
        mqtt.username = "ips:ips-public"
        mqtt.password = "8QC5EwBqpZ2Z"
        mqtt.delegate = self
        mqtt.keepAlive = 30
        mqtt.autoReconnect = true
        mqtt.autoReconnectTimeInterval = 20
        return mqtt
    }()

    private var currentToken: IPSToken?
    private var actionProgressObservers = [UUID: (ActionProgressNotification) -> Void]()

    public init() {
        _ = mqtt.connect(timeout: 20)
    }

    public func registerForNotifications(with token: IPSToken) {
        if let currentToken = currentToken {
            actionProgressObservers.removeAll()
            mqtt.unsubscribe(topicFor(token: currentToken))
        }
        currentToken = token
        if !isSubscribed(token: token) {
            mqtt.subscribe(topicFor(token: token))
        }
    }

    private func topicFor(token: IPSToken) -> String {
        return "drive/\(token.uuid)"
    }

    private func isSubscribed(token: IPSToken) -> Bool {
        return mqtt.subscriptions[topicFor(token: token)] != nil
    }
}

// MARK: - CocoaMQTTDelegate

extension MQService: CocoaMQTTDelegate {
    public func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            if let currentToken = currentToken {
                registerForNotifications(with: currentToken)
            }
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        // TODO: Handle disconnect
    }

    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {}

    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}

    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        let data = Data(message.payload)
        if let message = try? decoder.decode(ActionNotification.self, from: data) {
            if let driveFileManager = AccountManager.instance.getDriveFileManager(for: message.driveId, userId: AccountManager.instance.currentUserId),
               let file = driveFileManager.getCachedFile(id: message.parentId) {
                // TODO: Update file
            }
        } else if let message = try? decoder.decode(ActionProgressNotification.self, from: data) {
            for observer in actionProgressObservers.values {
                observer(message)
            }
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {}

    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}

    public func mqttDidPing(_ mqtt: CocoaMQTT) {}

    public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}

    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        // TODO: Handle disconnect
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
