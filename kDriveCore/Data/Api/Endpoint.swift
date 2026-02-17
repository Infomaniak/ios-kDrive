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
import OSLog
import RealmSwift

// MARK: - Type definition

public extension ApiEnvironment {
    var driveHost: String {
        switch self {
        case .prod, .preprod:
            return "kdrive.\(host)"
        case .customHost(let host):
            if host.contains("orphan") {
                return host
            }

            return "kdrive.\(host)"
        }
    }

    var apiDriveHost: String {
        switch self {
        case .prod, .preprod:
            return "api.\(driveHost)"
        case .customHost(let host):
            if host.contains("orphan") {
                return host
            }

            return "api.\(driveHost)"
        }
    }

    var preprodOnOrphanDriveHost: String {
        switch self {
        case .prod, .preprod:
            return "api.\(driveHost)"
        case .customHost(let host):
            if host.contains("orphan") {
                return "api.\(Self.preprod.driveHost)"
            }

            return "api.\(driveHost)"
        }
    }

    var mqttHost: String {
        switch self {
        case .prod:
            return "info-mq.infomaniak.com"
        case .preprod:
            return "preprod-info-mq.infomaniak.com"
        case .customHost(let host):
            if !host.contains("orphan") {
                Logger.general.error("Cannot guess mqttHost for arbitrary customHost will fallback to preprod")
            }
            return "preprod-info-mq.infomaniak.com"
        }
    }

    var mqttPass: String {
        switch self {
        case .prod:
            return "8QC5EwBqpZ2Z"
        case .preprod:
            return "4fBt5AdC2P"
        case .customHost(let host):
            if !host.contains("orphan") {
                Logger.general.error("Cannot guess mqttPass for arbitrary customHost will fallback to preprod")
            }
            return "4fBt5AdC2P"
        }
    }
}

public extension Endpoint {
    static let itemsPerPage = 200
    static let filesPerPage = 50

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

    func cursored(_ cursor: String?, limit: Int = Endpoint.itemsPerPage) -> Endpoint {
        let perPage = URLQueryItem(name: "limit", value: "\(limit)")
        let cursorQueryItem = cursor != nil ? [URLQueryItem(name: "cursor", value: cursor), perPage] : [perPage]
        return Endpoint(host: host, path: path, queryItems: (queryItems ?? []) + cursorQueryItem)
    }

    func limited(_ limit: Int = Endpoint.itemsPerPage) -> Endpoint {
        let perPage = URLQueryItem(name: "limit", value: "\(limit)")
        return Endpoint(host: host, path: path, queryItems: (queryItems ?? []) + [perPage])
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

    public init(abstractFile: AbstractFile) {
        driveId = abstractFile.driveId
        id = abstractFile.id
    }

    /// Resolve an abstract file within a `DriveFileManager`.
    func resolve(within driveFileManager: DriveFileManager) throws -> File {
        let liveFile = driveFileManager.database.fetchObject(ofType: File.self, forPrimaryKey: uid)

        guard let liveFile else {
            throw DriveError.errorWithUserInfo(.fileNotFound, info: [.fileId: ErrorUserInfo(intValue: id)])
        }

        return liveFile
    }

    /// Internal query an object from a realm
    private func fetch(using realm: Realm) -> File? {
        guard let file = realm.object(ofType: File.self, forPrimaryKey: uid), !file.isInvalidated else {
            return nil
        }

        return file
    }

    /// Resolve an abstract file within a `realm`. Throws if not found.
    func resolve(using realm: Realm) throws -> File {
        guard let file = fetch(using: realm) else {
            throw DriveError.errorWithUserInfo(.fileNotFound, info: [.fileId: ErrorUserInfo(intValue: id)])
        }
        return file
    }
}

extension File: AbstractFile {}

// MARK: - Endpoints

public extension Endpoint {
    static var driveV3: Endpoint {
        return Endpoint(hostKeypath: \.apiDriveHost, path: "/3/drive")
    }

    static var inAppReceipt: Endpoint {
        return Endpoint(path: "/invoicing/inapp/apple/link_receipt")
    }

    // MARK: V2

    private static var driveV2Path: String {
        return "/2/drive"
    }

    private static var driveV2: Endpoint {
        return Endpoint(hostKeypath: \.apiDriveHost, path: driveV2Path)
    }

    static var initData: Endpoint {
        let queryItems = [
            noAvatarDefault(),
            DriveInitWith.allCases.toQueryItem()
        ]
        return Endpoint(hostKeypath: \.preprodOnOrphanDriveHost, path: driveV2Path)
            .appending(path: "/init", queryItems: queryItems)
    }

    // MARK: Action

    static func undoAction(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/cancel")
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

    // MARK: Search

    static func search(
        drive: AbstractDrive,
        query: String? = nil,
        date: DateInterval? = nil,
        fileTypes: [ConvertedType] = [],
        fileExtensions: [String],
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
        for fileExtension in fileExtensions {
            queryItems.append(URLQueryItem(name: "extensions[]", value: fileExtension))
        }
        if !categories.isEmpty {
            let separator = belongToAllCategories ? "&" : "|"
            queryItems.append(URLQueryItem(name: "category", value: categories.map { "\($0.id)" }.joined(separator: separator)))
        }

        return .driveInfo(drive: drive).appending(path: "/files/search", queryItems: queryItems)
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
        return .driveInfoV2(drive: drive).appending(
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
