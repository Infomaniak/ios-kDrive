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
import InfomaniakCore
import InfomaniakDI
import kDriveResources
import Photos
import QuickLook
import RealmSwift

public enum ConvertedType: String, CaseIterable {
    case archive, audio, code, folder = "dir", font, form, image, pdf, presentation, spreadsheet, text, unknown, url, video

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
        case .form:
            return KDriveResourcesAsset.fileForm.image
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
        case .form:
            return KDriveResourcesStrings.Localizable.allOfficeForm
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
        case .form:
            return .data
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

    /// Bridge to PHAssetMediaType
    public var assetMediaType: PHAssetMediaType {
        switch self {
        case .video:
            return .video
        case .image:
            return .image
        case .audio:
            return .audio
        default:
            return .unknown
        }
    }

    public static func fromUTI(_ uti: UTI) -> ConvertedType {
        var types = ConvertedType.allCases
        types.removeAll { $0 == .unknown || $0 == .form }

        return types.first { uti.conforms(to: $0.uti) } ?? .unknown
    }

    public static let downloadableTypes = Set<ConvertedType>(arrayLiteral: .code, .form, .pdf, .presentation, .spreadsheet, .text,
                                                             .url)
    public static let remotePlayableTypes = Set<ConvertedType>(arrayLiteral: .audio, .video)
    // Currently it's the same as the downloadableTypes but later this could change
    public static let ignoreThumbnailTypes = downloadableTypes
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
            return SortTypeValue(
                apiValue: "path",
                order: "asc",
                translation: KDriveResourcesStrings.Localizable.sortNameAZ,
                realmKeyPath: \.sortedName
            )
        case .nameZA:
            return SortTypeValue(
                apiValue: "path",
                order: "desc",
                translation: KDriveResourcesStrings.Localizable.sortNameZA,
                realmKeyPath: \.sortedName
            )
        case .older:
            return SortTypeValue(
                apiValue: "last_modified_at",
                order: "asc",
                translation: KDriveResourcesStrings.Localizable.sortOlder,
                realmKeyPath: \.lastModifiedAt
            )
        case .newer:
            return SortTypeValue(
                apiValue: "last_modified_at",
                order: "desc",
                translation: KDriveResourcesStrings.Localizable.sortRecent,
                realmKeyPath: \.lastModifiedAt
            )
        case .biggest:
            return SortTypeValue(
                apiValue: "size",
                order: "desc",
                translation: KDriveResourcesStrings.Localizable.sortBigger,
                realmKeyPath: \.size
            )
        case .smallest:
            return SortTypeValue(
                apiValue: "size",
                order: "asc",
                translation: KDriveResourcesStrings.Localizable.sortSmaller,
                realmKeyPath: \.size
            )
        case .ext:
            return SortTypeValue(
                apiValue: "files",
                order: "asc",
                translation: KDriveResourcesStrings.Localizable.sortExtension,
                realmKeyPath: \.name
            )
        case .olderDelete:
            return SortTypeValue(
                apiValue: "deleted_at",
                order: "asc",
                translation: KDriveResourcesStrings.Localizable.sortOlder,
                realmKeyPath: \.deletedAt
            )
        case .newerDelete:
            return SortTypeValue(
                apiValue: "deleted_at",
                order: "desc",
                translation: KDriveResourcesStrings.Localizable.sortRecent,
                realmKeyPath: \.deletedAt
            )
        case .type:
            return SortTypeValue(apiValue: "type", order: "asc", translation: "", realmKeyPath: \.type)
        }
    }
}

public enum FileVisibility: String {
    case root = "is_root"
    case isSharedSpace = "is_shared_space"
    case isTeamSpace = "is_team_space"
    case isTeamSpaceFolder = "is_team_space_folder"
    case isInTeamSpaceFolder = "is_in_team_space_folder"
}

public enum FileStatus: String {
    case erasing
    case locked
    case trashInherited = "trash_inherited"
    case trashed
    case uploading
}

public enum FileImportStatus: String, PersistableEnum, Codable {
    case waiting, inProgress = "in_progress", done, failed, canceling, canceled
}

public final class FileExternalImport: EmbeddedObject, Codable {
    @Persisted public var id: Int
    @Persisted public var directoryId: Int
    @Persisted public var accountName: String
    @Persisted public var application: String
    @Persisted public var createdAt: Date
    @Persisted public var updatedAt: Date
    @Persisted public var path: String
    @Persisted public var status: FileImportStatus
    @Persisted public var countFailedFiles: Int
    @Persisted public var countSuccessFiles: Int
    @Persisted public var hasSharedFiles: String

