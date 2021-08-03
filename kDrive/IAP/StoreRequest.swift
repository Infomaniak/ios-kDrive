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

import Alamofire
import Foundation

struct ReceiptInfo: Encodable {
    let latestReceipt: String
    let userId: Int
    let itemId: Int
    let productId: String
    let transactionId: String
    let bundleId: String
}

class StoreRequest {
    static let shared = StoreRequest()

    let url = "https://api.devd257.dev.infomaniak.ch/invoicing/inapp/apple/link_receipt"

    private lazy var parameterEncoder: JSONParameterEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return JSONParameterEncoder(encoder: encoder)
    }()

    private init() {}

    func sendReceipt(body: ReceiptInfo) {
        AF.request(url, method: .post, parameters: body, encoder: parameterEncoder)
            .validate()
            .response { response in
                debugPrint(response)
            }
    }
}
