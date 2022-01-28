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

import Alamofire
import CocoaLumberjackSwift
import DifferenceKit
import Foundation
import kDriveResources
import Kingfisher
import QuickLook
import RealmSwift

public enum ConvertedType: String, CaseIterable {
    case archive, audio, code, folder, font, image, pdf, presentation, spreadsheet, text, unknown, url, video

    public var icon: UIImage {
        switch self {
        case .archive:
            return KDriveResourcesAsset.fileZip.image
        case .audio:
            return KDriveResourcesAsset.fileAudio.image
        case .code:
            return KDriveResourcesAsset.fileCode.image
        case .folder:
            return KDriveResourcesAsset.folderFilled.image
        case .font:
            return KDriveResourcesAsset.fileDefault.image
        case .image:
            return KDriveResourcesAsset.fileImage.image
        case .pdf:
            return KDriveResourcesAsset.filePdf.image
        case .presentation:
            return KDriveResourcesAsset.filePresentation.image
        case .spreadsheet:
            return KDriveResourcesAsset.fileSheets.image
        case .text:
            return KDriveResourcesAsset.fileText.image
        case .unknown:
            return KDriveResourcesAsset.fileDefault.image
        case .url:
            return KDriveResourcesAsset.url.image
        case .video:
            return KDriveResourcesAsset.fileVideo.image
        }
    }

    public var tintColor: UIColor? {
        switch self {
        case .folder, .url, .font, .unknown:
            return KDriveResourcesAsset.secondaryTextColor.color
        default:
            return nil
        }
    }

    public var title: String {
        switch self {
        case .archive:
            return KDriveResourcesStrings.Localizable.allArchive
        case .audio:
            return KDriveResourcesStrings.Localizable.allAudio
        case .code:
            return KDriveResourcesStrings.Localizable.allCode
        case .folder:
            return KDriveResourcesStrings.Localizable.allFolder
        case .image:
            return KDriveResourcesStrings.Localizable.allPictures
        case .pdf:
            return KDriveResourcesStrings.Localizable.allPdf
        case .presentation:
            return KDriveResourcesStrings.Localizable.allOfficePoints
        case .spreadsheet:
            return KDriveResourcesStrings.Localizable.allOfficeGrids
        case .text:
            return KDriveResourcesStrings.Localizable.allOfficeDocs
        case .unknown, .url, .font:
            return ""
        case .video:
            return KDriveResourcesStrings.Localizable.allVideo
        }
    }

    public var uti: UTI {
        switch self {
        case .archive:
            return .archive
        case .audio:
            return .audio
        case .code:
            return .sourceCode
        case .folder:
            return .folder
        case .font:
            return .font
        case .image:
            return .image
        case .pdf:
            return .pdf
        case .presentation:
            return .presentation
        case .spreadsheet:
            return .spreadsheet
        case .text:
            return .text
        case .unknown:
            return .data
        case .url:
            return .internetShortcut
        case .video:
            return .movie
        }
    }

    public static func fromUTI(_ uti: UTI) -> ConvertedType {
        var types = ConvertedType.allCases
        types.removeAll { $0 == .unknown }

        return types.first { uti.conforms(to: $0.uti) } ?? .unknown
    }

    public static let downloadableTypes = Set<ConvertedType>(arrayLiteral: .pdf, .presentation, .spreadsheet, .text, .url, .code)
    public static let remotePlayableTypes = Set<ConvertedType>(arrayLiteral: .audio, .video)
    // Currently it's the same as the downloadableTypes but later this could change
    public static let ignoreThumbnailTypes = downloadableTypes
}

public enum VisibilityType: String {
    case root = "is_root"
    // case isPrivate = "is_private"
    // case isCollaborativeFolder = "is_collaborative_folder"
    // case isShared = "is_shared"
    case isSharedSpace = "is_shared_space"
    case isTeamSpace = "is_team_space"
    case isTeamSpaceFolder = "is_team_space_folder"
    case isInTeamSpaceFolder = "is_in_team_space_folder"
}

public enum SortType: String {
    case nameAZ
    case nameZA
    case older
    case newer
    case biggest
    case smallest
    case ext
    case olderDelete
    case newerDelete
    case type

