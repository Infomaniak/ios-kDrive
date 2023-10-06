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
    /// The standard way to interact with a UploadFile within an UploadOperation
    ///
    /// Lock access to file if upload operation `isFinished`, by throwing a `ErrorDomain.operationFinished`
    /// - Parameters:
    ///   - function: The name of the function performing the transaction
    ///   - task: A closure to mutate the current `UploadFile`
    func transactionWithFile(function: StaticString = #function, _ task: @escaping (_ file: UploadFile) throws -> Void) throws {
        /// A cancelled operation can access database for cleanup, _not_ a finished one.
        guard !isFinished else {
            throw ErrorDomain.operationFinished
        }

        try autoreleasepool {
            let uploadsRealm = try Realm(configuration: DriveFileManager.constants.uploadsRealmConfiguration)
            uploadsRealm.refresh()

            guard let file = uploadsRealm.object(ofType: UploadFile.self, forPrimaryKey: self.uploadFileId),
                  !file.isInvalidated else {
                throw ErrorDomain.databaseUploadFileNotFound
            }

            try uploadsRealm.write {
                guard !file.isInvalidated else {
                    throw ErrorDomain.databaseUploadFileNotFound
                }
                try task(file)
                uploadsRealm.add(file, update: .modified)
            }
        }
    }

    /// Provides a read only and detached  `UploadFile`, regardless of the state of the operation.
    ///
    /// Throws if any DB access issues
    /// Does not check upload.finished state of the upload operation
    func readOnlyFile() throws -> UploadFile {
        return try autoreleasepool {
            let uploadsRealm = try Realm(configuration: DriveFileManager.constants.uploadsRealmConfiguration)
            uploadsRealm.refresh()

            guard let file = uploadsRealm.object(ofType: UploadFile.self, forPrimaryKey: self.uploadFileId),
                  !file.isInvalidated else {
                throw ErrorDomain.databaseUploadFileNotFound
            }

            return file.detached()
        }
    }
}
