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
import InfomaniakDI

public class DragAndDropFile: NSObject, Codable {
    static let localDragIdentifier = "private.kdrive.file"
    @LazyInjectService var downloadQueue: DownloadQueue

    public let fileId: Int
    public let driveId: Int
    public let userId: Int
    public let file: File?

    public init(file: File, userId: Int) {
        fileId = file.id
        driveId = file.driveId
        self.userId = userId
        self.file = file
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        fileId = try values.decode(Int.self, forKey: .fileId)
        driveId = try values.decode(Int.self, forKey: .driveId)
        userId = try values.decode(Int.self, forKey: .userId)
        @InjectService var accountManager: AccountManageable
        file = accountManager.getDriveFileManager(for: driveId, userId: userId)?.getCachedFile(id: fileId)
    }

    enum CodingKeys: String, CodingKey {
        case fileId
        case driveId
        case userId
    }
}

// MARK: - NSItemProviderReading

extension DragAndDropFile: NSItemProviderReading {
    private static let decoder = JSONDecoder()

    public static var readableTypeIdentifiersForItemProvider: [String] {
        return [localDragIdentifier]
    }

    public static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        return try decoder.decode(DragAndDropFile.self, from: data) as! Self
    }
}

// MARK: - NSItemProviderWriting

extension DragAndDropFile: NSItemProviderWriting {
    public static var writableTypeIdentifiersForItemProvider: [String] {
        return [localDragIdentifier, UTI.item.identifier, UTI.data.identifier]
    }

    public var writableTypeIdentifiersForItemProvider: [String] {
        if let file {
            return [
                DragAndDropFile.localDragIdentifier,
                file.isDirectory ? UTI.zip.identifier : file.uti.identifier,
                UTI.item.identifier,
                UTI.data.identifier
            ]
        } else {
            return [DragAndDropFile.localDragIdentifier, UTI.item.identifier, UTI.data.identifier]
        }
    }

    private func loadLocalData(for url: URL, completionHandler: @escaping (Data?, Error?) -> Void) {
        do {
            let data = try Data(contentsOf: url)
            completionHandler(data, nil)
        } catch {
            completionHandler(nil, error)
        }
    }

    public func loadData(withTypeIdentifier typeIdentifier: String,
                         forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        guard let file else {
            completionHandler(nil, nil)
            return nil
        }

        if typeIdentifier == DragAndDropFile.localDragIdentifier {
            let encoder = JSONEncoder()
            do {
                let encodedData = try encoder.encode(self)
                completionHandler(encodedData, nil)
            } catch {
                completionHandler(nil, error)
            }
            return nil
        } else {
            if !file.isLocalVersionOlderThanRemote {
                loadLocalData(for: file.localUrl, completionHandler: completionHandler)
                return nil
            } else {
                let progress = Progress(totalUnitCount: 100)
                downloadQueue.temporaryDownload(file: file, userId: userId) { operation in
                    progress.cancellationHandler = {
                        operation?.cancel()
                    }
                    if let operation,
                       let downloadProgress = operation.task?.progress {
                        progress.addChild(downloadProgress, withPendingUnitCount: 100)
                    }
                } completion: { [weak self] error in
                    guard let self else { return }
                    if let error {
                        completionHandler(nil, error)
                    } else {
                        let url = file.isDirectory ? file.temporaryUrl : file.localUrl
                        loadLocalData(for: url, completionHandler: completionHandler)
                    }
                }
                return progress
            }
        }
    }
}
