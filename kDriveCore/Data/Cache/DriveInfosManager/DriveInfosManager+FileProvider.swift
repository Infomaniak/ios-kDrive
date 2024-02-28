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

import CocoaLumberjackSwift
import FileProvider
import Foundation
import InfomaniakConcurrency
import InfomaniakCore

public extension DriveInfosManager {
    private typealias FilteredDomain = (new: NSFileProviderDomain, existing: NSFileProviderDomain?)

    internal func initFileProviderDomains(drives: [Drive], user: InfomaniakCore.UserProfile) {
        // Clean file provider storage if needed
        if UserDefaults.shared.fpStorageVersion < currentFpStorageVersion {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: NSFileProviderManager.default.documentStorageURL,
                    includingPropertiesForKeys: nil
                )
                for url in fileURLs {
                    try FileManager.default.removeItem(at: url)
                }
                UserDefaults.shared.fpStorageVersion = currentFpStorageVersion
            } catch {
                // TODO: Sentry
            }
        }

        // TODO: Start Activity
        Task {
            let updatedDomains = drives.map {
                NSFileProviderDomain(
                    identifier: NSFileProviderDomainIdentifier($0.objectId),
                    displayName: "\($0.name) (\(user.email))",
                    pathRelativeToDocumentStorage: "\($0.objectId)"
                )
            }

            do {
                let allDomains = try await NSFileProviderManager.domains()
                let existingDomainsForCurrentUser = allDomains.filter { $0.identifier.rawValue.hasSuffix("_\(user.id)") }

                let updatedDomainsForCurrentUser: [FilteredDomain] = updatedDomains.map { newDomain in
                    let existingDomain = existingDomainsForCurrentUser.first { $0.identifier == newDomain.identifier }
                    return (newDomain, existingDomain)
                }

                try await updatedDomainsForCurrentUser.concurrentForEach(customConcurrency: 1) { domain in
                    // Simply add domain if new
                    let newDomain = domain.new
                    guard let existingDomain = domain.existing else {
                        try await NSFileProviderManager.add(newDomain)
                        return
                    }

                    // Update existing accounts if necessary
                    if existingDomain.displayName != newDomain.displayName {
                        try await NSFileProviderManager.remove(existingDomain)
                        try await NSFileProviderManager.add(newDomain)
                        self.signalChanges(for: newDomain)
                    }
                }

                // Remove domains no longer present for current user
                let removedDomainsForCurrentUser = updatedDomains.filter { updatedDomain in
                    guard existingDomainsForCurrentUser.contains(where: { $0.identifier == updatedDomain.identifier }) else {
                        return true
                    }

                    return false
                }

                try await removedDomainsForCurrentUser.concurrentForEach(customConcurrency: 1) { oldDomain in
                    try await NSFileProviderManager.remove(oldDomain)
                }
            } catch {
                DDLogError("Error while updating file provider domains: \(error)")
                // TODO: add Sentry
            }

            // TODO: notify for consistency
        }
    }

    internal func deleteFileProviderDomains(for userId: Int) {
        NSFileProviderManager.getDomainsWithCompletionHandler { allDomains, error in
            if let error {
                DDLogError("Error while getting domains: \(error)")
            }

            let domainsForCurrentUser = allDomains.filter { $0.identifier.rawValue.hasSuffix("_\(userId)") }
            for domain in domainsForCurrentUser {
                NSFileProviderManager.remove(domain) { error in
                    if let error {
                        DDLogError("Error while removing domain \(domain.displayName): \(error)")
                    }
                }
            }
        }
    }

    func deleteAllFileProviderDomains() {
        NSFileProviderManager.removeAllDomains { error in
            if let error {
                DDLogError("Error while removing domains: \(error)")
            }
        }
    }

    internal func getFileProviderDomain(for driveId: String, completion: @escaping (NSFileProviderDomain?) -> Void) {
        NSFileProviderManager.getDomainsWithCompletionHandler { domains, error in
            if let error {
                DDLogError("Error while getting domains: \(error)")
                completion(nil)
            } else {
                completion(domains.first { $0.identifier.rawValue == driveId })
            }
        }
    }

    func getFileProviderManager(for drive: Drive, completion: @escaping (NSFileProviderManager) -> Void) {
        getFileProviderManager(for: drive.objectId, completion: completion)
    }

    func getFileProviderManager(driveId: Int, userId: Int, completion: @escaping (NSFileProviderManager) -> Void) {
        let objectId = DriveInfosManager.getObjectId(driveId: driveId, userId: userId)
        getFileProviderManager(for: objectId, completion: completion)
    }

    func getFileProviderManager(for driveId: String, completion: @escaping (NSFileProviderManager) -> Void) {
        getFileProviderDomain(for: driveId) { domain in
            if let domain {
                completion(NSFileProviderManager(for: domain) ?? .default)
            } else {
                completion(.default)
            }
        }
    }

    // MARK: Signal

    /// Signal changes on this Drive to the File Provider Extension
    private func signalChanges(for domain: NSFileProviderDomain) {
        guard let driveId = domain.driveId, let userId = domain.userId else {
            // Sentry
            return
        }

        DriveInfosManager.instance.getFileProviderManager(driveId: driveId, userId: userId) { manager in
            manager.signalEnumerator(for: .workingSet) { _ in
                // META: keep SonarCloud happy
            }
            manager.signalEnumerator(for: .rootContainer) { _ in
                // META: keep SonarCloud happy
            }
        }
    }
}
