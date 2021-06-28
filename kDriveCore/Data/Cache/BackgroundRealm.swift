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
import Sentry

public class BackgroundRealm {

    public static let uploads = getQueue(for: DriveFileManager.constants.uploadsRealmConfiguration)
    private static var instances: [String: BackgroundRealm] = [:]

    private let realm: Realm
    private let queue: DispatchQueue

    public class func getQueue(for configuration: Realm.Configuration) -> BackgroundRealm {
        guard let fileURL = configuration.fileURL else {
            fatalError("Realm configurations without file URL not supported")
        }

        if let instance = instances[fileURL.absoluteString] {
            return instance
        } else {
            let queue = DispatchQueue(label: "com.infomaniak.drive.\(fileURL.lastPathComponent)")
            var realm: Realm!
            queue.sync {
                do {
                    realm = try Realm(configuration: configuration, queue: queue)
                } catch {
                    // We want to capture the error for further investigation ...
                    SentrySDK.capture(error: error) { scope in
                        scope.setContext(value: [
                            "File URL": configuration.fileURL?.absoluteString ?? ""
                            ], key: "Realm")
                    }
                    fatalError("Failed creating background realm")
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

    public func execute(_ block: ((Realm) -> Void)) {
        queue.sync {
            autoreleasepool {
                block(realm)
            }
        }
    }

}
