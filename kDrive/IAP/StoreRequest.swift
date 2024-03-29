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
import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import kDriveCore

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

    let jsonDecoder = JSONDecoder()

    private init() {
        // META: keep SonarCloud happy
    }

    func sendReceipt(body: ReceiptInfo) {
        AF.request(Endpoint.inAppReceipt.url, method: .post, parameters: body, encoder: JSONParameterEncoder.convertToSnakeCase)
            .validate()
            .responseDecodable(of: ApiResponse<Bool>.self, decoder: jsonDecoder) { response in
                switch response.result {
                case .success(let result):
                    if let data = result.data, data {
                        DDLogInfo("[StoreRequest] Success")
                    } else {
                        DDLogError("[StoreRequest] Server error")
                        if let error = result.error {
                            DDLogError("[StoreRequest] \(error)")
                            SentryDebug.capture(error: error)
                        }
                    }
                case .failure(let error):
                    DDLogError("[StoreRequest] Client error: \(error)")
                }
            }
    }
}
