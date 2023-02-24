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

extension UploadOperation {
    func transactionWithFile(_ task: @escaping (_ file: UploadFile) throws -> Void,
                             function: StaticString = #function) throws {
        UploadOperationLog("transactionWithFile \(fileId) in:\(function)")
        var bufferError: Error?
        BackgroundRealm.uploads.execute { uploadsRealm in
            let file: UploadFile? = uploadsRealm.object(ofType: UploadFile.self, forPrimaryKey: self.file)
            guard let file else {
                bufferError = ErrorDomain.databaseUploadFileNotFound
                return
            }
            
            UploadOperationLog("begin transaction fid:\(file.id)")
            do {
                try task(file)
            }
            catch {
                bufferError = error
            }
            UploadOperationLog("end transaction fid:\(file.id)")
        }
        
        if let bufferError {
            throw bufferError
        }
    }
}