    public struct SortTypeValue {
        public let apiValue: String
        public let order: String
        public let translation: String
        public let realmKeyPath: PartialKeyPath<File>

        public var sortDescriptor: RealmSwift.SortDescriptor {
            return SortDescriptor(keyPath: realmKeyPath, ascending: order == "asc")
        }
    }

    public var value: SortTypeValue {
        switch self {
        case .nameAZ:
            return SortTypeValue(apiValue: "files.path", order: "asc", translation: KDriveResourcesStrings.Localizable.sortNameAZ, realmKeyPath: \.sortedName)
        case .nameZA:
            return SortTypeValue(apiValue: "files.path", order: "desc", translation: KDriveResourcesStrings.Localizable.sortNameZA, realmKeyPath: \.sortedName)
        case .older:
            return SortTypeValue(apiValue: "last_modified_at", order: "asc", translation: KDriveResourcesStrings.Localizable.sortOlder, realmKeyPath: \.lastModifiedAt)
        case .newer:
            return SortTypeValue(apiValue: "last_modified_at", order: "desc", translation: KDriveResourcesStrings.Localizable.sortRecent, realmKeyPath: \.lastModifiedAt)
        case .biggest:
            return SortTypeValue(apiValue: "files.size", order: "desc", translation: KDriveResourcesStrings.Localizable.sortBigger, realmKeyPath: \.size)
        case .smallest:
            return SortTypeValue(apiValue: "files.size", order: "asc", translation: KDriveResourcesStrings.Localizable.sortSmaller, realmKeyPath: \.size)
        case .ext:
            return SortTypeValue(apiValue: "files", order: "asc", translation: KDriveResourcesStrings.Localizable.sortExtension, realmKeyPath: \.name)
        case .olderDelete:
            return SortTypeValue(apiValue: "deleted_at", order: "asc", translation: KDriveResourcesStrings.Localizable.sortOlder, realmKeyPath: \.deletedAt)
        case .newerDelete:
            return SortTypeValue(apiValue: "deleted_at", order: "desc", translation: KDriveResourcesStrings.Localizable.sortRecent, realmKeyPath: \.deletedAt)
        case .type:
            return SortTypeValue(apiValue: "type", order: "desc", translation: "", realmKeyPath: \.type)
        }
    }
}

public enum FileStatus: String, Codable, PersistableEnum {
    case erasing
    case locked
    case trashInherited = "trash_inherited"
    case trashed
    case uploading
}

public class FileConversion: EmbeddedObject, Codable {
    /// File can be converted to another extension
    @Persisted public var whenDownload: Bool
    /// Available file convertible extensions
    @Persisted public var downloadExtensions: List<String>
    /// File can be converted for live only-office editing
    @Persisted public var whenOnlyoffice: Bool
    /// If convertible, the alternate extension that only-office understands.
    @Persisted public var onylofficeExtension: String?

    private enum CodingKeys: String, CodingKey {
        case whenDownload = "when_download"
        case downloadExtensions = "download_extensions"
        case whenOnlyoffice = "when_onlyoffice"
        case onylofficeExtension = "onlyoffice_extension"
    }
}

public class FileVersion: EmbeddedObject, Codable {
    /// File has multi-version
    @Persisted public var isMultiple: Bool
    /// Get number of version
    @Persisted public var number: Int
    /// Size of the file with all version (byte unit)
    @Persisted public var totalSize: Int

    private enum CodingKeys: String, CodingKey {
        case isMultiple = "is_multiple"
        case number
        case totalSize = "total_size"
    }
}