    private enum CodingKeys: String, CodingKey {
        case id
        case directoryId = "directory_id"
        case accountName = "account_name"
        case application
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case path
        case status
        case countFailedFiles = "count_failed_files"
        case countSuccessFiles = "count_success_files"
        case hasSharedFiles = "has_shared_files"
    }
}

public final class FileConversion: EmbeddedObject, Codable {
    /// File can be converted to another extension
    @Persisted public var whenDownload: Bool
    /// Available file convertible extensions
    @Persisted public var downloadExtensions: List<String>
    /// File can be converted for live only-office editing
    @Persisted public var whenOnlyoffice: Bool
    /// If convertible, the alternate extension that only-office understands.
    @Persisted public var onylofficeExtension: String?

    private enum CodingKeys: String, CodingKey {
        case whenDownload = "when_downloading"
        case downloadExtensions = "download_extensions"
        case whenOnlyoffice = "when_onlyoffice_opening"
        case onylofficeExtension = "onlyoffice_extension"
    }
}

public final class FileVersion: EmbeddedObject, Codable {
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

public final class File: Object, Codable {
    private let fileManager = FileManager.default

    @LazyInjectService var accountManager: AccountManageable

    @Persisted(primaryKey: true) public var id = UUID().uuidString.hashValue
    @Persisted public var parentId: Int
    /// Drive identifier
    @Persisted public var driveId: Int
    @Persisted public var name: String
    @Persisted public var sortedName: String
    @Persisted public var path: String? // Extra property
    /// Use `type` instead
    @Persisted private var rawType: String
    /// Use `status` instead
    @Persisted private var rawStatus: String?
    /// Use `visibility`
    @Persisted private var rawVisibility: String
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
    @Persisted public var sharelink: ShareLink?
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
    @Persisted public var dropbox: DropBox?
    @Persisted public var externalImport: FileExternalImport?

    // File only
    /// Size of File (byte unit)
    @Persisted public var size: Int?
    /// File has thumbnail, if so you can request thumbnail route
    @Persisted public var hasThumbnail: Bool
    /// File can be handled by only-office
    @Persisted public var hasOnlyoffice: Bool
    /// File type
    @Persisted public var extensionType: String?
    /// Information when file has multi-version
    @Persisted public var version: FileVersion? // Extra property
    /// File can be converted to another extension
    @Persisted public var conversion: FileConversion?

    // Other
    @Persisted public var children: MutableSet<File>
    @Persisted(originProperty: "children") var parentLink: LinkingObjects<File>
    @Persisted public var responseAt: Int
    @Persisted public var versionCode: Int
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
        case rawType = "type"
        case rawStatus = "status"
        case rawVisibility = "visibility"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case addedAt = "added_at"
        case lastModifiedAt = "last_modified_at"
        case deletedBy = "deleted_by"
        case deletedAt = "deleted_at"
        case users
        case isFavorite = "is_favorite"
        case sharelink
        case _capabilities = "capabilities"
        case categories
        case color
        case dropbox
        case size
        case hasThumbnail = "has_thumbnail"
        case hasOnlyoffice = "has_onlyoffice"
        case extensionType = "extension_type"
        case externalImport = "external_import"
        case version
        case conversion = "conversion_capabilities"
    }

    public var parent: File? {
        // We want to get the real parent not one of the fake roots
        return parentLink.filter(NSPredicate(format: "id > 0")).first
    }

    public var creator: DriveUser? {
        if let createdBy {
            let driveInfosManager = DriveInfosManager.instance
            let realm = driveInfosManager.getRealm()
            return driveInfosManager.getFrozenUser(id: createdBy, using: realm)
        }
        return nil
    }

    public var isRoot: Bool {
        return id <= DriveFileManager.constants.rootID
    }

    public var isDirectory: Bool {
        return type == .dir
    }

    public var isTrashed: Bool {
        return status == .trashed || status == .trashInherited
    }

    public var isDisabled: Bool {
        return !capabilities.canRead && !capabilities.canShow
    }

    public var temporaryUrl: URL {
        let temporaryUrl = temporaryContainerUrl.appendingPathComponent(name)
        return isDirectory ? temporaryUrl.appendingPathExtension("zip") : temporaryUrl
    }

