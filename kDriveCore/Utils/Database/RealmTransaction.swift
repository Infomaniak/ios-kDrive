/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import RealmSwift
import Sentry

// TODO: Move to Core
/// Something that can perform a realm transaction with the system aware we would like time to finish it.
public protocol RealmTransactionable {
    /// Execute a transaction, while making the system aware that we wish not to be interrupted.
    /// - Parameters:
    ///   - block: transaction closure
    ///   - completion: completion closure
    func execute<T>(_ block: @escaping (Realm) -> T, completion: @escaping (T) -> Void)

    /// Execute a transaction, while making the system aware that we wish not to be interrupted. Async Await version
    /// - Parameter block: transaction closure
    /// - Returns: Result of the transaction
    func execute<T>(_ block: @escaping (Realm) -> T) async -> T
}

public final class RealmTransaction: RealmTransactionable {
    private let queue: DispatchQueue

    private let realmAccessible: RealmAccessible

    /// Init method
    /// - Parameter realmAccessible: Something that can provide a Realm we can work with
    public init(realmAccessible: RealmAccessible) {
        self.realmAccessible = realmAccessible
        guard let fileURL = realmAccessible.realmConfiguration.fileURL else {
            fatalError("Realm configurations without file URL not supported")
        }
        queue = DispatchQueue(
            label: "com.infomaniak.drive.\(fileURL.lastPathComponent).\(UUID().uuidString)",
            autoreleaseFrequency: .workItem
        )
    }

    public func execute<T>(_ block: @escaping (Realm) -> T, completion: @escaping (T) -> Void) {
        queue.async {
            let activity = ExpiringActivity(id: UUID().uuidString, delegate: nil)
            activity.start()

            let realm = self.realmAccessible.getRealm()
            completion(block(realm))

            activity.endAll()
        }
    }

    public func execute<T>(_ block: @escaping (Realm) -> T) async -> T {
        return await withCheckedContinuation { (continuation: CheckedContinuation<T, Never>) in
            execute(block) { result in
                continuation.resume(returning: result)
            }
        }
    }
}
