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
//                    UploadOperationLog("file not found in:\(function) fid:\(self.fileId)")
                    throw ErrorDomain.databaseUploadFileNotFound
                }

//                UploadOperationLog("begin transaction in:\(function) fid:\(self.fileId)")
                try uploadsRealm.write {
                    guard !file.isInvalidated else {
//                        UploadOperationLog("invalidated file in:\(function) fid:\(self.fileId)")
                        throw ErrorDomain.databaseUploadFileNotFound
                    }
                    try task(file)
                    uploadsRealm.add(file, update: .modified)
                }
//                UploadOperationLog("end transaction in:\(function) fid:\(self.fileId)")
            } catch {
//                UploadOperationLog("transaction error:\(error) in:\(function) fid:\(self.fileId)", level: .error)
                bufferError = error
            }
        }

        if let bufferError {
            throw bufferError
        }
    }
}