    public var temporaryContainerUrl: URL {
        return fileManager.temporaryDirectory.appendingPathComponent("\(driveId)", isDirectory: true)
            .appendingPathComponent("\(id)", isDirectory: true)
    }

    public var localUrl: URL {
        return localContainerUrl.appendingPathComponent(name, isDirectory: isDirectory)
    }

    public var localContainerUrl: URL {
        let directory = isAvailableOffline ? DriveFileManager.constants.rootDocumentsURL : DriveFileManager.constants
            .cacheDirectoryURL
        return directory.appendingPathComponent("\(driveId)", isDirectory: true)
            .appendingPathComponent("\(id)", isDirectory: true)
    }

    public var imagePreviewUrl: URL {
        return Endpoint.preview(file: self, at: lastModifiedAt).url
    }

    public var thumbnailURL: URL {
        let endpoint: Endpoint = isTrashed ? .trashThumbnail(file: self, at: lastModifiedAt) :
            .thumbnail(file: self, at: lastModifiedAt)
        return endpoint.url
    }

    public var isDownloaded: Bool {
        // Check that size on disk matches, if available
        do {
            let attributes = try fileManager.attributesOfItem(atPath: localUrl.path)
            if let remoteSize = size,
               let metadataSize = attributes[FileAttributeKey.size] as? NSNumber,
               metadataSize.intValue != remoteSize {
                return false
            }
        } catch {
            DDLogError("[File] unable to read metadata on disk: \(error)")
        }

        return fileManager.fileExists(atPath: localUrl.path)
    }

    public var isMostRecentDownloaded: Bool {
        return isDownloaded && !isLocalVersionOlderThanRemote
    }

    public var isOfficeFile: Bool {
        return hasOnlyoffice || conversion?.whenOnlyoffice == true
    }

    public var isBookmark: Bool {
        return self.extension == "url" || self.extension == "webloc"
    }

    public var isDropbox: Bool {
        return dropbox != nil
    }

    public var hasSharelink: Bool {
        return sharelink != nil
    }

    public var `extension`: String {
        return localUrl.pathExtension
    }

