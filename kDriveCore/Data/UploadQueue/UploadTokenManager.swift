/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import RealmSwift
import Sentry
import InfomaniakDI

public class UploadTokenManager {
    public static let instance = UploadTokenManager() // TODO migrate
    
    @InjectService var accountManager: AccountManageable

    private var tokens: [Int: UploadToken] = [:]
    private var lock = DispatchGroup()

    public func getToken(userId: Int, driveId: Int, completionHandler: @escaping (UploadToken?) -> Void) {
        lock.wait()
        lock.enter()
        if let token = tokens[userId], !token.isNearlyExpired {
            completionHandler(token)
            lock.leave()
        } else if let userToken = accountManager.getTokenForUserId(userId),
                  let drive = accountManager.getDrive(for: userId, driveId: driveId, using: nil),
                  let driveFileManager = accountManager.getDriveFileManager(for: drive) {
            driveFileManager.apiFetcher.getPublicUploadToken(with: userToken, drive: drive) { result in
                switch result {
                case .success(let token):
                    self.tokens[userId] = token
                    completionHandler(token)
                case .failure(let error):
                    DDLogError("[UploadOperation] Error while trying to get upload token: \(error)")
                    completionHandler(nil)
                }
                self.lock.leave()
            }
        } else {
            completionHandler(nil)
            lock.leave()
        }
    }
}
