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

import DifferenceKit
import Foundation
import Photos
import QuickLookThumbnailing
import RealmSwift
import UIKit

enum UploadFileType: String {
    case file, phAsset, unknown
}

public enum ConflictOption: String, PersistableEnum {
    case error, replace, rename, ignore
}

/// An abstract file to upload
public protocol UploadFilable {
    var name: String { get }
    var parentDirectoryId: Int { get }
    var userId: Int { get }
    var driveId: Int { get }
    var uploadDate: Date? { get }
    var creationDate: Date? { get }
    var modificationDate: Date? { get }
    var taskCreationDate: Date? { get }
    var maxRetryCount: Int { get }
}

public class UploadFile: Object, UploadFilable {
    public static let defaultMaxRetryCount = 3
    
    public static let observedProperties = ["name",
                                            "url",
                                            "parentDirectoryId",
                                            "userId",
                                            "driveId",
                                            "uploadDate",
                                            "modificationDate",
                                            "_error"]
    
    @Persisted(primaryKey: true) public var id: String = ""
    @Persisted public var name: String = ""
    @Persisted var relativePath: String = ""
    @Persisted private var url: String?
    @Persisted private var rawType: String = "file"
    @Persisted public var parentDirectoryId: Int = 1
    @Persisted public var userId: Int = 0
    @Persisted public var driveId: Int = 0
    @Persisted public var uploadDate: Date?
    @Persisted public var creationDate: Date?
    @Persisted public var modificationDate: Date?
    @Persisted public var taskCreationDate: Date?
    @Persisted var shouldRemoveAfterUpload = true
    @Persisted public var maxRetryCount: Int = defaultMaxRetryCount
    @Persisted private var rawPriority: Int = 0
    @Persisted private var _error: Data?
    @Persisted var conflictOption: ConflictOption
    @Persisted var uploadingSession: UploadingSessionTask?
    
    private var localAsset: PHAsset?

    public var pathURL: URL? {
        get {
            guard let url else {
                return nil
            }
            return URL(fileURLWithPath: url)
        }
        set {
            url = newValue?.path
        }
    }

    public var error: DriveError? {
        get {
            if let error = _error {
                return DriveError.from(realmData: error)
            } else {
                return nil
            }
        }
        set {
            _error = newValue?.toRealm()
        }
    }

    public var size: Int64 {
        if let pathURL = pathURL {
            return (try? FileManager.default.attributesOfItem(atPath: pathURL.path)[.size] as? Int64) ?? 0
        } else {
            return 0
        }
    }

    public var formattedSize: String {
        return Constants.formatFileSize(size)
    }

    var type: UploadFileType {
        return UploadFileType(rawValue: rawType) ?? .unknown
    }

    public var convertedType: ConvertedType {
        if type == .phAsset, let asset = getPHAsset() {
            switch asset.mediaType {
            case .image:
                return .image
            case .video:
                return .video
            case .audio:
                return .audio
            case .unknown:
                return .unknown
            @unknown default:
                return .unknown
            }
        } else if let url = pathURL {
            return ConvertedType.fromUTI(url.uti ?? .data)
        } else {
            return ConvertedType.unknown
        }
    }

    var priority: Operation.QueuePriority {
        get {
            return Operation.QueuePriority(rawValue: rawPriority) ?? .normal
        }
        set {
            rawPriority = newValue.rawValue
        }
    }

    public var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "conflict", value: conflictOption.rawValue),
            URLQueryItem(name: "file_name", value: name),
            // TODO: Upload route needs relative_path/filename to work correctly, remove when upload is done with apiV2
            URLQueryItem(name: "relative_path", value: relativePath + name),
            // URLQueryItem(name: "total_size", value: "\(size)")
            URLQueryItem(name: "asV2", value: nil)
        ]
        if let creationDate = creationDate {
            items.append(URLQueryItem(name: "file_created_at", value: "\(Int(creationDate.timeIntervalSince1970))"))
        }
        if let modificationDate = modificationDate {
            items.append(URLQueryItem(name: "last_modified_at", value: "\(Int(modificationDate.timeIntervalSince1970))"))
        }
        return items
    }

    public init(id: String = UUID().uuidString, parentDirectoryId: Int, userId: Int, driveId: Int, url: URL, name: String? = nil, conflictOption: ConflictOption = .rename, shouldRemoveAfterUpload: Bool = true, priority: Operation.QueuePriority = .normal) {
        self.parentDirectoryId = parentDirectoryId
        self.userId = userId
        self.driveId = driveId
        self.url = url.path
        self.name = name ?? url.lastPathComponent
        self.id = id
        self.shouldRemoveAfterUpload = shouldRemoveAfterUpload
        self.rawType = UploadFileType.file.rawValue
        self.creationDate = url.creationDate
        self.modificationDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        self.taskCreationDate = Date()
        self.conflictOption = conflictOption
        self.rawPriority = priority.rawValue
    }

    public init(parentDirectoryId: Int, userId: Int, driveId: Int, name: String, asset: PHAsset, conflictOption: ConflictOption = .rename, shouldRemoveAfterUpload: Bool = true, priority: Operation.QueuePriority = .normal) {
        self.parentDirectoryId = parentDirectoryId
        self.userId = userId
        self.driveId = driveId
        self.name = name
        self.id = asset.localIdentifier
        self.localAsset = asset
        self.shouldRemoveAfterUpload = shouldRemoveAfterUpload
        self.rawType = UploadFileType.phAsset.rawValue
        self.creationDate = asset.creationDate
        /*
         We use the creationDate instead of the modificationDate
         because this date is not always accurate.
         (It does not seem to correspond to a real modification of the image)
         Apple Feedback: FB11923430
         */
        self.modificationDate = asset.creationDate
        self.taskCreationDate = Date()
        self.conflictOption = conflictOption
        self.rawPriority = priority.rawValue
    }

    override public init() {
        // We have to keep it for Realm
    }

    public enum ThumbnailRequest {
        case phImageRequest(PHImageRequestID)
        case qlThumbnailRequest(QLThumbnailGenerator.Request)

        public func cancel() {
            switch self {
            case .phImageRequest(let requestID):
                PHImageManager.default().cancelImageRequest(requestID)
            case .qlThumbnailRequest(let request):
                QLThumbnailGenerator.shared.cancel(request)
            }
        }
    }

    @discardableResult
    public func getThumbnail(completion: @escaping (UIImage) -> Void) -> ThumbnailRequest? {
        let thumbnailSize = CGSize(width: 38, height: 38)
        if type == .phAsset, let asset = getPHAsset() {
            let option = PHImageRequestOptions()
            option.deliveryMode = .fastFormat
            option.isNetworkAccessAllowed = true
            option.resizeMode = .fast
            let requestID = PHImageManager.default().requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: option) { image, _ in
                if let image = image {
                    completion(image)
                }
            }
            return .phImageRequest(requestID)
        } else if let url = pathURL {
            let request = FilePreviewHelper.instance.getThumbnail(url: url, thumbnailSize: thumbnailSize) { image in
                completion(image)
            }
            return .qlThumbnailRequest(request)
        }
        return nil
    }

    func getPHAsset() -> PHAsset? {
        if localAsset != nil {
            return localAsset
        }
        localAsset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        return localAsset
    }

    func setDatedRelativePath() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/"
        relativePath = dateFormatter.string(from: creationDate ?? Date())
    }
}