    public var officeUrl: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = ApiEnvironment.current.driveHost
        components.path = "/app/office/\(driveId)/\(id)"
        return components.url
    }

    public var typeIdentifier: String {
        localUrl.typeIdentifier ?? convertedType.uti.identifier
    }

    public var uti: UTI {
        localUrl.uti ?? convertedType.uti
    }

    public var tintColor: UIColor? {
        if let color {
            return UIColor(hex: color)
        } else if visibility == .isTeamSpaceFolder {
            return KDriveResourcesAsset.blueFolderColor.color
        } else {
            return convertedType.tintColor
        }
    }

    public var isLocalVersionOlderThanRemote: Bool {
        if let modificationDate = try? fileManager.attributesOfItem(atPath: localUrl.path)[.modificationDate] as? Date,
           modificationDate >= lastModifiedAt {
            return false
        }
        return true
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
        if isDirectory {
            if isDisabled {
                return KDriveResourcesAsset.folderDisable.image
            } else if isDropbox {
                return KDriveResourcesAsset.folderDropBox.image.withRenderingMode(.alwaysTemplate)
            } else {
                switch visibility {
                case .isTeamSpace:
                    return KDriveResourcesAsset.folderCommonDocuments.image
                case .isTeamSpaceFolder:
                    return KDriveResourcesAsset.folderCommonDocuments.image.withRenderingMode(.alwaysTemplate)
                case .isSharedSpace:
                    return KDriveResourcesAsset.folderShared.image
                default:
                    return KDriveResourcesAsset.folderFilled.image.withRenderingMode(.alwaysTemplate)
                }
            }
        } else {
            return convertedType.icon
        }
    }

    /// Type of returned object either dir (Directory) or file (File)
    public var type: FileType? {
        return FileType(rawValue: rawType)
    }

    /// Current state, null if no action
    public var status: FileStatus? {
        if let status = rawStatus {
            return FileStatus(rawValue: status)
        }
        return nil
    }

    /// Visibility of File, null if no specific visibility
    public var visibility: FileVisibility? {
        return FileVisibility(rawValue: rawVisibility)
    }

    /// Indicate if we can use the cached children or if we must call API.
    public var canLoadChildrenFromCache: Bool {
        return fullyDownloaded && versionCode == DriveFileManager.constants.currentVersionCode
    }

    public var canBeColored: Bool {
        return !isDisabled && visibility != .isSharedSpace && visibility != .isTeamSpace
    }

    /// Is this File currently importing
    public var isImporting: Bool {
        return externalImport?.status == .inProgress
    }

    public func applyLastModifiedDateToLocalFile() {
        try? fileManager.setAttributes([.modificationDate: lastModifiedAt], ofItemAtPath: localUrl.path)
    }

    public func excludeFileFromSystemBackup() {
        var metadata = URLResourceValues()
        metadata.isExcludedFromBackup = true
        var pathCopy = localUrl
        try? pathCopy.setResourceValues(metadata)
    }

    public func getFileSize(withVersion: Bool = false) -> String? {
        let value = withVersion ? version?.totalSize : size
        if let value {
            return Constants.formatFileSize(Int64(value))
        }
        return nil
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

            if let urlStr {
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
            identifier = parentId == DriveFileManager.constants
                .rootID ? .rootContainer : NSFileProviderItemIdentifier("\(parentId)")
        } else {
            identifier = .rootContainer
        }
        DriveInfosManager.instance.getFileProviderManager(driveId: driveId, userId: userId) { manager in
            manager.signalEnumerator(for: .workingSet) { _ in
                // META: keep SonarCloud happy
            }
            manager.signalEnumerator(for: identifier) { _ in
                // META: keep SonarCloud happy
            }
        }
    }

    public func proxify() -> ProxyFile {
        return ProxyFile(driveId: driveId, id: id)
    }

    public convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        parentId = try container.decode(Int.self, forKey: .parentId)
        driveId = try container.decode(Int.self, forKey: .driveId)
        let decodedName = try container.decode(String.self, forKey: .name)
        name = decodedName
        sortedName = try container.decodeIfPresent(String.self, forKey: .sortedName) ?? decodedName
        path = try container.decodeIfPresent(String.self, forKey: .path)
        rawType = try container.decode(String.self, forKey: .rawType)
        rawStatus = try container.decodeIfPresent(String.self, forKey: .rawStatus)
        rawVisibility = try container.decode(String.self, forKey: .rawVisibility)
        createdBy = try container.decodeIfPresent(Int.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        lastModifiedAt = try container.decode(Date.self, forKey: .lastModifiedAt)
        deletedBy = try container.decodeIfPresent(Int.self, forKey: .deletedBy)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        users = try container.decodeIfPresent(List<Int>.self, forKey: .users) ?? List<Int>()
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        sharelink = try container.decodeIfPresent(ShareLink.self, forKey: .sharelink)
        _capabilities = try container.decodeIfPresent(Rights.self, forKey: ._capabilities)
        categories = try container.decodeIfPresent(List<FileCategory>.self, forKey: .categories) ?? List<FileCategory>()
        color = try container.decodeIfPresent(String.self, forKey: .color)
        dropbox = try container.decodeIfPresent(DropBox.self, forKey: .dropbox)
        externalImport = try container.decodeIfPresent(FileExternalImport.self, forKey: .externalImport)
        size = try container.decodeIfPresent(Int.self, forKey: .size)
        hasThumbnail = try container.decodeIfPresent(Bool.self, forKey: .hasThumbnail) ?? false
        hasOnlyoffice = try container.decodeIfPresent(Bool.self, forKey: .hasOnlyoffice) ?? false
        extensionType = try container.decodeIfPresent(String.self, forKey: .extensionType)
        version = try container.decodeIfPresent(FileVersion.self, forKey: .version)
        conversion = try container.decodeIfPresent(FileConversion.self, forKey: .conversion)
    }

    override public init() {
        // Required by Realm
        super.init()
        // primary key is set as default value
    }

    convenience init(id: Int, name: String) {
        self.init()
        self.id = id
        self.name = name
        rawType = "dir"
        children = MutableSet<File>()
    }
}

extension File: Differentiable {
    public var differenceIdentifier: Int {
        return id
    }

    public func isContentEqual(to source: File) -> Bool {
        autoreleasepool {
            lastModifiedAt == source.lastModifiedAt
                && sortedName == source.sortedName
                && isFavorite == source.isFavorite
                && isAvailableOffline == source.isAvailableOffline
                && isFirstInCollection == source.isFirstInCollection
                && isLastInCollection == source.isLastInCollection
                && visibility == source.visibility
                && hasSharelink == source.hasSharelink
                && isDropbox == source.isDropbox
                && capabilities.isContentEqual(to: source.capabilities)
                && Array(categories).isContentEqual(to: Array(source.categories))
                && color == source.color
        }
    }
}
