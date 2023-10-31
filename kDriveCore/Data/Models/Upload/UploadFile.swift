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
import InfomaniakCore
import Photos
import QuickLookThumbnailing
import RealmSwift
import UIKit

enum UploadFileType: String {
    case file, phAsset, unknown
}

public enum ConflictOption: String, PersistableEnum {
    case error, version, rename
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
    /// As a number of chunks can fail in one UploadRequest, the retryCount is slightly higher now
    public static let defaultMaxRetryCount = 5

    public static let observedProperties = ["name",
                                            "url",
                                            "parentDirectoryId",
                                            "userId",
                                            "driveId",
                                            "uploadDate",
                                            "modificationDate",
                                            "_error"]

    @Persisted(primaryKey: true) public var id = ""
    @Persisted public var name = ""
    @Persisted var relativePath = ""
    @Persisted var fileProviderItemIdentifier: String? // NSFileProviderItemIdentifier if any
    @Persisted var assetLocalIdentifier: String? // PHAsset source identifier if any
    @Persisted private var url: String?
    @Persisted private var rawType = "file"
    @Persisted public var parentDirectoryId = 1
    @Persisted public var userId = 0
    @Persisted public var driveId = 0
    @Persisted public var uploadDate: Date?
    @Persisted public var creationDate: Date?
    @Persisted public var modificationDate: Date?
    @Persisted public var taskCreationDate: Date?
    @Persisted public var progress: Double?
    @Persisted var shouldRemoveAfterUpload = true
    @Persisted var initiatedFromFileManager = false
    @Persisted public var maxRetryCount: Int = defaultMaxRetryCount
    @Persisted private var rawPriority = 0
    @Persisted var _error: Data?
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
        if let pathURL {
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

    public init(
        parentDirectoryId: Int,
        userId: Int,
        driveId: Int,
        fileProviderItemIdentifier: String? = nil,
        url: URL,
        name: String? = nil,
        conflictOption: ConflictOption = .rename,
        shouldRemoveAfterUpload: Bool = true,
        initiatedFromFileManager: Bool = false,
        priority: Operation.QueuePriority = .normal
    ) {
        id = UUID().uuidString // We need a strictly unique id for each UploadOperation
        self.parentDirectoryId = parentDirectoryId
        self.userId = userId
        self.driveId = driveId
        self.fileProviderItemIdentifier = fileProviderItemIdentifier
        self.url = url.path
        self.name = name ?? url.lastPathComponent
        self.shouldRemoveAfterUpload = shouldRemoveAfterUpload
        self.initiatedFromFileManager = initiatedFromFileManager
        rawType = UploadFileType.file.rawValue
        creationDate = url.creationDate
        modificationDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        taskCreationDate = Date()
        self.conflictOption = conflictOption
        rawPriority = priority.rawValue
    }

    public init(
        parentDirectoryId: Int,
        userId: Int,
        driveId: Int,
        name: String,
        asset: PHAsset,
        conflictOption: ConflictOption = .rename,
        shouldRemoveAfterUpload: Bool = true,
        priority: Operation.QueuePriority = .normal
    ) {
        id = UUID().uuidString // We need a strictly unique id for each UploadOperation
        self.parentDirectoryId = parentDirectoryId
        self.userId = userId
        self.driveId = driveId
        self.name = name
        assetLocalIdentifier = asset.localIdentifier

        localAsset = asset
        self.shouldRemoveAfterUpload = shouldRemoveAfterUpload
        rawType = UploadFileType.phAsset.rawValue
        creationDate = asset.creationDate
        /*
         We use the creationDate instead of the modificationDate
         because this date is not always accurate.
         (It does not seem to correspond to a real modification of the image)
         Apple Feedback: FB11923430
         */
        modificationDate = asset.creationDate
        taskCreationDate = Date()
        self.conflictOption = conflictOption
        rawPriority = priority.rawValue
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
            let requestID = PHImageManager.default()
                .requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: option) { image, _ in
                    if let image {
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

        guard let assetLocalIdentifier else {
            return nil
        }

        localAsset = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalIdentifier], options: nil).firstObject
        return localAsset
    }

    func setDatedRelativePath() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/"
        relativePath = dateFormatter.string(from: creationDate ?? Date())
    }
    
    /// Set a relative path to an arbitrary album name
    func setAlbumRelativePath(name: String) {
        relativePath = name
    }
}

public extension UploadFile {
    func contains(chunkUrl: String) -> Bool {
        let result = uploadingSession?.chunkTasks.filter { $0.requestUrl == chunkUrl }
        return (result?.count ?? 0) > 0
    }
}

public extension UploadFile {
    /// Centralize error cleaning
    func clearErrorsForRetry() {
        // Clear any stored error
        error = nil
        // Reset retry count to default
        maxRetryCount = UploadFile.defaultMaxRetryCount
        // Assign the UploadFile to the main app, not the FileManager extension
        initiatedFromFileManager = false
    }
}

public extension [UploadFile] {
    func firstContaining(chunkUrl: String) -> UploadFile? {
        // keep only the files with a valid uploading session
        let files = filter {
            ($0.uploadDate == nil) && ($0.uploadingSession?.uploadSession != nil)
        }
        Log.bgSessionManager("files:\(files.count) :\(chunkUrl)")

        // find the first one that matches [the query (that matches the chunk request)]
        let file = files.first { $0.contains(chunkUrl: chunkUrl) }
        return file
    }
}
