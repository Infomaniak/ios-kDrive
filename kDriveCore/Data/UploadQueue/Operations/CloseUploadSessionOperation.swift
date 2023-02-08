//
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
import InfomaniakDI

public final class CloseUploadSessionOperation: AsynchronousOperation {
    @LazyInjectService var accountManager: AccountManageable

    let file: UploadFile
    let sessionToken: String
    
    required init(file: UploadFile, sessionToken: String) {
        self.file = file
        self.sessionToken = sessionToken
        
        CloseUploadSessionOperationLog("init \(file.id)")
    }
 
    override public func execute() async {
        CloseUploadSessionOperationLog("execute \(file.id)")
        
        // Try to close the upload
        guard let driveFileManager = accountManager.getDriveFileManager(for: accountManager.currentDriveId,
                                                                        userId: accountManager.currentUserId) else {
            CloseUploadSessionOperationLog("Failed to getDriveFileManager fid:\(file.id) userId:\(accountManager.currentUserId)",
                                           level: .error)
            file.error = .localError
            end()
            return
        }

        let apiFetcher = driveFileManager.apiFetcher
        let drive = driveFileManager.drive
        let abstractToken = AbstractTokenWrapper(token: self.sessionToken)
        
        do {
            let uploadedFile = try await apiFetcher.closeSession(drive: drive, sessionToken: abstractToken)
            CloseUploadSessionOperationLog("uploadedFile:\(uploadedFile) fid:\(file.id)")
            
            // TODO: Store file to DB
            // and signal upload success / refresh UI
        }
        catch {
            CloseUploadSessionOperationLog("closeSession error:\(error) fid:\(file.id)",
                                           level: .error)
        }
        
        end()
    }
    
    private func end() {
        // Terminate the NSOperation
        CloseUploadSessionOperationLog("call finish \(file.id)")
        finish()
    }
    
}
