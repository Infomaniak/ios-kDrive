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
import RealmSwift
import Photos
import DifferenceKit
import UIKit

enum UploadFileType: String {
    case file, phAsset, unknown
}

public class UploadFile: Object {

    public static let defaultMaxRetryCount = 3

    @objc public dynamic var id: String = ""
    @objc public dynamic var name: String = ""
    @objc dynamic var relativePath: String = ""
    @objc dynamic var sessionUrl: String = ""
    @objc private dynamic var url: String?
    @objc private dynamic var rawType: String = "file"
    @objc public dynamic var parentDirectoryId: Int = 1
    @objc dynamic var userId: Int = 0
    @objc dynamic var driveId: Int = 0
    @objc public dynamic var uploadDate: Date?
    @objc public dynamic var creationDate: Date?
    @objc public dynamic var modificationDate: Date?
    @objc public dynamic var taskCreationDate: Date?
    @objc dynamic var shouldRemoveAfterUpload = true
    @objc public dynamic var maxRetryCount: Int = defaultMaxRetryCount
    @objc private dynamic var rawPriority: Int = 0
    @objc private dynamic var _error: Data?

    private var localAsset: PHAsset?

    public var isFirstInCollection = false
    public var isLastInCollection = false

    var urlEncodedName: String {
        return name.addingPercentEncoding(withAllowedCharacters: .afURLQueryAllowed)!
    }

    var urlEncodedRelativePath: String {
        return relativePath.addingPercentEncoding(withAllowedCharacters: .afURLQueryAllowed)!
    }

    public var pathURL: URL? {
        get {
            return url == nil ? nil : URL(fileURLWithPath: url!)
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

    var priority: Operation.QueuePriority {
        get {
            return Operation.QueuePriority(rawValue: rawPriority) ?? .normal
        }
        set {
            rawPriority = newValue.rawValue
        }
    }

    public init(id: String = UUID().uuidString, parentDirectoryId: Int, userId: Int, driveId: Int, url: URL, name: String? = nil, shouldRemoveAfterUpload: Bool = true, priority: Operation.QueuePriority = .normal) {
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
        self.rawPriority = priority.rawValue
    }

    public init(parentDirectoryId: Int, userId: Int, driveId: Int, name: String, asset: PHAsset, creationDate: Date?, modificationDate: Date?, shouldRemoveAfterUpload: Bool = true, priority: Operation.QueuePriority = .normal) {
        self.parentDirectoryId = parentDirectoryId
        self.userId = userId
        self.driveId = driveId
        self.name = name
        self.id = asset.localIdentifier
        self.localAsset = asset
        self.shouldRemoveAfterUpload = shouldRemoveAfterUpload
        self.rawType = UploadFileType.phAsset.rawValue
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.taskCreationDate = Date()
        self.rawPriority = priority.rawValue
    }

    override init() {

    }

    public func getIconForUploadFile(placeholder: (UIImage) -> Void, completion: @escaping (UIImage) -> Void) {
        if type == .phAsset {
            let asset = getPHAsset()
            if asset?.mediaType == .video {
                placeholder(ConvertedType.video.icon)
            } else if asset?.mediaType == .audio {
                placeholder(ConvertedType.audio.icon)
            } else {
                placeholder(ConvertedType.image.icon)
            }
            if let asset = asset {
                let option = PHImageRequestOptions()
                option.deliveryMode = .fastFormat
                option.isNetworkAccessAllowed = true
                option.resizeMode = .fast
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 128, height: 128), contentMode: .aspectFill, options: option) { image, _ in
                    if let image = image {
                        completion(image)
                    }
                }
            }
        } else {
            let uti = pathURL?.uti ?? .data
            placeholder(ConvertedType.fromUTI(uti).icon)
        }
    }

    func getPHAsset() -> PHAsset? {
        if localAsset != nil {
            return localAsset
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        // swiftlint:disable empty_count
        if assets.count > 0 {
            return assets[0]
        }

        return nil
    }

    override public class func primaryKey() -> String? {
        return "id"
    }

    func setVideoPath(url: URL) {
        self.url = url.path
        self.name = url.lastPathComponent

        self.id = "\(Date().timeIntervalSinceNow)-\(name)"
    }

    func setDatedRelativePath() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/"
        relativePath = dateFormatter.string(from: creationDate ?? Date())
    }

}

extension UploadFile: Differentiable {

    public var differenceIdentifier: String {
        return id
    }

    public func isContentEqual(to source: UploadFile) -> Bool {
        return name == source.name
            && _error == source._error
            && isFirstInCollection == source.isFirstInCollection
            && isLastInCollection == source.isLastInCollection
    }
}
