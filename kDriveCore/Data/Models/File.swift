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
import QuickLook
import Alamofire
import RealmSwift
import Kingfisher
import DifferenceKit

public enum ConvertedType: String, CaseIterable {
    case archive, audio, code, folder, font, image, pdf, presentation, spreadsheet, text, unknown, video

    public var icon: UIImage {
        switch self {
        case .archive:
            return KDriveCoreAsset.fileZip.image
        case .audio:
            return KDriveCoreAsset.fileAudio.image
        case .code:
            return KDriveCoreAsset.fileCode.image
        case .folder:
            return KDriveCoreAsset.folderFilled.image
        case .font:
            return KDriveCoreAsset.fileDefault.image
        case .image:
            return KDriveCoreAsset.fileImage.image
        case .pdf:
            return KDriveCoreAsset.filePdf.image
        case .presentation:
            return KDriveCoreAsset.filePresentation.image
        case .spreadsheet:
            return KDriveCoreAsset.fileSheets.image
        case .text:
            return KDriveCoreAsset.fileText.image
        case .unknown:
            return KDriveCoreAsset.fileDefault.image
        case .video:
            return KDriveCoreAsset.fileVideo.image
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
        case .video:
            return .movie
        }
    }

    public static func fromUTI(_ uti: UTI) -> ConvertedType {
        var types = ConvertedType.allCases
        types.removeAll(where: { $0 == .unknown })

        return types.first(where: { uti.conforms(to: $0.uti) }) ?? .unknown
    }

    public static let downloadableTypes = Set<ConvertedType>(arrayLiteral: .code, .pdf, .presentation, .spreadsheet, .text)
    public static let remotePlayableTypes = Set<ConvertedType>(arrayLiteral: .audio, .video)
    //Currently it's the same as the downloadableTypes but later this could change
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
        public let realmKeyPath: String
    }

    public var value: SortTypeValue {
        switch self {
        case .nameAZ:
            return SortTypeValue(apiValue: "files.path", order: "asc", translation: KDriveCoreStrings.Localizable.sortNameAZ, realmKeyPath: "nameNaturalSorting")
        case .nameZA:
            return SortTypeValue(apiValue: "files.path", order: "desc", translation: KDriveCoreStrings.Localizable.sortNameZA, realmKeyPath: "nameNaturalSorting")
        case .older:
            return SortTypeValue(apiValue: "last_modified_at", order: "asc", translation: KDriveCoreStrings.Localizable.sortOlder, realmKeyPath: "lastModifiedAt")
        case .newer:
            return SortTypeValue(apiValue: "last_modified_at", order: "desc", translation: KDriveCoreStrings.Localizable.sortRecent, realmKeyPath: "lastModifiedAt")
        case .biggest:
            return SortTypeValue(apiValue: "files.size", order: "desc", translation: KDriveCoreStrings.Localizable.sortBigger, realmKeyPath: "size")
        case .smallest:
            return SortTypeValue(apiValue: "files.size", order: "asc", translation: KDriveCoreStrings.Localizable.sortSmaller, realmKeyPath: "size")
        case .ext:
            return SortTypeValue(apiValue: "files", order: "asc", translation: KDriveCoreStrings.Localizable.sortExtension, realmKeyPath: "name")
        case .olderDelete:
            return SortTypeValue(apiValue: "deleted_at", order: "asc", translation: KDriveCoreStrings.Localizable.sortOlder, realmKeyPath: "deletedAt")
        case .newerDelete:
            return SortTypeValue(apiValue: "deleted_at", order: "desc", translation: KDriveCoreStrings.Localizable.sortRecent, realmKeyPath: "deletedAt")
        }
    }
}

public class File: Object, Codable {

