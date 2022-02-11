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

public struct Endpoint {
    public static let itemsPerPage = 200

    let path: String
    let queryItems: [URLQueryItem]?
    let apiEnvironment: ApiEnvironment

    public var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = apiEnvironment.host
        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            fatalError("Invalid endpoint URL: \(self)")
        }
        return url
    }

    init(path: String, queryItems: [URLQueryItem]? = nil, apiEnvironment: ApiEnvironment = .prod) {
        self.path = path
        self.queryItems = queryItems
        self.apiEnvironment = apiEnvironment
    }

    func appending(path: String, queryItems: [URLQueryItem]? = nil) -> Endpoint {
        return Endpoint(path: self.path + path, queryItems: queryItems, apiEnvironment: apiEnvironment)
    }

    func paginated(page: Int = 1) -> Endpoint {
        let paginationQueryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(Endpoint.itemsPerPage)")
        ]

        return Endpoint(path: path, queryItems: (queryItems ?? []) + paginationQueryItems, apiEnvironment: apiEnvironment)
    }

    func sorted(by sortTypes: [SortType] = [.type, .nameAZ]) -> Endpoint {
        var sortQueryItems = [
            URLQueryItem(name: "order_by", value: sortTypes.map(\.value.apiValue).joined(separator: ","))
        ]
        sortQueryItems.append(contentsOf: sortTypes.map { URLQueryItem(name: "order_for[\($0.value.apiValue)]", value: $0.value.order) })

        return Endpoint(path: path, queryItems: (queryItems ?? []) + sortQueryItems, apiEnvironment: apiEnvironment)
    }
}

// MARK: - Proxies

public protocol AbstractDrive {
    var id: Int { get set }
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

public class ProxyFile: AbstractFile {
    public var driveId: Int
    public var id: Int

    public init(driveId: Int, id: Int) {
        self.driveId = driveId
        self.id = id
    }
}

extension File: AbstractFile {}

// MARK: - Endpoints

public extension Endpoint {
    private static let fileMinimalWithQueryItems = URLQueryItem(name: "with", value: "capabilities,categories,conversion,dropbox,is_favorite,sharelink,sorted_name")
    private static let fileExtraWithQueryItems = URLQueryItem(name: "with", value: fileMinimalWithQueryItems.value?.appending(",path,users,version"))

    private static var base: Endpoint {
        return Endpoint(path: "/2/drive", apiEnvironment: .preprod)
    }

    static var inAppReceipt: Endpoint {
        return Endpoint(path: "/invoicing/inapp/apple/link_receipt", apiEnvironment: .prod)
    }

    // MARK: Action

    static func undoAction(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/cancel")
    }

    // MARK: Activities

    static func recentActivity(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/activities", queryItems: [
            URLQueryItem(name: "with", value: "file,file.capabilities,file.categories,file.conversion,file.dropbox,file.is_favorite,file.sharelink,file.sorted_name,user"),
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

    // MARK: Category

    static func categories(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/categories")
    }

    static func category(drive: AbstractDrive, category: Category) -> Endpoint {
        return .categories(drive: drive).appending(path: "/\(category.id)")
    }

    static func fileCategory(file: AbstractFile, category: Category) -> Endpoint {
        return .fileInfo(file).appending(path: "/categories/\(category.id)")
    }

    // MARK: Comment

    static func comments(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/comments", queryItems: [
            URLQueryItem(name: "with", value: "user,likes,responses,responses.user,responses.likes")
        ])
    }

    static func comment(file: AbstractFile, comment: Comment) -> Endpoint {
        return .comments(file: file).appending(path: "/\(comment.id)", queryItems: [
            URLQueryItem(name: "with", value: "user,likes,responses,responses.user,responses.likes")
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
        return .base.appending(path: "/\(drive.id)")
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
        return .fileInfo(file).appending(path: "/dropbox", queryItems: [
            URLQueryItem(name: "with", value: "user")
        ])
    }

    static func dropboxInvite(file: AbstractFile) -> Endpoint {
        return .dropbox(file: file).appending(path: "/invite")
    }

    // MARK: Favorite

    static func favorites(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/favorites", queryItems: [fileMinimalWithQueryItems])
    }

    static func favorite(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/favorite")
    }

    // MARK: File access

    static func invitation(drive: AbstractDrive, id: Int) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/invitations/\(id)")
    }

    static func access(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/access", queryItems: [
            URLQueryItem(name: "with", value: "user")
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

    static func fileInfo(_ file: AbstractFile) -> Endpoint {
        return .driveInfo(drive: ProxyDrive(id: file.driveId)).appending(path: "/files/\(file.id)", queryItems: [fileExtraWithQueryItems])
    }

    static func files(of directory: AbstractFile) -> Endpoint {
        return .fileInfo(directory).appending(path: "/files", queryItems: [fileMinimalWithQueryItems])
    }

    static func createDirectory(in file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/directory", queryItems: [fileMinimalWithQueryItems])
    }

    static func createFile(in file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/file", queryItems: [fileMinimalWithQueryItems])
    }

    static func thumbnail(file: AbstractFile, at date: Date) -> Endpoint {
        return .fileInfo(file).appending(path: "/thumbnail", queryItems: [
            URLQueryItem(name: "t", value: "\(date.timeIntervalSince1970)")
        ])
    }

    static func preview(file: AbstractFile, at date: Date) -> Endpoint {
        return .fileInfo(file).appending(path: "/preview", queryItems: [
            URLQueryItem(name: "width", value: "2500"),
            URLQueryItem(name: "height", value: "1500"),
            URLQueryItem(name: "quality", value: "80"),
            URLQueryItem(name: "t", value: "\(date.timeIntervalSince1970)")
        ])
    }

    static func download(file: AbstractFile, as asType: String? = nil) -> Endpoint {
        let queryItems: [URLQueryItem]?
        if let asType = asType {
            queryItems = [URLQueryItem(name: "as", value: asType)]
        } else {
            queryItems = nil
        }
        return .fileInfo(file).appending(path: "/download", queryItems: queryItems)
    }

    static func convert(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/convert", queryItems: [fileMinimalWithQueryItems])
    }

    static func move(file: AbstractFile, destinationId: Int) -> Endpoint {
        return .fileInfo(file).appending(path: "/move/\(destinationId)")
    }

    static func duplicate(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/copy", queryItems: [fileMinimalWithQueryItems])
    }

    static func copy(file: AbstractFile, destinationId: Int) -> Endpoint {
        return .duplicate(file: file).appending(path: "/\(destinationId)", queryItems: [fileMinimalWithQueryItems])
    }

    static func rename(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/rename", queryItems: [fileMinimalWithQueryItems])
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
        return .base.appending(path: "/preferences")
    }

    static func preferences(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/preference")
    }

    // MARK: Root directory

    static func lockedFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/lock")
    }

    static func rootFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files", queryItems: [fileMinimalWithQueryItems])
    }

