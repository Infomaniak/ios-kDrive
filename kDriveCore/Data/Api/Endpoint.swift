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
import InfomaniakCore
import RealmSwift

// MARK: - Type definition

public extension ApiEnvironment {
    var driveHost: String {
        return "kdrive.\(host)"
    }

    var apiDriveHost: String {
        return "api.\(driveHost)"
    }

    var onlyOfficeDocumentServerHost: String {
        return "documentserver.\(driveHost)"
    }

    var mqttHost: String {
        switch self {
        case .prod:
            return "info-mq.infomaniak.com"
        case .preprod:
            return "preprod-info-mq.infomaniak.com"
        }
    }

    var mqttPass: String {
        switch self {
        case .prod:
            return "8QC5EwBqpZ2Z"
        case .preprod:
            return "4fBt5AdC2P"
        }
    }
}

public extension Endpoint {
    static let itemsPerPage = 200

    func paginated(page: Int = 1) -> Endpoint {
        let paginationQueryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(Endpoint.itemsPerPage)")
        ]

        return Endpoint(host: host, path: path, queryItems: (queryItems ?? []) + paginationQueryItems)
    }

    func sorted(by sortTypes: [SortType] = [.type, .nameAZ]) -> Endpoint {
        var sortQueryItems = [
            URLQueryItem(name: "order_by", value: sortTypes.map(\.value.apiValue).joined(separator: ","))
        ]
        sortQueryItems
            .append(contentsOf: sortTypes.map { URLQueryItem(name: "order_for[\($0.value.apiValue)]", value: $0.value.order) })

        return Endpoint(host: host, path: path, queryItems: (queryItems ?? []) + sortQueryItems)
    }

    func cursored(_ cursor: String?) -> Endpoint {
        let perPage = URLQueryItem(name: "limit", value: "\(Endpoint.itemsPerPage)")
        let cursorQueryItem = cursor != nil ? [URLQueryItem(name: "cursor", value: cursor), perPage] : [perPage]
        return Endpoint(host: host, path: path, queryItems: (queryItems ?? []) + cursorQueryItem)
    }
}

// MARK: - Proxies

/// Something that can represent a string Token
public protocol AbstractToken {
    var token: String { get set }
}

public struct AbstractTokenWrapper: AbstractToken {
    public var token: String
}

public protocol AbstractDrive {
    var id: Int { get set }
}

public struct AbstractDriveWrapper: AbstractDrive {
    public var id: Int
}

public class ProxyDrive: AbstractDrive {
    public var id: Int

    public init(id: Int) {
        self.id = id
    }
}

extension Drive: AbstractDrive {}

public protocol AbstractFile {
    var driveId: Int { get set }
    var id: Int { get set }
}

public struct ProxyFile: AbstractFile, Sendable {
    public var uid: String {
        File.uid(driveId: driveId, fileId: id)
    }

    public var driveId: Int
    public var id: Int
    public var isRoot: Bool {
        return id <= DriveFileManager.constants.rootID
    }

    public init(driveId: Int, id: Int) {
        self.driveId = driveId
        self.id = id
    }

    func resolve(using realm: Realm) throws -> File {
        guard let file = realm.object(ofType: File.self, forPrimaryKey: uid), !file.isInvalidated else {
            throw DriveError.errorWithUserInfo(.fileNotFound, info: [.fileId: ErrorUserInfo(intValue: id)])
        }
        return file
    }
}

extension File: AbstractFile {}

// MARK: - Endpoints

public extension Endpoint {
    private static var driveV3: Endpoint {
        return Endpoint(hostKeypath: \.apiDriveHost, path: "/3/drive")
    }

    static var inAppReceipt: Endpoint {
        return Endpoint(path: "/invoicing/inapp/apple/link_receipt")
    }

    // MARK: V2

    private static var driveV2: Endpoint {
        return Endpoint(hostKeypath: \.apiDriveHost, path: "/2/drive")
    }

    static var initData: Endpoint {
        let queryItems = [
            noAvatarDefault(),
            DriveInitWith.allCases.toQueryItem()
        ]
        return .driveV2.appending(path: "/init", queryItems: queryItems)
    }

    // MARK: Action

    static func undoAction(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/cancel")
    }

    // MARK: Listing

    static func fileListing(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/listing", queryItems: [FileWith.fileListingMinimal.toQueryItem()])
    }

