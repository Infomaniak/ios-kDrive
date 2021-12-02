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
        case .folder, .url:
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
            return .url
        case .video:
            return .movie
        }
    }

    public static func fromUTI(_ uti: UTI) -> ConvertedType {
        var types = ConvertedType.allCases
        types.removeAll { $0 == .unknown }

        return types.first { uti.conforms(to: $0.uti) } ?? .unknown
    }

    public static let downloadableTypes = Set<ConvertedType>(arrayLiteral: .pdf, .presentation, .spreadsheet, .text)
    public static let remotePlayableTypes = Set<ConvertedType>(arrayLiteral: .audio, .video)
    // Currently it's the same as the downloadableTypes but later this could change
    public static let ignoreThumbnailTypes = downloadableTypes
}

public enum VisibilityType: String {
    case root = "is_root"
    case isPrivate = "is_private"
    case isCollaborativeFolder = "is_collaborative_folder"
    case isShared = "is_shared"
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
            return SortTypeValue(apiValue: "files.path", order: "asc", translation: KDriveResourcesStrings.Localizable.sortNameAZ, realmKeyPath: \.nameNaturalSorting)
        case .nameZA:
            return SortTypeValue(apiValue: "files.path", order: "desc", translation: KDriveResourcesStrings.Localizable.sortNameZA, realmKeyPath: \.nameNaturalSorting)
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
        }
    }
}

public class File: Object, Codable {
    @Persisted(primaryKey: true) public var id: Int = 0
    @Persisted public var parentId: Int = 0
    @Persisted public var name: String = ""
    @Persisted public var nameNaturalSorting: String = ""
    @Persisted(originProperty: "children") private var parentLink: LinkingObjects<File>
    @Persisted public var categories: List<FileCategory>
    @Persisted public var children: List<File>
    @Persisted public var canUseTag = false
    @Persisted public var color: String?
    @Persisted public var createdBy: Int = 0
    @Persisted private var createdAt: Int = 0
    @Persisted private var fileCreatedAt: Int = 0
    @Persisted public var deletedBy: Int = 0
    @Persisted public var deletedAt: Int = 0
    @Persisted public var driveId: Int = 0
    @Persisted public var hasThumbnail = false
    @Persisted public var hasVersion = false
    @Persisted public var isFavorite = false
    @Persisted public var lastModifiedAt: Int = 0
    @Persisted public var nbVersion: Int = 0
    @Persisted public var collaborativeFolder: String?
    @Persisted private var rawConvertedType: String?
    @Persisted public var path: String = ""
    @Persisted public var rights: Rights?
    @Persisted public var shareLink: String?
    @Persisted public var size: Int = 0
    @Persisted public var sizeWithVersion: Int = 0
    @Persisted public var status: String?
    @Persisted public var tags: List<Int>
    @Persisted public var type: String = ""
    @Persisted public var users: List<Int>
    @Persisted public var responseAt: Int = 0
    @Persisted public var rawVisibility: String = ""
    @Persisted public var onlyOffice = false
    @Persisted public var onlyOfficeConvertExtension: String?
    @Persisted public var fullyDownloaded = false
    @Persisted public var isAvailableOffline = false
    public var userId: Int?
    public var isFirstInCollection = false
    public var isLastInCollection = false

    public var parent: File? {
        // We want to get the real parent not one of the fake roots
        return parentLink.filter(NSPredicate(format: "id > 0")).first
    }

    public var isRoot: Bool {
        return id <= DriveFileManager.constants.rootID
    }

