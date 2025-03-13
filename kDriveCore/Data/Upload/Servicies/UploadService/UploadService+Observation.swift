/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

public typealias UploadedFileId = String
public typealias UploadProgress = Double

public protocol UploadObservable {
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

extension UploadService: UploadObservable {
    @discardableResult
    public func observeFileUploaded<T: AnyObject>(_ observer: T,
                                                  fileId: String? = nil,
                                                  using closure: @escaping (UploadFile, File?) -> Void) -> ObservationToken {
        var token: ObservationToken!
        serialQueue.sync { [weak self] in
            guard let self else { return }
            let key = UUID()
            observations.didUploadFile[key] = { [weak self, weak observer] uploadFile, driveFile in
                guard let self else { return }
                // If the observer has been deallocated, we can
                // automatically remove the observation closure.
                guard observer != nil else {
                    observations.didUploadFile.removeValue(forKey: key)
                    return
                }

                if fileId == nil || uploadFile.id == fileId {
                    Task { @MainActor in
                        closure(uploadFile, driveFile)
                    }
                }
            }

            token = ObservationToken { [weak self] in
                guard let self else { return }
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
        serialQueue.sync { [weak self] in
            guard let self else { return }
            let key = UUID()
            observations.didChangeUploadCountInParent[key] = { [weak self, weak observer] updatedParentId, count in
                guard let self else { return }
                guard observer != nil else {
                    observations.didChangeUploadCountInParent.removeValue(forKey: key)
                    return
                }

                if parentId == updatedParentId {
                    Task { @MainActor in
                        closure(updatedParentId, count)
                    }
                }
            }

            token = ObservationToken { [weak self] in
                guard let self else { return }
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
        serialQueue.sync { [weak self] in
            guard let self else { return }
            let key = UUID()
            observations.didChangeUploadCountInDrive[key] = { [weak self, weak observer] updatedDriveId, count in
                guard let self else { return }
                guard observer != nil else {
                    observations.didChangeUploadCountInDrive.removeValue(forKey: key)
                    return
                }

                if driveId == updatedDriveId {
                    Task { @MainActor in
                        closure(updatedDriveId, count)
                    }
                }
            }

            token = ObservationToken { [weak self] in
                guard let self else { return }
                observations.didChangeUploadCountInDrive.removeValue(forKey: key)
            }
        }
        return token
    }
}