    @objc public dynamic var id: Int = 0
    @objc public dynamic var parentId: Int = 0
    @objc public dynamic var name: String = ""
    @objc public dynamic var nameNaturalSorting: String = ""
    private let parentLink = LinkingObjects(fromType: File.self, property: "children")
    public var children = List<File>()
    @objc public dynamic var canUseTag: Bool = false
    @objc public dynamic var createdBy: Int = 0
    @objc private dynamic var createdAt: Int = 0
    @objc private dynamic var fileCreatedAt: Int = 0
    @objc public dynamic var deletedBy: Int = 0
    @objc private dynamic var deletedAt: Int = 0
    @objc public dynamic var driveId: Int = 0
    @objc public dynamic var hasThumbnail: Bool = false
    @objc public dynamic var hasVersion: Bool = false
    @objc public dynamic var isFavorite: Bool = false
    @objc public dynamic var lastModifiedAt: Int = 0
    @objc public dynamic var nbVersion: Int = 0
    @objc public dynamic var collaborativeFolder: String?
    @objc private dynamic var rawConvertedType: String?
    @objc public dynamic var path: String = ""
    @objc public dynamic var rights: Rights?
    @objc public dynamic var shareLink: String?
    @objc public dynamic var size: Int = 0
    @objc public dynamic var sizeWithVersion: Int = 0
    @objc public dynamic var status: String?
    public var tags = List<Int>()
    @objc public dynamic var type: String = ""
    public var users = List<Int>()
    @objc public dynamic var responseAt: Int = 0
    @objc private dynamic var rawVisibility: String = ""
    @objc public dynamic var onlyOffice: Bool = false
    @objc public dynamic var onlyOfficeConvertExtension: String?
    @objc public dynamic var fullyDownloaded: Bool = false
    @objc public dynamic var isAvailableOffline: Bool = false
    public var isFirstInCollection = false
    public var isLastInCollection = false

    public var parent: File? {
        //We want to get the real parent not one of the fake roots
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
        get {
            return type == "dir"
        }
    }

    public var isTrashed: Bool {
        get {
            return status == "trashed" || status == "trash_inherited"
        }
    }

    public var isDisabled: Bool {
        get {
            return rights?.read.value == false && rights?.show.value == false
        }
    }

    public var localUrl: URL {
        get {
            return localContainerUrl.appendingPathComponent("\(name)", isDirectory: isDirectory)
        }
    }

    public var localContainerUrl: URL {
        get {
            let directory = isAvailableOffline ? DriveFileManager.constants.rootDocumentsURL : DriveFileManager.constants.cacheDirectoryURL
            return directory.appendingPathComponent("\(driveId)", isDirectory: true).appendingPathComponent("\(id)", isDirectory: true)
        }
    }

