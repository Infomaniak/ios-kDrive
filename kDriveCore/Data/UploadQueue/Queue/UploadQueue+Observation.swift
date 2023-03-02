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

import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import RealmSwift
import Sentry

public typealias UploadedFileId = String
public typealias UploadProgress = Double

public protocol UploadQueueObservable {
    
    @discardableResult
    func observeFileUploaded<T: AnyObject>(_ observer: T,
                                           fileId: String?,
                                           using closure: @escaping (UploadFile, File?) -> Void) -> ObservationToken
    
    @discardableResult
    func observeUploadCount<T: AnyObject>(_ observer: T,
                                          parentId: Int,
                                          using closure: @escaping (Int, Int) -> Void) -> ObservationToken
 
    @discardableResult
    func observeUploadCount<T: AnyObject>(_ observer: T,
                                          driveId: Int,
                                          using closure: @escaping (Int, Int) -> Void) -> ObservationToken
}

// MARK: - Observation

extension UploadQueue: UploadQueueObservable {

    @discardableResult
    public func observeFileUploaded<T: AnyObject>(_ observer: T,
                                           fileId: String? = nil,
                                           using closure: @escaping (UploadFile, File?) -> Void) -> ObservationToken {
        let key = UUID()
        observations.didUploadFile[key] = { [weak self, weak observer] uploadFile, driveFile in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.observations.didUploadFile.removeValue(forKey: key)
                return
            }

            if fileId == nil || uploadFile.id == fileId {
                closure(uploadFile, driveFile)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didUploadFile.removeValue(forKey: key)
        }
    }

    @discardableResult
    public func observeUploadCount<T: AnyObject>(_ observer: T,
                                                 parentId: Int,
                                                 using closure: @escaping (Int, Int) -> Void) -> ObservationToken {
        let key = UUID()
        observations.didChangeUploadCountInParent[key] = { [weak self, weak observer] updatedParentId, count in
            guard observer != nil else {
                self?.observations.didChangeUploadCountInParent.removeValue(forKey: key)
                return
            }

            if parentId == updatedParentId {
                closure(updatedParentId, count)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didChangeUploadCountInParent.removeValue(forKey: key)
        }
    }

    @discardableResult
    public func observeUploadCount<T: AnyObject>(_ observer: T,
                                          driveId: Int,
                                          using closure: @escaping (Int, Int) -> Void) -> ObservationToken {
        let key = UUID()
        observations.didChangeUploadCountInDrive[key] = { [weak self, weak observer] updatedDriveId, count in
            guard observer != nil else {
                self?.observations.didChangeUploadCountInDrive.removeValue(forKey: key)
                return
            }

            if driveId == updatedDriveId {
                closure(updatedDriveId, count)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didChangeUploadCountInDrive.removeValue(forKey: key)
        }
    }
}
