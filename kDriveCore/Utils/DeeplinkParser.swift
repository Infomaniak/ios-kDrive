/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import MatomoTracker
import SwiftUI

/// Deeplink entrypoint
public protocol DeeplinkParsable {
    /// Parse a deeplink and navigate to the desired location
    func parse(url: URL) async -> Bool
}

public struct DeeplinkParser: DeeplinkParsable {
    private enum DeeplinkPath: String {
        case store
        case file
        case search
        case subscriptions
    }

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var router: AppNavigable

    private let sharedContainerURL: URL?

    public init() {
        sharedContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: KDriveFileSharing.appGroupIdentifier
        )
    }

    init(sharedContainerURL: URL?) {
        self.sharedContainerURL = sharedContainerURL
    }

    private func handleDeeplink(url: URL) async -> Bool {
        if url.host == DeeplinkPath.subscriptions.rawValue {
            guard let driveFileManager = accountManager.currentDriveFileManager else {
                return false
            }
            await router.navigate(to: .store(driveId: driveFileManager.driveId, userId: accountManager.currentUserId))
            return true
        }
        if let sharedWithMeLink = await SharedWithMeLink(sharedWithMeURL: url) {
            await router.navigate(to: .sharedWithMe(sharedWithMeLink: sharedWithMeLink))
            return true
        }
        if let officeLink = OfficeLink(officeURL: url) {
            await router.navigate(to: .office(officeLink: officeLink))
            return true
        }
        if let privateShareLink = PrivateShareLink(privateShareUrl: url) {
            await router.navigate(to: .privateShare(privateShareLink: privateShareLink))
            return true
        }
        if let publicShareLink = PublicShareLink(publicShareURL: url) {
            await router.navigate(to: .publicShare(publicShareLink: publicShareLink))
            return true
        }
        if let directoryLink = DirectoryLink(directoryURL: url) {
            await router.navigate(to: .directory(directoryLink: directoryLink))
            return true
        }
        if let filePreviewLink = FilePreviewLink(filePreviewURL: url) {
            await router.navigate(to: .filePreview(filePreviewLink: filePreviewLink))
            return true
        }
        if let favoritePreviewLink = FavoritePreviewLink(filePreviewURL: url) {
            await router.navigate(to: .favoritePreview(favoritePreviewLink: favoritePreviewLink))
            return true
        }
        if let basicLink = BasicLink(basicURL: url) {
            await router.navigate(to: .basic(basicLink: basicLink))
            return true
        }
        if let searchLink = SearchLink(searchURL: url) {
            await router.navigate(to: .search(searchLink: searchLink))
            return true
        } else {
            Log.sceneDelegate("Failed to open URL: Invalid URL", level: .error)
            return false
        }
    }

    public func parse(url: URL) async -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return await handleDeeplink(url: url)
        }

        if components.scheme == KDriveFileSharing.scheme, components.host == KDriveFileSharing.host {
            guard let files = filesForSharingDeeplink(url) else {
                Log.sceneDelegate("Failed to import files: Invalid request", level: .error)
                return false
            }
            await router.navigate(to: .saveFiles(files: files))
            matomo.track(eventWithCategory: .deeplink, name: DeeplinkPath.file.rawValue)
            return true
        }

        guard let params = components.queryItems else {
            return await handleDeeplink(url: url)
        }

        if components.path.split(separator: "/").last ?? "" == DeeplinkPath.search.rawValue {
            if let searchLink = SearchLink(searchURL: url) {
                await router.navigate(to: .search(searchLink: searchLink))
                return true
            }
        } else if components.path == DeeplinkPath.store.rawValue,
                  let userId = params.first(where: { $0.name == "userId" })?.value,
                  let driveId = params.first(where: { $0.name == "driveId" })?.value,
                  let driveIdInt = Int(driveId), let userIdInt = Int(userId) {
            await router.navigate(to: .store(driveId: driveIdInt, userId: userIdInt))
            matomo.track(eventWithCategory: .deeplink, name: DeeplinkPath.store.rawValue)
            return true
        }

        Log.sceneDelegate("unable to parse deeplink URL: \(url)", level: .error)
        return false
    }

    func filesForSharingDeeplink(_ url: URL) -> [ImportedFile]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == KDriveFileSharing.scheme,
              components.host == KDriveFileSharing.host,
              components.path.isEmpty,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              let queryItems = components.queryItems,
              !queryItems.isEmpty,
              queryItems.count <= KDriveFileSharing.maximumFileCount,
              queryItems.allSatisfy({
                  $0.name == KDriveFileSharing.urlQueryItemName && !($0.value?.isEmpty ?? true)
              }),
              let sharedContainerURL else {
            return nil
        }

        let handoffRootURL = KDriveFileSharing.handoffDirectoryURL(in: sharedContainerURL).standardizedFileURL
        let resolvedSharedContainerURL = sharedContainerURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedHandoffRootURL = handoffRootURL.resolvingSymlinksInPath().standardizedFileURL
        let expectedHandoffRootURL = KDriveFileSharing
            .handoffDirectoryURL(in: resolvedSharedContainerURL)
            .standardizedFileURL
        guard resolvedHandoffRootURL == expectedHandoffRootURL else {
            return nil
        }

        var files = [ImportedFile]()
        for queryItem in queryItems {
            guard let path = queryItem.value,
                  NSString(string: path).isAbsolutePath,
                  let fileName = path.safeLastPathComponent else {
                return nil
            }

            let sourceURL = URL(fileURLWithPath: path).standardizedFileURL
            guard sourceURL.isSharedFile(in: handoffRootURL) else {
                return nil
            }

            let resolvedSourceURL = sourceURL.resolvingSymlinksInPath().standardizedFileURL
            let expectedSourceURL = sourceURL.pathComponents
                .suffix(2)
                .reduce(resolvedHandoffRootURL) { $0.appendingPathComponent($1) }
                .standardizedFileURL
            guard resolvedSourceURL == expectedSourceURL,
                  let values = try? resolvedSourceURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else {
                return nil
            }

            files.append(ImportedFile(
                name: fileName,
                path: resolvedSourceURL,
                uti: resolvedSourceURL.uti ?? .data
            ))
        }
        return files
    }
}

private extension URL {
    func isSharedFile(in rootURL: URL) -> Bool {
        let rootComponents = rootURL.pathComponents
        let sourceComponents = pathComponents
        guard sourceComponents.count == rootComponents.count + 2,
              Array(sourceComponents.prefix(rootComponents.count)) == rootComponents else {
            return false
        }
        return UUID(uuidString: sourceComponents[rootComponents.count]) != nil
    }
}
