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

import FileProvider
import Foundation
import InfomaniakConcurrency
import InfomaniakCore
import InfomaniakDI

public extension DriveInfosManager {
    private typealias FilteredDomain = (new: NSFileProviderDomain, existing: NSFileProviderDomain?)

    internal func initFileProviderDomains(frozenDrives: [Drive], user: InfomaniakCore.UserProfile) {
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
                Log.driveInfosManager("FileManager issue :\(error)", level: .error)
            }
        }

        updateFileManagerDomains(frozenDrives: frozenDrives, user: user)
    }

    internal func deleteFileProviderDomains(for userId: Int) {
        NSFileProviderManager.getDomainsWithCompletionHandler { allDomains, error in
            if let error {
                Log.driveInfosManager("Error while getting domains: \(error)", level: .error)
            }

            let domainsForCurrentUser = allDomains.filter { $0.identifier.rawValue.hasSuffix("_\(userId)") }
            for domain in domainsForCurrentUser {
                NSFileProviderManager.remove(domain) { error in
                    guard let error else {
                        return
                    }
                    Log.driveInfosManager("Error while removing domain \(domain.displayName): \(error)", level: .error)
                }
            }
        }
    }

    func deleteAllFileProviderDomains() {
        NSFileProviderManager.removeAllDomains { error in
            guard let error else {
                Log.driveInfosManager("Did remove all domains")
                return
            }
            Log.driveInfosManager("Error while removing domains: \(error)", level: .error)
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

    private func getFileProviderDomain(for driveId: String, completion: @escaping (NSFileProviderDomain?) -> Void) {
        NSFileProviderManager.getDomainsWithCompletionHandler { domains, error in
            if let error {
                Log.driveInfosManager("Error while getting domains: \(error)", level: .error)
                completion(nil)
            } else {
                completion(domains.first { $0.identifier.rawValue == driveId })
            }
        }
    }

    // MARK: Update FileManager

    /// Diffing __NSFileProviderDomain__ for drives of a specified user, and propagate changes to the __NSFileProviderManager__
    ///
    /// Requires frozen drives as making use of async await
    private func updateFileManagerDomains(frozenDrives: [Drive], user: InfomaniakCore.UserProfile) {
        let expiringActivity = ExpiringActivity(id: "\(#function)_\(UUID().uuidString)", delegate: nil)
        expiringActivity.start()
        Task {
            let updatedDomains = frozenDrives.map {
                NSFileProviderDomain(
                    identifier: NSFileProviderDomainIdentifier($0.objectId),
                    displayName: "\($0.name) (\(user.email))",
                    pathRelativeToDocumentStorage: "\($0.objectId)"
                )
            }

            Log.driveInfosManager("Updated domains \(updatedDomains.count) for user :\(user.displayName) \(user.id)")
            do {
                try await updateDomainsIfNecessary(updatedDomains: updatedDomains, userId: user.id)
                try await deleteDomainsIfNecessary(updatedDomains: updatedDomains, userId: user.id)
            } catch {
                Log.driveInfosManager("Error while updating file provider domains: \(error)", level: .error)
            }

            expiringActivity.endAll()
        }
    }

    /// Insert or update Domains if necessary
    private func updateDomainsIfNecessary(updatedDomains: [NSFileProviderDomain], userId: Int) async throws {
        let existingDomainsForCurrentUser = try await existingDomains(for: userId)

        let updatedDomainsForCurrentUser: [FilteredDomain] = updatedDomains.map { newDomain in
            let existingDomain = existingDomainsForCurrentUser.first { $0.identifier == newDomain.identifier }
            return (newDomain, existingDomain)
        }

        try await updatedDomainsForCurrentUser.concurrentForEach(customConcurrency: 1) { domain in
            // Simply add domain if new
            let newDomain = domain.new
            guard let existingDomain = domain.existing else {
                Log.driveInfosManager("Inserting new domain:\(newDomain.identifier)")
                try await NSFileProviderManager.add(newDomain)
                self.signalChanges(for: newDomain)
                return
            }

            // Update existing accounts if necessary
            if existingDomain.displayName != newDomain.displayName {
                Log.driveInfosManager("Updating domain:\(newDomain.identifier)")
                try await NSFileProviderManager.remove(existingDomain)
                try await NSFileProviderManager.add(newDomain)
                self.signalChanges(for: newDomain)
            }
        }
    }

    /// Delete Domains if necessary
    private func deleteDomainsIfNecessary(updatedDomains: [NSFileProviderDomain], userId: Int) async throws {
        // We need to fetch a fresh copy of the domains after the update
        let existingDomainsForCurrentUser = try await existingDomains(for: userId)

        // Remove domains no longer present for current user
        let removedDomainsForCurrentUser = updatedDomains.filter { updatedDomain in
            guard existingDomainsForCurrentUser.contains(where: { $0.identifier == updatedDomain.identifier }) else {
                return true
            }

            return false
        }

        try await removedDomainsForCurrentUser.concurrentForEach(customConcurrency: 1) { oldDomain in
            Log.driveInfosManager("Removing domain:\(oldDomain.identifier)")
            try await NSFileProviderManager.remove(oldDomain)
        }
    }

    /// Fetch a fresh list of registered domains for a specified user
    private func existingDomains(for userId: Int) async throws -> [NSFileProviderDomain] {
        let allDomains = try await NSFileProviderManager.domains()
        let existingDomains = allDomains.filter { $0.identifier.rawValue.hasSuffix("_\(userId)") }
        return existingDomains
    }

    // MARK: Signal FileManager

    /// Signal changes on this Drive to the File Provider Extension
    private func signalChanges(for domain: NSFileProviderDomain) {
        guard let driveId = domain.driveId, let userId = domain.userId else {
            Log.driveInfosManager(
                "Unable to read: driveId:\(String(describing: domain.driveId)) userId:\(String(describing: domain.userId))",
                level: .error
            )
            return
        }

        getFileProviderManager(driveId: driveId, userId: userId) { manager in
            manager.signalEnumerator(for: .workingSet) { error in
                guard let error else {
                    Log.driveInfosManager("did signal .workingSet")
                    return
                }

                Log.driveInfosManager("failed to signal .workingSet \(error)", level: .error)
            }
            manager.signalEnumerator(for: .rootContainer) { error in
                guard let error else {
                    Log.driveInfosManager("did signal .rootContainer")
                    return
                }
                Log.driveInfosManager("failed to signal .rootContainer \(error)", level: .error)
            }
        }
    }
}
