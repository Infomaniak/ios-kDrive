/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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

// MARK: - Type definition

enum ApiEnvironment {
    case prod, preprod

    var host: String {
        switch self {
        case .prod:
            return "api.infomaniak.com"
        case .preprod:
            return "api.preprod.dev.infomaniak.ch"
        }
    }
}

struct Endpoint {
    let path: String
    let queryItems: [URLQueryItem]?
    let apiEnvironment: ApiEnvironment = .preprod

    var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = apiEnvironment.host
        components.path = "/2/drive\(path)"
        components.queryItems = queryItems

        guard let url = components.url else {
            fatalError("Invalid endpoint URL: \(self)")
        }
        return url
    }

    func appending(path: String, queryItems: [URLQueryItem]? = nil) -> Endpoint {
        return Endpoint(path: self.path + path, queryItems: queryItems)
    }
}

// MARK: - Proxies

protocol AbstractDrive {
    var id: Int { get set }
}

class ProxyDrive: AbstractDrive {
    var id: Int

    init(id: Int) {
        self.id = id
    }
}

extension Drive: AbstractDrive {}

protocol AbstractFile {
    var driveId: Int { get set }
    var id: Int { get set }
}

class ProxyFile: AbstractFile {
    var driveId: Int
    var id: Int

    init(driveId: Int, id: Int) {
        self.driveId = driveId
        self.id = id
    }
}

extension File: AbstractFile {}

// MARK: - Endpoints

extension Endpoint {
    // MARK: Action

    static func undoAction(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/cancel")
    }

    // MARK: Activities

    static func fileActivities(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/activities")
    }

    static func notifications(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/notifications")
    }

    static func fileActivities(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/activities")
    }

    static func trashedFileActivities(file: AbstractFile) -> Endpoint {
        return .trashedInfo(file: file).appending(path: "/activities")
    }

    // MARK: Archive

    static func buildArchive(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/archives")
    }

    static func getArchive(drive: AbstractDrive, uuid: String) -> Endpoint {
        return .buildArchive(drive: drive).appending(path: "/\(uuid)")
    }

    // MARK: Comment

    static func comments(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/comments")
    }

    static func comment(file: AbstractFile, comment: Comment) -> Endpoint {
        return .comments(file: file).appending(path: "/\(comment.id)")
    }

    static func likeComment(file: AbstractFile, comment: Comment) -> Endpoint {
        return .comment(file: file, comment: comment).appending(path: "/like")
    }

    static func unlikeComment(file: AbstractFile, comment: Comment) -> Endpoint {
        return .comment(file: file, comment: comment).appending(path: "/unlike")
    }

    // MARK: Drive (complete me)

    static func driveInfo(drive: AbstractDrive) -> Endpoint {
        return Endpoint(path: "/\(drive.id)", queryItems: nil)
    }

    static func driveUsers(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/account/user")
    }

    static func driveSettings(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/settings")
    }

    // MARK: Dropbox

    static func dropboxes(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/dropboxes")
    }

    static func dropbox(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/dropbox")
    }

    static func dropboxInvite(file: AbstractFile) -> Endpoint {
        return .dropbox(file: file).appending(path: "/invite")
    }

    // MARK: Favorite

    static func favorites(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/favorites")
    }

    static func favorite(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/favorite")
    }

    // MARK: File access

    static func invitation(drive: AbstractDrive, id: Int) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/invitations/\(id)")
    }

    static func access(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/access")
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

    static func teajPermission(file: AbstractFile) -> Endpoint {
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

    static func fileInfo(_ file: AbstractFile) -> Endpoint {
        return .driveInfo(drive: ProxyDrive(id: file.driveId)).appending(path: "/files/\(file.id)")
    }

    static func files(of directory: AbstractFile) -> Endpoint {
        return .fileInfo(directory).appending(path: "/files")
    }

    static func createDirectory(in file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/directory")
    }

    static func createFile(in file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/file")
    }

    static func thumbnail(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/thumbnail")
    }

    static func preview(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/preview")
    }

    static func download(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/download")
    }

    static func convert(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/convert")
    }

    static func move(file: AbstractFile, destinationId: Int) -> Endpoint {
        return .fileInfo(file).appending(path: "/move/\(destinationId)")
    }

    static func duplicate(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/copy")
    }

    static func copy(file: AbstractFile, destinationId: Int) -> Endpoint {
        return .duplicate(file: file).appending(path: "/\(destinationId)")
    }

    static func rename(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/rename")
    }

    static func count(of directory: AbstractFile) -> Endpoint {
        return .fileInfo(directory).appending(path: "/count")
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
        return .fileInfo(file).appending(path: "/color")
    }

    // MARK: Preferences

    static var userPreferences: Endpoint {
        return Endpoint(path: "/preferences", queryItems: nil)
    }

    static func preferences(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/preference")
    }

    // MARK: Root directory

    static func lockedFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/lock")
    }

    // MARK: Search

    // MARK: Share link

    // MARK: Trash

    static func trash(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/trash")
    }

    static func trashCount(drive: AbstractDrive) -> Endpoint {
        return .trash(drive: drive).appending(path: "/count")
    }

    static func trashedInfo(file: AbstractFile) -> Endpoint {
        return .trash(drive: ProxyDrive(id: file.driveId)).appending(path: "/\(file.id)")
    }

    static func trashedFiles(of directory: AbstractFile) -> Endpoint {
        return .trashedInfo(file: directory).appending(path: "/files")
    }

    static func restore(file: AbstractFile) -> Endpoint {
        return .trashedInfo(file: file).appending(path: "/restore")
    }

    static func trashThumbnail(file: AbstractFile) -> Endpoint {
        return .trashedInfo(file: file).appending(path: "/thumbnail")
    }

    static func trashCount(of directory: AbstractFile) -> Endpoint {
        return .trashedInfo(file: directory).appending(path: "/count")
    }

    // MARK: Upload

    // MARK: User invitation

    static func userInvitations(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/user/invitation")
    }

    static func userInvitation(drive: AbstractDrive, id: Int) -> Endpoint {
        return .userInvitations(drive: drive).appending(path: "/\(id)")
    }

    static func sendUserInvitation(drive: AbstractDrive, id: Int) -> Endpoint {
        return .userInvitation(drive: drive, id: id).appending(path: "/send")
    }
}
