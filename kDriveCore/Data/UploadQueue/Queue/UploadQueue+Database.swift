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

import Foundation
import RealmSwift

extension UploadQueue {
    func transactionWithUploadRealm(function: StaticString = #function, _ task: @escaping (_ realm: Realm) throws -> Void) throws {
//        UploadQueueLog("transactionWithUploadRealm begin in function:\(function)")
        var bufferError: Error?
        autoreleasepool {
            do {
                let uploadsRealm = try Realm(configuration: DriveFileManager.constants.uploadsRealmConfiguration)
                uploadsRealm.refresh()
//                UploadQueueLog("transactionWithUploadRealm before closure in function:\(function)")
                try task(uploadsRealm)
//                UploadQueueLog("transactionWithUploadRealm after closure in function:\(function)")
            } catch {
                bufferError = error
            }
        }

        if let bufferError {
//            UploadQueueLog("transactionWithUploadRealm error:\(bufferError) function:\(function)", level: .error)
            throw bufferError
        }

//        UploadQueueLog("transactionWithUploadRealm end in function:\(function)")
    }
}