    static func bulkFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/bulk")
    }

    static func lastModifiedFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/last_modified", queryItems: [fileMinimalWithQueryItems])
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
        return .driveInfo(drive: drive).appending(path: "/files/team_directory", queryItems: [fileMinimalWithQueryItems])
    }

    static func existFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/exists")
    }

    static func sharedFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/shared")
    }

    static func mySharedFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/my_shared", queryItems: [fileMinimalWithQueryItems])
    }

    static func countInRoot(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/count")
    }

    // MARK: Search

    static func search(drive: AbstractDrive, query: String? = nil, date: DateInterval? = nil, fileType: ConvertedType? = nil, categories: [Category], belongToAllCategories: Bool) -> Endpoint {
        // Query items
        var queryItems = [fileMinimalWithQueryItems]
        if let query = query, !query.isBlank {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }
        if let date = date {
            queryItems += [
                URLQueryItem(name: "modified_at", value: "custom"),
                URLQueryItem(name: "from", value: "\(Int(date.start.timeIntervalSince1970))"),
                URLQueryItem(name: "until", value: "\(Int(date.end.timeIntervalSince1970))")
            ]
        }
        if let fileType = fileType {
            queryItems.append(URLQueryItem(name: "type", value: fileType.rawValue))
        }
        if !categories.isEmpty {
            let separator = belongToAllCategories ? "&" : "|"
            queryItems.append(URLQueryItem(name: "category", value: categories.map { "\($0.id)" }.joined(separator: separator)))
        }

        return .driveInfo(drive: drive).appending(path: "/files/search", queryItems: queryItems)
    }

    // MARK: Share link

    static func shareLinkFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/files/links")
    }

    static func shareLink(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/link")
    }

    // MARK: Trash

    static func trash(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: "/trash", queryItems: [fileMinimalWithQueryItems])
    }

    static func trashCount(drive: AbstractDrive) -> Endpoint {
        return .trash(drive: drive).appending(path: "/count")
    }

    static func trashedInfo(file: AbstractFile) -> Endpoint {
        return .trash(drive: ProxyDrive(id: file.driveId)).appending(path: "/\(file.id)", queryItems: [fileExtraWithQueryItems])
    }

    static func trashedFiles(of directory: AbstractFile) -> Endpoint {
        return .trashedInfo(file: directory).appending(path: "/files", queryItems: [fileMinimalWithQueryItems])
    }

    static func restore(file: AbstractFile) -> Endpoint {
        return .trashedInfo(file: file).appending(path: "/restore")
    }

    static func trashThumbnail(file: AbstractFile, at date: Date) -> Endpoint {
        return .trashedInfo(file: file).appending(path: "/thumbnail", queryItems: [
            URLQueryItem(name: "t", value: "\(date.timeIntervalSince1970)")
        ])
    }

    static func trashCount(of directory: AbstractFile) -> Endpoint {
        return .trashedInfo(file: directory).appending(path: "/count")
    }

    // MARK: Upload

    static func upload(file: AbstractFile) -> Endpoint {
        return .fileInfo(file).appending(path: "/upload")
    }

    static func directUpload(file: UploadFile) -> Endpoint {
        let parentDirectory = ProxyFile(driveId: file.driveId, id: file.parentDirectoryId)
        return .upload(file: parentDirectory).appending(path: "/direct", queryItems: file.queryItems)
    }

    static func uploadStatus(file: AbstractFile, token: String) -> Endpoint {
        return .upload(file: file).appending(path: "/\(token)")
    }

    static func chunkUpload(file: AbstractFile, token: String) -> Endpoint {
        return .uploadStatus(file: file, token: token).appending(path: "/chunk")
    }

    static func commitUpload(file: AbstractFile, token: String) -> Endpoint {
        return .uploadStatus(file: file, token: token).appending(path: "/file")
    }

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
