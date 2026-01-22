/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import InfomaniakCore
import RealmSwift

// MARK: - Files

public extension Endpoint {
    // MARK: Dropbox

    static func dropboxes(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/dropboxes")
    }

    static func dropbox(file: AbstractFile) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/dropbox", queryItems: [
            URLQueryItem(name: "with", value: "user,capabilities")
        ])
    }

    static func dropboxInvite(file: AbstractFile) -> Endpoint {
        return .dropbox(file: file).appending(path: "/invite")
    }

    // MARK: Favorite

    static func favorites(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/favorites", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func favorite(file: AbstractFile) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/favorite")
    }

    // MARK: File access

    static func invitation(drive: AbstractDrive, id: Int) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/files/invitations/\(id)")
    }

    static func access(file: AbstractFile) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/access", queryItems: [
            URLQueryItem(name: "with", value: "user"),
            noAvatarDefault()
        ])
    }

    static func checkAccess(file: AbstractFile) -> Endpoint {
        return .access(file: file).appending(path: "/check")
    }

    static func invitationsAccess(file: AbstractFile) -> Endpoint {
        return .access(file: file).appending(path: "/invitations")
    }

    static func teamsAccess(file: AbstractFile) -> Endpoint {
        return .access(file: file).appending(path: "/teams")
    }

    static func teamAccess(file: AbstractFile, id: Int) -> Endpoint {
        return .teamsAccess(file: file).appending(path: "/\(id)")
    }

    static func usersAccess(file: AbstractFile) -> Endpoint {
        return .access(file: file).appending(path: "/users")
    }

    static func userAccess(file: AbstractFile, id: Int) -> Endpoint {
        return .usersAccess(file: file).appending(path: "/\(id)")
    }

    static func userDriveAccess(drive: ProxyDrive, userId: Int) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/users/\(userId)")
    }

    static func forceAccess(file: AbstractFile) -> Endpoint {
        return .access(file: file).appending(path: "/force")
    }

    // MARK: File permission

    static func acl(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/acl")
    }

    static func permissions(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/permission")
    }

    static func userPermission(file: AbstractFile) -> Endpoint {
        return .permissions(file: file).appending(path: "/user")
    }

    static func teamPermission(file: AbstractFile) -> Endpoint {
        return .permissions(file: file).appending(path: "/team")
    }

    static func inheritPermission(file: AbstractFile) -> Endpoint {
        return .permissions(file: file).appending(path: "/inherit")
    }

    static func permission(file: AbstractFile, id: Int) -> Endpoint {
        return .permissions(file: file).appending(path: "/\(id)")
    }

    // MARK: File version

    static func versions(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/versions")
    }

    static func version(file: AbstractFile, id: Int) -> Endpoint {
        return .versions(file: file).appending(path: "/\(id)")
    }

    static func downloadVersion(file: AbstractFile, id: Int) -> Endpoint {
        return .version(file: file, id: id).appending(path: "/download")
    }

    static func restoreVersion(file: AbstractFile, id: Int) -> Endpoint {
        return .version(file: file, id: id).appending(path: "/restore")
    }

    // MARK: File/directory

    static func file(_ file: AbstractFile) -> Endpoint {
        return .driveInfo(drive: ProxyDrive(id: file.driveId)).appending(path: "/files/\(file.id)",
                                                                         queryItems: [FileWith.fileExtra.toQueryItem()])
    }

    static func fileInfo(_ file: AbstractFile) -> Endpoint {
        return .driveInfo(drive: ProxyDrive(id: file.driveId)).appending(
            path: "/files/\(file.id)",
            queryItems: [FileWith.fileExtra.toQueryItem(), noAvatarDefault()]
        )
    }

    static func fileInfoV2(_ file: AbstractFile) -> Endpoint {
        return .driveInfoV2(drive: ProxyDrive(id: file.driveId)).appending(path: "/files/\(file.id)",
                                                                           queryItems: [FileWith.fileExtra.toQueryItem()])
    }

    static func files(of directory: AbstractFile) -> Endpoint {
        return .fileInfo(directory).appending(path: "/files", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func createDirectory(in file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/directory", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func createFile(in file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/file", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func thumbnail(file: AbstractFile, at date: Date) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/thumbnail", queryItems: [
            URLQueryItem(name: "t", value: "\(Int(date.timeIntervalSince1970))")
        ])
    }

    static func preview(file: AbstractFile, at date: Date) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/preview", queryItems: [
            URLQueryItem(name: "width", value: "2500"),
            URLQueryItem(name: "height", value: "1500"),
            URLQueryItem(name: "quality", value: "80"),
            URLQueryItem(name: "t", value: "\(Int(date.timeIntervalSince1970))")
        ])
    }

    static func download(file: AbstractFile,
                         publicShareProxy: PublicShareProxy? = nil,
                         as asType: String? = nil) -> Endpoint {
        let queryItems: [URLQueryItem]?
        if let asType {
            queryItems = [URLQueryItem(name: "as", value: asType)]
        } else {
            queryItems = nil
        }
        if let publicShareProxy {
            return .downloadShareLinkFile(driveId: publicShareProxy.driveId,
                                          linkUuid: publicShareProxy.shareLinkUid,
                                          fileId: file.id,
                                          token: publicShareProxy.token)
        } else {
            return .fileInfoV2(file).appending(path: "/download", queryItems: queryItems)
        }
    }

    static func convert(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/convert", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func move(file: AbstractFile, destination: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/move/\(destination.id)")
    }

    static func duplicate(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/duplicate", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func copy(file: AbstractFile, destination: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/copy/\(destination.id)", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func rename(file: AbstractFile) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/rename", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func count(of directory: AbstractFile) -> Endpoint {
        return .fileInfoV2(directory).appending(path: "/count")
    }

    static func size(file: AbstractFile, depth: String) -> Endpoint {
        return .fileInfo(file).appending(path: "/size", queryItems: [
            URLQueryItem(name: "depth", value: depth)
        ])
    }

    static func unlock(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/lock")
    }

    static func directoryColor(file: AbstractFile) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/color")
    }

    // MARK: Root directory

    static func lockedFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/lock")
    }

    static func rootFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/1/files", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func bulkFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/files/bulk")
    }

    static func lastModifiedFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/last_modified", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func largestFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/largest")
    }

    static func mostVersionedFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/most_versions")
    }

    static func countByTypeFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/file_types")
    }

    static func createTeamDirectory(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/team_directory", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func existFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/exists")
    }

    static func sharedFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/shared")
    }

    static func mySharedFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(
            path: "/files/my_shared",
            queryItems: [(FileWith.fileMinimal + [.users]).toQueryItem(), noAvatarDefault()]
        )
    }

    static func sharedWithMeFiles(drive: AbstractDrive) -> Endpoint {
        return .driveV3.appending(path: "/files/shared_with_me",
                                  queryItems: [(FileWith.fileMinimal).toQueryItem()])
    }

    static func countInRoot(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/count")
    }

    // MARK: Listing

    static func fileListing(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/listing", queryItems: [FileWith.fileListingMinimal.toQueryItem()])
    }

    static func fileListingContinue(file: AbstractFile, cursor: String) -> Endpoint {
        return .fileInfo(file).appending(path: "/listing/continue", queryItems: [URLQueryItem(name: "cursor", value: cursor),
                                                                                 FileWith.fileListingMinimal.toQueryItem()])
    }

    static func filePartialListing(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(
            path: "/files/listing/partial",
            queryItems: [URLQueryItem(name: "with", value: "file")]
        )
    }
}