public class File: Object, Codable {
    @Persisted(primaryKey: true) public var id: Int = 0
    @Persisted public var parentId: Int
    /// Drive identifier
    @Persisted public var driveId: Int
    @Persisted public var name: String
    @Persisted public var sortedName: String
    @Persisted public var path: String? // Extra property
    /// Type of returned object either dir (Directory) or file (File)
    @Persisted public var type: String // FileType
    /// Current state, null if no action
    @Persisted public var status: String? // FileStatus
    /// Visibility of File, empty string if no specific visibility
    @Persisted public var visibility: String // VisibilityType
    /// User identifier of upload
    @Persisted public var createdBy: Int?
    /// Date of  creation
    @Persisted public var createdAt: Date?
    /// Date of upload
    @Persisted public var addedAt: Date
    /// Date of modification
    @Persisted public var lastModifiedAt: Date
    /// Date of deleted resource, only visible when the File is trashed
    @Persisted public var deletedBy: Int?
    /// User identifier of deleted resource, only visible when the File is trashed
    @Persisted public var deletedAt: Date?
    /// Array of users identifiers that has access to the File
    @Persisted public var users: List<Int> // Extra property
    /// Is File pinned as favorite
    @Persisted public var isFavorite: Bool
    // @Persisted public var sharelink: ShareLink
    @Persisted private var _capabilities: Rights?
    @Persisted public var categories: List<FileCategory>

    public var capabilities: Rights {
        get {
            return _capabilities ?? Rights()
        }
        set {
            _capabilities = newValue
        }
    }

    // Directory only
    /// Color of the directory for the user requesting it
    @Persisted public var color: String?
    // @Persisted public var dropbox: DropBox

    // File only
    /// Size of File (byte unit)
    @Persisted public var size: Int?
    /// File has thumbnail, if so you can request thumbnail route
    @Persisted public var hasThumbnail: Bool?
    /// File can be handled by only-office
    @Persisted public var hasOnlyoffice: Bool?
    /// File type
    @Persisted public var extensionType: String? // ConvertedType
    /// Information when file has multi-version
    @Persisted public var version: FileVersion? // Extra property
    /// File can be converted to another extension
    @Persisted public var conversion: FileConversion?

    // Other
    @Persisted public var children: List<File>
    @Persisted(originProperty: "children") var parentLink: LinkingObjects<File>
    @Persisted public var responseAt: Int
    @Persisted public var fullyDownloaded: Bool
    @Persisted public var isAvailableOffline: Bool

    public var userId: Int?
    public var isFirstInCollection = false
    public var isLastInCollection = false

