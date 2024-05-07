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

import CocoaLumberjackSwift
import Foundation
import RealmSwift
import Sentry

// TODO: Remove
public final class BackgroundRealm {
    private struct WriteOperation: Equatable, Hashable {
        let parent: File?
        let file: File

        func hash(into hasher: inout Hasher) {
            if let parentId = parent?.id {
                hasher.combine(parentId)
            }
            hasher.combine(file.id)
        }

        static func == (lhs: WriteOperation, rhs: WriteOperation) -> Bool {
            return lhs.parent?.id == rhs.parent?.id
                && lhs.file.id == rhs.file.id
                && lhs.file.lastModifiedAt == rhs.file.lastModifiedAt
        }
    }

    private static let writeBufferSize = 20
    private static let writeBufferExpiration = 1.0

    // TODO: Remove
    public static let uploads = getQueue(for: DriveFileManager.constants.uploadsRealmConfiguration)
    private static var instances: [String: BackgroundRealm] = [:]

    private let realm: Realm
    private let queue: DispatchQueue
    private var buffer = Set<WriteOperation>()
    private var debouncedBufferWrite: DispatchWorkItem?

    public class func getQueue(for configuration: Realm.Configuration) -> BackgroundRealm {
        guard let fileURL = configuration.fileURL else {
            fatalError("Realm configurations without file URL not supported")
        }

        if let instance = instances[fileURL.absoluteString] {
            return instance
        } else {
            let queue = DispatchQueue(label: "com.infomaniak.drive.\(fileURL.lastPathComponent)", autoreleaseFrequency: .workItem)
            var realm: Realm!
            queue.sync {
                do {
                    realm = try Realm(configuration: configuration, queue: queue)
                } catch {
                    // We can't recover from this error but at least we report it correctly on Sentry
                    Logging.reportRealmOpeningError(error, realmConfiguration: configuration)
                }
            }
            let instance = BackgroundRealm(realm: realm, queue: queue)
            instances[fileURL.absoluteString] = instance
            return instance
        }
    }

    private init(realm: Realm, queue: DispatchQueue) {
        self.realm = realm
        self.queue = queue
    }

    public func execute(_ block: (Realm) -> Void) {
        let activity = ExpiringActivity()
        activity.start()
        queue.sync {
            block(realm)
        }
        activity.endAll()
    }

    /**
     Differ File write in realm for bulk write.

     - Parameter parent: Parent of the file, the file is inserted as a child
     - Parameter file: The file to write in realm

     Writes in realm are differed until either the buffer grows to 20 write operations or 1 second passes.
     - Warning: As the buffer is kept in memory, writes can be lost if the app is terminated eg. case of crash

     */
    public func bufferedWrite(in parent: File?, file: File) {
        buffer.insert(WriteOperation(parent: parent, file: file))
        if buffer.count > BackgroundRealm.writeBufferSize {
            debouncedBufferWrite?.cancel()
            debouncedBufferWrite = nil
            writeBuffer()
        }

        if debouncedBufferWrite == nil {
            let debouncedWorkItem = DispatchWorkItem { [weak self] in
                self?.writeBuffer()
                self?.debouncedBufferWrite = nil
            }
            queue.asyncAfter(deadline: .now() + BackgroundRealm.writeBufferExpiration, execute: debouncedWorkItem)
            debouncedBufferWrite = debouncedWorkItem
        }
    }

    private func writeBuffer() {
        let activity = ExpiringActivity()
        activity.start()
        try? realm.safeWrite {
            for write in buffer {
                realm.add(write.file, update: .all)
                if write.parent?.isInvalidated == false {
                    write.parent?.children.insert(write.file)
                }
            }
        }
        buffer.removeAll()
        activity.endAll()
    }
}
