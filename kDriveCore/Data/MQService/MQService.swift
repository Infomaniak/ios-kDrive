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
    private let webSocket: CocoaMQTTWebSocket
    private let mqtt: CocoaMQTT
    private var currentToken: IPSToken?

    public init() {
        webSocket = CocoaMQTTWebSocket(uri: "/ws")
        webSocket.enableSSL = true
        mqtt = CocoaMQTT(clientID: "", host: "info-mq.infomaniak.com", port: 443, socket: webSocket)
        mqtt.username = "ips:ips-public"
        mqtt.password = "8QC5EwBqpZ2Z"
        mqtt.delegate = self
        mqtt.keepAlive = 30
        _ = mqtt.connect(timeout: 20)
    }

    public func registerForNotifications(with token: IPSToken) {
        if let currentToken = currentToken {
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
        if let message = String(data: data, encoding: .utf8) {
            print(message)
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print("subscribed: \(success), failed: \(failed)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}

    public func mqttDidPing(_ mqtt: CocoaMQTT) {}

    public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}

    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        // TODO: Handle disconnect
    }
}
