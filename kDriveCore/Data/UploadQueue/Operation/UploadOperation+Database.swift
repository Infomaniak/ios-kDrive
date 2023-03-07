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

extension UploadOperation {
    func transactionWithFile(function: StaticString = #function, _ task: @escaping (_ file: UploadFile) throws -> Void) throws {
//        UploadOperationLog("transactionWithFile in:\(function) fid:\(self.fileId)")
        var bufferError: Error?
        autoreleasepool {
            do {
                let uploadsRealm = try Realm(configuration: DriveFileManager.constants.uploadsRealmConfiguration)
                uploadsRealm.refresh()

                guard let file = uploadsRealm.object(ofType: UploadFile.self, forPrimaryKey: self.fileId), !file.isInvalidated else {
                    bufferError = ErrorDomain.databaseUploadFileNotFound
//                    UploadOperationLog("invalidated file fid:\(self.fileId)")
                    return
                }

//                UploadOperationLog("begin transaction fid:\(self.fileId)")
                try uploadsRealm.safeWrite {
                    guard file.isInvalidated == false else {
                        bufferError = ErrorDomain.databaseUploadFileNotFound
//                        UploadOperationLog("invalidated file fid:\(self.fileId)")
                        return
                    }
                    try task(file)
                }
            }
            catch {
                bufferError = error
            }
        }

//        UploadOperationLog("end transaction in:\(function) fid:\(self.fileId)")
        if let bufferError {
            throw bufferError
        }
    }
}
