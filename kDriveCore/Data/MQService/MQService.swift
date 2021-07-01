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
    public init() {
        let websocket = CocoaMQTTWebSocket(uri: "/ws")
        websocket.enableSSL = true
        let mqtt = CocoaMQTT(clientID: "", host: "info-mq.infomaniak.com", port: 443, socket: websocket)
        mqtt.username = "ips:ips-public"
        mqtt.password = "8QC5EwBqpZ2Z"
        mqtt.delegate = self
        mqtt.keepAlive = 30
        mqtt.connect(timeout: 20)
    }
}

extension MQService: CocoaMQTTDelegate {
    public func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        print("trust: \(trust)")
        completionHandler(true)
    }

    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("ack: \(ack)")

        if ack == .accept {
            mqtt.subscribe("drive/5e1f23fe-614b-416d-b0ac-a4fb7edebe8c", qos: CocoaMQTTQoS.qos1)
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        print("new state: \(state)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print("message: \(message.string?.description), id: \(id)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        print("id: \(id)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        print("message: \(message.string?.description), id: \(id)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print("subscribed: \(success), failed: \(failed)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        print("topic: \(topics)")
    }

    public func mqttDidPing(_ mqtt: CocoaMQTT) {
        print()
    }

    public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        print()
    }

    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        print("\(err?.localizedDescription)")
    }
}
