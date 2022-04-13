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

public class BackgroundRealm {
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
            return lhs.parent?.id == rhs.parent?.id && lhs.file.id == rhs.file.id && lhs.file.lastModifiedAt == rhs.file.lastModifiedAt
        }
    }

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
        queue.sync {
            block(realm)
        }
    }

    public func bufferedWrite(in parent: File?, file: File) {
        buffer.insert(WriteOperation(parent: parent, file: file))
        DDLogInfo("[BackgroundRealm] Buffer size \(buffer.count)")
        if buffer.count > 20 {
            DDLogInfo("[BackgroundRealm] Buffer size exceeded \(buffer.count)")
            debouncedBufferWrite?.cancel()
            debouncedBufferWrite = nil
            writeBuffer()
        }

        if debouncedBufferWrite == nil {
            let debouncedWorkItem = DispatchWorkItem { [weak self] in
                DDLogInfo("[BackgroundRealm] Buffer expired writing data...")
                self?.writeBuffer()
                self?.debouncedBufferWrite = nil
            }
            queue.asyncAfter(deadline: .now() + 1, execute: debouncedWorkItem)
            debouncedBufferWrite = debouncedWorkItem
        }
    }

    private func writeBuffer() {
        try? realm.safeWrite {
            for write in buffer {
                realm.add(write.file, update: .all)
                write.parent?.children.insert(write.file)
            }
        }
        buffer.removeAll()
        DDLogInfo("[BackgroundRealm] Buffer written")
    }
}