    private enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case driveId = "drive_id"
        case name
        case sortedName = "sorted_name"
        case path
        case type
        case status
        case visibility
        case createdBy = "created_by"
        case createdAt = "created_at"
        case addedAt = "added_at"
        case lastModifiedAt = "last_modified_at"
        case deletedBy = "deleted_by"
        case deletedAt = "deleted_at"
        case users
        case isFavorite = "is_favorite"
        // case sharelink
        case _capabilities = "capabilities"
        case categories
        case color
        // case dropbox
        case size
        case hasThumbnail = "has_thumbnail"
        case hasOnlyoffice = "has_onlyoffice"
        case extensionType = "extension_type"
        case version
        case conversion
    }

    public var parent: File? {
        // We want to get the real parent not one of the fake roots
        return parentLink.filter(NSPredicate(format: "id > 0")).first
    }

    public var creator: DriveUser? {
        if let createdBy = createdBy {
            return DriveInfosManager.instance.getUser(id: createdBy)
        }
        return nil
    }

    public var isRoot: Bool {
        return id <= DriveFileManager.constants.rootID
    }

    public var isDirectory: Bool {
        return type == "dir"
    }

    public var isTrashed: Bool {
        return status == "trashed" || status == "trash_inherited"
    }

    public var isDisabled: Bool {
        return !capabilities.canRead && !capabilities.canShow
    }

    public var temporaryUrl: URL {
        let temporaryUrl = temporaryContainerUrl.appendingPathComponent(name)
        return isDirectory ? temporaryUrl.appendingPathExtension("zip") : temporaryUrl
    }

    public var temporaryContainerUrl: URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("\(driveId)", isDirectory: true).appendingPathComponent("\(id)", isDirectory: true)
    }

    public var localUrl: URL {
        return localContainerUrl.appendingPathComponent(name, isDirectory: isDirectory)
    }

    public var localContainerUrl: URL {
        let directory = isAvailableOffline ? DriveFileManager.constants.rootDocumentsURL : DriveFileManager.constants.cacheDirectoryURL
        return directory.appendingPathComponent("\(driveId)", isDirectory: true).appendingPathComponent("\(id)", isDirectory: true)
    }

    public var imagePreviewUrl: URL {
        return Endpoint.preview(file: self, at: lastModifiedAt).url
    }

    public var thumbnailURL: URL {
        let endpoint: Endpoint = isTrashed ? .trashThumbnail(file: self, at: lastModifiedAt) : .thumbnail(file: self, at: lastModifiedAt)
        return endpoint.url
    }

    public var isDownloaded: Bool {
        return FileManager.default.fileExists(atPath: localUrl.path)
    }

    public var isMostRecentDownloaded: Bool {
        return isDownloaded && !isLocalVersionOlderThanRemote()
    }

    public var isOfficeFile: Bool {
        return hasOnlyoffice == true || conversion?.whenOnlyoffice == true
    }

    public var isBookmark: Bool {
        return self.extension == "url" || self.extension == "webloc"
    }

    public var `extension`: String {
        return localUrl.pathExtension
    }

    public var officeUrl: URL? {
        return URL(string: ApiRoutes.showOffice(file: self))
    }

    public var typeIdentifier: String {
        localUrl.typeIdentifier ?? convertedType.uti.identifier
    }

    public var uti: UTI {
        localUrl.uti ?? convertedType.uti
    }

    public var tintColor: UIColor? {
        if let color = color {
            return UIColor(hex: color)
        } else {
            return convertedType.tintColor
        }
    }

    public func applyLastModifiedDateToLocalFile() {
        try? FileManager.default.setAttributes([.modificationDate: lastModifiedAt], ofItemAtPath: localUrl.path)
    }

    public func isLocalVersionOlderThanRemote() -> Bool {
        do {
            if let modifiedDate = try FileManager.default.attributesOfItem(atPath: localUrl.path)[.modificationDate] as? Date {
                if modifiedDate >= lastModifiedAt {
                    return false
                }
            }
            return true
        } catch {
            return true
        }
    }

    public var convertedType: ConvertedType {
        if isDirectory {
            return .folder
        } else if isBookmark {
            return .url
        } else {
            return ConvertedType(rawValue: extensionType ?? "") ?? .unknown
        }
    }

    public var icon: UIImage {
        return IconUtils.getIcon(for: self)
    }

    public var visibilityType: VisibilityType? {
        get {
            /* if let type = VisibilityType(rawValue: visibility),
                type == .root || type == .isTeamSpace || type == .isTeamSpaceFolder || type == .isInTeamSpaceFolder || type == .isSharedSpace {
                 return type
             } else if let collaborativeFolder = collaborativeFolder, !collaborativeFolder.isBlank {
                 return VisibilityType.isCollaborativeFolder
             } else if users.count > 1 {
                 return VisibilityType.isShared
             } else {
                 return VisibilityType.isPrivate
             } */
            return VisibilityType(rawValue: visibility)
        }
        set {
            visibility = newValue?.rawValue ?? ""
        }
    }

    public func getThumbnail(completion: @escaping ((UIImage, Bool) -> Void)) {
        IconUtils.getThumbnail(for: self, completion: completion)
    }

    public func getFileSize(withVersion: Bool = false) -> String? {
        let value = withVersion ? version?.totalSize : size
        if let value = value {
            return Constants.formatFileSize(Int64(value))
        }
        return nil
    }

    @discardableResult
    public func getPreview(completion: @escaping ((UIImage?) -> Void)) -> Kingfisher.DownloadTask? {
        if let currentDriveFileManager = AccountManager.instance.currentDriveFileManager {
            return KingfisherManager.shared.retrieveImage(with: imagePreviewUrl, options: [.requestModifier(currentDriveFileManager.apiFetcher.authenticatedKF), .preloadAllAnimationData]) { result in
                if let image = try? result.get().image {
                    completion(image)
                } else {
                    completion(nil)
                }
            }
        } else {
            return nil
        }
    }

    public func getBookmarkURL() -> URL? {
        do {
            var urlStr: String?
            if self.extension == "url" {
                let content = try String(contentsOf: localUrl)
                let lines = content.components(separatedBy: .newlines)
                let prefix = "URL="
                if let urlLine = lines.first(where: { $0.starts(with: prefix) }),
                   let index = urlLine.range(of: prefix)?.upperBound {
                    urlStr = String(urlLine[index...])
                }
            } else if self.extension == "webloc" {
                let decoder = PropertyListDecoder()
                let data = try Data(contentsOf: localUrl)
                let content = try decoder.decode([String: String].self, from: data)
                urlStr = content["URL"]
            }

            if let urlStr = urlStr {
                return URL(string: urlStr)
            } else {
                return nil
            }
        } catch {
            DDLogError("Error while decoding bookmark: \(error)")
            return nil
        }
    }

    /// Signal changes on this file to the File Provider Extension
    public func signalChanges(userId: Int) {
        let identifier: NSFileProviderItemIdentifier
        if isDirectory {
            identifier = id == DriveFileManager.constants.rootID ? .rootContainer : NSFileProviderItemIdentifier("\(id)")
        } else if let parentId = parent?.id {
            identifier = parentId == DriveFileManager.constants.rootID ? .rootContainer : NSFileProviderItemIdentifier("\(parentId)")
        } else {
            identifier = .rootContainer
        }
        DriveInfosManager.instance.getFileProviderManager(driveId: driveId, userId: userId) { manager in
            manager.signalEnumerator(for: .workingSet) { _ in }
            manager.signalEnumerator(for: identifier) { _ in }
        }
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        parentId = try container.decode(Int.self, forKey: .parentId)
        driveId = try container.decode(Int.self, forKey: .driveId)
        name = try container.decode(String.self, forKey: .name)
        sortedName = try container.decode(String.self, forKey: .sortedName)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        type = try container.decode(String.self, forKey: .type)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        visibility = try container.decode(String.self, forKey: .visibility)
        createdBy = try container.decodeIfPresent(Int.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        lastModifiedAt = try container.decode(Date.self, forKey: .lastModifiedAt)
        deletedBy = try container.decodeIfPresent(Int.self, forKey: .deletedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedBy)
        users = try container.decodeIfPresent(List<Int>.self, forKey: .users) ?? List<Int>()
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        // sharelink = try container.decodeIfPresent(ShareLink.self, forKey: .sharelink)
        _capabilities = try container.decode(Rights.self, forKey: ._capabilities)
        categories = try container.decodeIfPresent(List<FileCategory>.self, forKey: .categories) ?? List<FileCategory>()
        color = try container.decodeIfPresent(String.self, forKey: .color)
        // dropbox = try container.decodeIfPresent(DropBox.self, forKey: .dropbox)
        size = try container.decodeIfPresent(Int.self, forKey: .size)
        hasThumbnail = try container.decodeIfPresent(Bool.self, forKey: .hasThumbnail)
        hasOnlyoffice = try container.decodeIfPresent(Bool.self, forKey: .hasOnlyoffice)
        extensionType = try container.decodeIfPresent(String.self, forKey: .extensionType)
        version = try container.decodeIfPresent(FileVersion.self, forKey: .version)
        conversion = try container.decodeIfPresent(FileConversion.self, forKey: .conversion)
    }

    // We have to keep it for Realm
    override public init() {}

    convenience init(id: Int, name: String) {
        self.init()
        self.id = id
        self.name = name
        type = "dir"
        children = List<File>()
    }
}

extension File: Differentiable {
    public var differenceIdentifier: Int {
        return id
    }

    public func isContentEqual(to source: File) -> Bool {
        // TODO: Update this
        autoreleasepool {
            lastModifiedAt == source.lastModifiedAt
                && sortedName == source.sortedName
                && isFavorite == source.isFavorite
                && isAvailableOffline == source.isAvailableOffline
                && isFirstInCollection == source.isFirstInCollection
                && isLastInCollection == source.isLastInCollection
                && visibility == source.visibility
                // && shareLisnk == source.shareLink
                && capabilities.isContentEqual(to: source.capabilities)
                && Array(categories).isContentEqual(to: Array(source.categories))
                && color == source.color
        }
    }
}