    static func fileListingContinue(file: AbstractFile, cursor: String) -> Endpoint {
        return .fileInfo(file).appending(path: "/listing/continue", queryItems: [URLQueryItem(name: "cursor", value: cursor),
                                                                                 FileWith.fileListingMinimal.toQueryItem()])
    }

    // MARK: Activities

    static func recentActivity(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/activities", queryItems: [
            noAvatarDefault(),
            (FileWith.fileActivities + [.user]).toQueryItem(),
            URLQueryItem(name: "depth", value: "unlimited"),
            URLQueryItem(name: "actions[]", value: "file_create"),
            URLQueryItem(name: "actions[]", value: "file_update"),
            URLQueryItem(name: "actions[]", value: "comment_create"),
            URLQueryItem(name: "actions[]", value: "file_restore"),
            URLQueryItem(name: "actions[]", value: "file_trash")
        ])
    }

    static func notifications(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/notifications")
    }

    static func fileActivities(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/activities")
    }

    static func filesActivities(drive: AbstractDrive, fileIds: [Int], from date: Date) -> Endpoint {
        return .recentActivity(drive: drive).appending(path: "/batch", queryItems: [
            noAvatarDefault(),
            FileWith.fileActivities.toQueryItem(),
            URLQueryItem(name: "actions[]", value: "file_rename"),
            URLQueryItem(name: "actions[]", value: "file_update"),
            URLQueryItem(name: "file_ids", value: fileIds.map(String.init).joined(separator: ",")),
            URLQueryItem(name: "from_date", value: "\(Int(date.timeIntervalSince1970))")
        ])
    }

    static func trashedFileActivities(file: AbstractFile) -> Endpoint {
        return .trashedInfo(file: file).appending(path: "/activities")
    }

    // MARK: Archive

    static func buildArchive(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/files/archives")
    }

    static func getArchive(drive: AbstractDrive, uuid: String) -> Endpoint {
        return .buildArchive(drive: drive).appending(path: "/\(uuid)")
    }

    // MARK: Category

    static func categories(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/categories")
    }

    static func category(drive: AbstractDrive, category: Category) -> Endpoint {
        return .categories(drive: drive).appending(path: "/\(category.id)")
    }

    static func fileCategory(file: AbstractFile, category: Category) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/categories/\(category.id)")
    }

    static func fileCategory(drive: AbstractDrive, category: Category) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/files/categories/\(category.id)")
    }

    // MARK: Comment

    static func comments(file: AbstractFile) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/comments", queryItems: [
            URLQueryItem(name: "with", value: "user,likes,responses,responses.user,responses.likes"),
            noAvatarDefault()
        ])
    }

    static func comment(file: AbstractFile, comment: Comment) -> Endpoint {
        return .comments(file: file).appending(path: "/\(comment.id)", queryItems: [
            URLQueryItem(name: "with", value: "user,likes,responses,responses.user,responses.likes"),
            noAvatarDefault()
        ])
    }

    static func likeComment(file: AbstractFile, comment: Comment) -> Endpoint {
        return .comment(file: file, comment: comment).appending(path: "/like")
    }

    static func unlikeComment(file: AbstractFile, comment: Comment) -> Endpoint {
        return .comment(file: file, comment: comment).appending(path: "/unlike")
    }

    // MARK: Drive (complete me)

    static func driveInfo(drive: AbstractDrive) -> Endpoint {
        return .driveV3.appending(path: "/\(drive.id)")
    }

    static func driveInfoV2(drive: AbstractDrive) -> Endpoint {
        return .driveV2.appending(path: "/\(drive.id)")
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

    static func download(file: AbstractFile, as asType: String? = nil) -> Endpoint {
        let queryItems: [URLQueryItem]?
        if let asType {
            queryItems = [URLQueryItem(name: "as", value: asType)]
        } else {
            queryItems = nil
        }
        return .fileInfoV2(file).appending(path: "/download", queryItems: queryItems)
    }

    static func convert(file: AbstractFile) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/convert", queryItems: [FileWith.fileMinimal.toQueryItem()])
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

    // MARK: - Import

    static func cancelImport(drive: AbstractDrive, id: Int) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/imports/\(id)/cancel")
    }

    // MARK: Preferences

    static var userPreferences: Endpoint {
        return .driveV3.appending(path: "/preferences")
    }

    static func preferences(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/preference")
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

    // MARK: Search

    static func search(
        drive: AbstractDrive,
        query: String? = nil,
        date: DateInterval? = nil,
        fileTypes: [ConvertedType] = [],
        categories: [Category],
        belongToAllCategories: Bool
    ) -> Endpoint {
        // Query items
        var queryItems = [FileWith.fileMinimal.toQueryItem()]
        if let query, !query.isBlank {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }
        if let date {
            queryItems += [
                URLQueryItem(name: "modified_at", value: "custom"),
                URLQueryItem(name: "modified_after", value: "\(Int(date.start.timeIntervalSince1970))"),
                URLQueryItem(name: "modified_before", value: "\(Int(date.end.timeIntervalSince1970))")
            ]
        }
        for fileType in fileTypes {
            queryItems.append(URLQueryItem(name: "types[]", value: fileType.rawValue))
        }
        if !categories.isEmpty {
            let separator = belongToAllCategories ? "&" : "|"
            queryItems.append(URLQueryItem(name: "category", value: categories.map { "\($0.id)" }.joined(separator: separator)))
        }

        return .driveInfo(drive: drive).appending(path: "/files/search", queryItems: queryItems)
    }

    // MARK: Share link

    static func shareLinkFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/files/links")
    }

    static func shareLink(file: AbstractFile) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/link")
    }

    // MARK: Trash

    static func trash(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/trash", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func emptyTrash(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/trash")
    }

    static func trashCount(drive: AbstractDrive) -> Endpoint {
        return .trash(drive: drive).appending(path: "/count")
    }

    static func trashedInfo(file: AbstractFile) -> Endpoint {
        return .trash(drive: ProxyDrive(id: file.driveId)).appending(
            path: "/\(file.id)",
            queryItems: [FileWith.fileExtra.toQueryItem(), noAvatarDefault()]
        )
    }

    static func trashedFiles(of directory: AbstractFile) -> Endpoint {
        return .trashedInfo(file: directory).appending(path: "/files", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func restore(file: AbstractFile) -> Endpoint {
        return .trashedInfo(file: file).appending(path: "/restore")
    }

    static func trashThumbnail(file: AbstractFile, at date: Date) -> Endpoint {
        return .trashedInfo(file: file).appending(path: "/thumbnail", queryItems: [
            URLQueryItem(name: "t", value: "\(Int(date.timeIntervalSince1970))")
        ])
    }

    static func trashCount(of directory: AbstractFile) -> Endpoint {
        return .trashedInfo(file: directory).appending(path: "/count")
    }

    // MARK: Upload

    // Direct Upload

    static func directUpload(drive: AbstractDrive) -> Endpoint {
        return .driveV3.appending(path: "/\(drive.id)/upload")
    }

    // Chunk Upload
    static func upload(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/upload", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    private static func uploadSession(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/upload/session", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func cancelSession(drive: AbstractDrive, sessionToken: AbstractToken) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/upload/session/\(sessionToken.token)")
    }

    static func startSession(drive: AbstractDrive) -> Endpoint {
        return .uploadSession(drive: drive).appending(path: "/start")
    }

    static func getUploadSession(drive: AbstractDrive, sessionToken: AbstractToken) -> Endpoint {
        return .driveInfo(drive: drive).appending(
            path: "/upload/session/\(sessionToken.token)",
            queryItems: [URLQueryItem(name: "with", value: "chunks")]
        )
    }

    static func closeSession(drive: AbstractDrive, sessionToken: AbstractToken) -> Endpoint {
        return .uploadSession(drive: drive)
            .appending(path: "/\(sessionToken.token)/finish", queryItems: [FileWith.chunkUpload.toQueryItem()])
    }

    static func appendChunk(drive: AbstractDrive, sessionToken: AbstractToken) -> Endpoint {
        return .uploadSession(drive: drive).appending(path: "/\(sessionToken.token)/chunk")
    }

    // MARK: User invitation

    static func userInvitations(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/user/invitation")
    }

    static func userInvitation(drive: AbstractDrive, id: Int) -> Endpoint {
        return .userInvitations(drive: drive).appending(path: "/\(id)")
    }

    static func sendUserInvitation(drive: AbstractDrive, id: Int) -> Endpoint {
        return .userInvitation(drive: drive, id: id).appending(path: "/send")
    }
}
