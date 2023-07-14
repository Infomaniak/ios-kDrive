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
    /// Observe the upload of a file
    /// - Parameters:
    ///   - observer: The observer type
    ///   - fileId: The Id of the file to observe
    ///   - closure: Called on completion, in MainQueue
    /// - Returns: A token that should be cancelled first thing in your `closure`
    @discardableResult
    func observeFileUploaded<T: AnyObject>(_ observer: T,
                                           fileId: String?,
                                           using closure: @escaping (UploadFile, File?) -> Void) -> ObservationToken

    /// Observe Uploaded files within a specific folder.
    /// - Parameters:
    ///   - observer: The observer type
    ///   - parentId: parent Id
    ///   - closure: Called on completion, in MainQueue
    /// - Returns: A token that should be cancelled first thing in your `closure`
    @discardableResult
    func observeUploadCount<T: AnyObject>(_ observer: T,
                                          parentId: Int,
                                          using closure: @escaping (Int, Int) -> Void) -> ObservationToken

    /// Observe the count of uploaded files within a Drive
    /// - Parameters:
    ///   - observer: The observer type
    ///   - driveId: drive Id
    ///   - closure: Called on completion, in MainQueue
    /// - Returns: A token that should be cancelled first thing in your `closure`
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
        var token: ObservationToken!
        serialQueue.sync { [unowned self] in
            let key = UUID()
            observations.didUploadFile[key] = { [unowned self, weak observer] uploadFile, driveFile in
                // If the observer has been deallocated, we can
                // automatically remove the observation closure.
                guard observer != nil else {
                    observations.didUploadFile.removeValue(forKey: key)
                    return
                }

                if fileId == nil || uploadFile.id == fileId {
                    DispatchQueue.main.async {
                        closure(uploadFile, driveFile)
                    }
                }
            }

            token = ObservationToken { [unowned self] in
                observations.didUploadFile.removeValue(forKey: key)
            }
        }
        return token
    }

    @discardableResult
    public func observeUploadCount<T: AnyObject>(_ observer: T,
                                                 parentId: Int,
                                                 using closure: @escaping (Int, Int) -> Void) -> ObservationToken {
        var token: ObservationToken!
        serialQueue.sync { [unowned self] in
            let key = UUID()
            observations.didChangeUploadCountInParent[key] = { [unowned self, weak observer] updatedParentId, count in
                guard observer != nil else {
                    observations.didChangeUploadCountInParent.removeValue(forKey: key)
                    return
                }

                if parentId == updatedParentId {
                    DispatchQueue.main.async {
                        closure(updatedParentId, count)
                    }
                }
            }

            token = ObservationToken { [unowned self] in
                observations.didChangeUploadCountInParent.removeValue(forKey: key)
            }
        }
        return token
    }

    @discardableResult
    public func observeUploadCount<T: AnyObject>(_ observer: T,
                                                 driveId: Int,
                                                 using closure: @escaping (Int, Int) -> Void) -> ObservationToken {
        var token: ObservationToken!
        serialQueue.sync { [unowned self] in
            let key = UUID()
            observations.didChangeUploadCountInDrive[key] = { [unowned self, weak observer] updatedDriveId, count in
                guard observer != nil else {
                    observations.didChangeUploadCountInDrive.removeValue(forKey: key)
                    return
                }

                if driveId == updatedDriveId {
                    DispatchQueue.main.async {
                        closure(updatedDriveId, count)
                    }
                }
            }

            token = ObservationToken { [unowned self] in
                observations.didChangeUploadCountInDrive.removeValue(forKey: key)
            }
        }
        return token
    }
}