    public var lastModifiedDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(lastModifiedAt))
    }

    /// Upload to drive date
    public var createdAtDate: Date? {
        if createdAt != 0 {
            return Date(timeIntervalSince1970: TimeInterval(createdAt))
        } else {
            return nil
        }
    }

    /// File creation date
    public var fileCreatedAtDate: Date? {
        if fileCreatedAt != 0 {
            return Date(timeIntervalSince1970: TimeInterval(fileCreatedAt))
        } else {
            return nil
        }
    }

    /// File deletion date
    public var deletedAtDate: Date? {
        if deletedAt != 0 {
            return Date(timeIntervalSince1970: TimeInterval(deletedAt))
        } else {
            return nil
        }
    }

    public var isDirectory: Bool {
        return type == "dir"
    }

    public var isTrashed: Bool {
        return status == "trashed" || status == "trash_inherited"
    }

    public var isDisabled: Bool {
        return rights?.read == false && rights?.show == false
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
        return URL(string: "\(ApiRoutes.driveApiUrl)\(driveId)/file/\(id)/preview?width=2500&height=1500&quality=80&t=\(lastModifiedAt)")!
    }

    public var thumbnailURL: URL {
        let url = isTrashed ? "\(ApiRoutes.driveApiUrl)\(driveId)/file/trash/\(id)/thumbnail?t=\(lastModifiedAt)" : "\(ApiRoutes.driveApiUrl)\(driveId)/file/\(id)/thumbnail?t=\(lastModifiedAt)"
        return URL(string: url)!
    }

    public var isDownloaded: Bool {
        return FileManager.default.fileExists(atPath: localUrl.path)
    }

    public var isOfficeFile: Bool {
        return onlyOffice || onlyOfficeConvertExtension != nil
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
        try? FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: TimeInterval(lastModifiedAt))], ofItemAtPath: localUrl.path)
    }

    public func isLocalVersionOlderThanRemote() -> Bool {
        do {
            if let modifiedDate = try FileManager.default.attributesOfItem(atPath: localUrl.path)[.modificationDate] as? Date {
                if modifiedDate >= Date(timeIntervalSince1970: TimeInterval(lastModifiedAt)) {
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
            return ConvertedType(rawValue: rawConvertedType ?? "") ?? .unknown
        }
    }

    public var icon: UIImage {
        return IconUtils.getIcon(for: self)
    }

    public var visibility: VisibilityType {
        get {
            if let type = VisibilityType(rawValue: rawVisibility),
               type == .root || type == .isTeamSpace || type == .isTeamSpaceFolder || type == .isInTeamSpaceFolder || type == .isSharedSpace {
                return type
            } else if let collaborativeFolder = collaborativeFolder, !collaborativeFolder.isBlank {
                return VisibilityType.isCollaborativeFolder
            } else if users.count > 1 {
                return VisibilityType.isShared
            } else {
                return VisibilityType.isPrivate
            }
        }
        set {
            rawVisibility = newValue.rawValue
        }
    }

    public func getThumbnail(completion: @escaping ((UIImage, Bool) -> Void)) {
        IconUtils.getThumbnail(for: self, completion: completion)
    }

    public func getFileSize(withVersion: Bool = false) -> String {
        var value = size
        if withVersion {
            value = sizeWithVersion
        }
        return Constants.formatFileSize(Int64(value))
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
                let components = content.components(separatedBy: "URL=")
                if components.count > 1 {
                    urlStr = components[1]
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
            print("Error while decoding bookmark: \(error)")
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
        let values = try decoder.container(keyedBy: CodingKeys.self)
        collaborativeFolder = (try values.decodeIfPresent(String.self, forKey: .collaborativeFolder)) ?? ""
        rawConvertedType = try values.decodeIfPresent(String.self, forKey: .rawConvertedType)
        driveId = try values.decode(Int.self, forKey: .driveId)
        createdAt = (try values.decodeIfPresent(Int.self, forKey: .createdAt)) ?? 0
        fileCreatedAt = (try values.decodeIfPresent(Int.self, forKey: .fileCreatedAt)) ?? 0
        deletedAt = (try values.decodeIfPresent(Int.self, forKey: .deletedAt)) ?? 0
        hasThumbnail = (try values.decodeIfPresent(Bool.self, forKey: .hasThumbnail)) ?? false
        id = try values.decode(Int.self, forKey: .id)
        parentId = try values.decodeIfPresent(Int.self, forKey: .parentId) ?? 0
        isFavorite = (try values.decodeIfPresent(Bool.self, forKey: .isFavorite)) ?? false
        lastModifiedAt = (try values.decodeIfPresent(Int.self, forKey: .lastModifiedAt)) ?? 0
        let name = try values.decode(String.self, forKey: .name)
        self.name = name
        nameNaturalSorting = (try values.decodeIfPresent(String.self, forKey: .nameNaturalSorting)) ?? name
        rights = try values.decodeIfPresent(Rights.self, forKey: .rights)
        shareLink = try values.decodeIfPresent(String.self, forKey: .shareLink)
        size = (try values.decodeIfPresent(Int.self, forKey: .size)) ?? 0
        status = try values.decodeIfPresent(String.self, forKey: .status)
        type = try values.decode(String.self, forKey: .type)
        rawVisibility = (try values.decodeIfPresent(String.self, forKey: .rawVisibility)) ?? ""
        onlyOffice = try values.decodeIfPresent(Bool.self, forKey: .onlyOffice) ?? false
        onlyOfficeConvertExtension = try values.decodeIfPresent(String.self, forKey: .onlyOfficeConvertExtension)
        categories = try values.decodeIfPresent(List<FileCategory>.self, forKey: .categories) ?? List<FileCategory>()
        children = try values.decodeIfPresent(List<File>.self, forKey: .children) ?? List<File>()

        // extras
        canUseTag = (try values.decodeIfPresent(Bool.self, forKey: .canUseTag)) ?? false
        hasVersion = (try values.decodeIfPresent(Bool.self, forKey: .hasVersion)) ?? false
        nbVersion = (try values.decodeIfPresent(Int.self, forKey: .nbVersion)) ?? 0
        createdBy = (try values.decodeIfPresent(Int.self, forKey: .createdBy)) ?? 0
        deletedBy = (try values.decodeIfPresent(Int.self, forKey: .deletedBy)) ?? 0
        path = (try values.decodeIfPresent(String.self, forKey: .path)) ?? ""
        sizeWithVersion = (try values.decodeIfPresent(Int.self, forKey: .sizeWithVersion)) ?? 0
        users = try values.decodeIfPresent(List<Int>.self, forKey: .users) ?? List<Int>()
        color = try values.decodeIfPresent(String.self, forKey: .color)
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

    public func encode(to encoder: Encoder) throws {}

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case name
        case nameNaturalSorting = "name_natural_sorting"
        case categories
        case children
        case canUseTag = "can_use_tag"
        case color
        case createdBy = "created_by"
        case createdAt = "created_at"
        case fileCreatedAt = "file_created_at"
        case deletedBy = "deleted_by"
        case deletedAt = "deleted_at"
        case driveId = "drive_id"
        case hasThumbnail = "has_thumbnail"
        case hasVersion = "has_version"
        case isFavorite = "is_favorite"
        case lastModifiedAt = "last_modified_at"
        case nbVersion = "nb_version"
        case rawConvertedType = "converted_type"
        case path
        case collaborativeFolder = "collaborative_folder"
        case rights
        case shareLink = "share_link"
        case size
        case sizeWithVersion = "size_with_version"
        case status
        case tags
        case type
        case users
        case rawVisibility = "visibility"
        case onlyOffice = "onlyoffice"
        case onlyOfficeConvertExtension = "onlyoffice_convert_extension"
    }
}

extension File: Differentiable {
    public var differenceIdentifier: Int {
        return id
    }

    public func isContentEqual(to source: File) -> Bool {
        autoreleasepool {
            lastModifiedAt == source.lastModifiedAt
                && nameNaturalSorting == source.nameNaturalSorting
                && isFavorite == source.isFavorite
                && isAvailableOffline == source.isAvailableOffline
                && isFirstInCollection == source.isFirstInCollection
                && isLastInCollection == source.isLastInCollection
                && visibility == source.visibility
                && shareLink == source.shareLink
                && rights.isContentEqual(to: source.rights)
                && Array(categories).isContentEqual(to: Array(source.categories))
                && color == source.color
        }
    }
}