    public var imagePreviewUrl: URL {
        get {
            return URL(string: "\(ApiRoutes.driveApiUrl)\(driveId)/file/\(id)/preview?width=2500&height=1500&quality=80&t=\(lastModifiedAt)")!
        }
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

    public var `extension`: String {
        return localUrl.pathExtension
    }

    public var officeUrl: URL? {
        return URL(string: ApiRoutes.showOffice(file: self))
    }

    public var typeIdentifier: UTI {
        localUrl.typeIdentifier ?? convertedType.uti
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
            } else if let collaborativeFolder = collaborativeFolder, !collaborativeFolder.isBlank() {
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
        return KingfisherManager.shared.retrieveImage(with: self.imagePreviewUrl, options: [.requestModifier(AccountManager.instance.currentDriveFileManager.apiFetcher.authenticatedKF)]) { result in
            if let image = try? result.get().image {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }

    /// Signal changes on this file to the File Provider Extension
    public func signalChanges() {
        NSFileProviderManager.default.signalEnumerator(for: .workingSet) { _ in }
        let identifier: NSFileProviderItemIdentifier
        if isDirectory {
            identifier = id == DriveFileManager.constants.rootID ? .rootContainer : NSFileProviderItemIdentifier("\(id)")
        } else if let parentId = parent?.id {
            identifier = parentId == DriveFileManager.constants.rootID ? .rootContainer : NSFileProviderItemIdentifier("\(parentId)")
        } else {
            identifier = .rootContainer
        }
        NSFileProviderManager.default.signalEnumerator(for: identifier) { _ in }
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        collaborativeFolder = (try? values.decode(String.self, forKey: .collaborativeFolder)) ?? ""
        rawConvertedType = try? values.decode(String.self, forKey: .rawConvertedType)
        driveId = try values.decode(Int.self, forKey: .driveId)
        createdAt = (try? values.decode(Int.self, forKey: .createdAt)) ?? 0
        fileCreatedAt = (try? values.decode(Int.self, forKey: .fileCreatedAt)) ?? 0
        deletedAt = (try? values.decode(Int.self, forKey: .deletedAt)) ?? 0
        hasThumbnail = (try? values.decode(Bool.self, forKey: .hasThumbnail)) ?? false
        id = try values.decode(Int.self, forKey: .id)
        parentId = try values.decodeIfPresent(Int.self, forKey: .parentId) ?? 0
        isFavorite = (try? values.decode(Bool.self, forKey: .isFavorite)) ?? false
        lastModifiedAt = (try? values.decode(Int.self, forKey: .lastModifiedAt)) ?? 0
        let name = try values.decode(String.self, forKey: .name)
        self.name = name
        nameNaturalSorting = (try? values.decode(String.self, forKey: .nameNaturalSorting)) ?? name
        rights = try? values.decode(Rights.self, forKey: .rights)
        rights?.fileId = id
        shareLink = try? values.decode(String.self, forKey: .shareLink)
        size = (try? values.decode(Int.self, forKey: .size)) ?? 0
        status = try values.decodeIfPresent(String.self, forKey: .status)
        type = try values.decode(String.self, forKey: .type)
        rawVisibility = (try? values.decode(String.self, forKey: .rawVisibility)) ?? ""
        onlyOffice = try values.decodeIfPresent(Bool.self, forKey: .onlyOffice) ?? false
        onlyOfficeConvertExtension = try values.decodeIfPresent(String.self, forKey: .onlyOfficeConvertExtension)
        children = try values.decodeIfPresent(List<File>.self, forKey: .children) ?? List<File>()

        //extras
        canUseTag = (try? values.decode(Bool.self, forKey: .canUseTag)) ?? false
        hasVersion = (try? values.decode(Bool.self, forKey: .hasVersion)) ?? false
        nbVersion = (try? values.decode(Int.self, forKey: .nbVersion)) ?? 0
        createdBy = (try? values.decode(Int.self, forKey: .createdBy)) ?? 0
        deletedBy = (try? values.decode(Int.self, forKey: .deletedBy)) ?? 0
        path = (try? values.decode(String.self, forKey: .path)) ?? ""
        sizeWithVersion = (try? values.decode(Int.self, forKey: .sizeWithVersion)) ?? 0
        users = try values.decodeIfPresent(List<Int>.self, forKey: .users) ?? List<Int>()
    }

    //We have to keep it for Realm
    override public init() { }

    init(id: Int, name: String) {
        self.id = id
        self.name = name
        self.type = "dir"
        children = List<File>()
    }

    public func encode(to encoder: Encoder) throws {
    }

    public override static func primaryKey() -> String? {
        return "id"
    }

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case parentId = "parent_id"
        case name = "name"
        case nameNaturalSorting = "name_natural_sorting"
        case children = "children"
        case canUseTag = "can_use_tag"
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
        case path = "path"
        case collaborativeFolder = "collaborative_folder"
        case rights = "rights"
        case shareLink = "share_link"
        case size = "size"
        case sizeWithVersion = "size_with_version"
        case status = "status"
        case tags = "tags"
        case type = "type"
        case users = "users"
        case rawVisibility = "visibility"
        case onlyOffice = "onlyoffice"
        case onlyOfficeConvertExtension = "onlyoffice_convert_extension"
    }
}

extension File: Differentiable {

    public var differenceIdentifier: Int {
        get {
            return id
        }
    }

    public func isContentEqual(to source: File) -> Bool {
        autoreleasepool {
            return lastModifiedAt == source.lastModifiedAt
                && nameNaturalSorting == source.nameNaturalSorting
                && isFavorite == source.isFavorite
                && isAvailableOffline == source.isAvailableOffline
                && isFirstInCollection == source.isFirstInCollection
                && isLastInCollection == source.isLastInCollection
                && visibility == source.visibility
                && shareLink == source.shareLink
                && rights.isContentEqual(to: source.rights)
        }
    }
}
