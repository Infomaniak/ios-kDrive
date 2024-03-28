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

import Alamofire
import Foundation
import InfomaniakCore
import InfomaniakDI
import InfomaniakLogin
import Kingfisher
import UIKit

public extension ApiFetcher {
    convenience init(token: ApiToken, delegate: RefreshTokenDelegate) {
        self.init()
        createAuthenticatedSession(token,
                                   authenticator: SyncedAuthenticator(refreshTokenDelegate: delegate),
                                   additionalAdapters: [UserAgentAdapter()])
    }
}

public class AuthenticatedImageRequestModifier: ImageDownloadRequestModifier {
    weak var apiFetcher: ApiFetcher?

    init(apiFetcher: ApiFetcher) {
        self.apiFetcher = apiFetcher
    }

    public func modified(for request: URLRequest) -> URLRequest? {
        if let token = apiFetcher?.currentToken?.accessToken {
            var newRequest = request
            newRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return newRequest
        } else {
            return nil
        }
    }
}

public class DriveApiFetcher: ApiFetcher {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var tokenable: InfomaniakTokenable

    public var authenticatedKF: AuthenticatedImageRequestModifier!

    override public init() {
        super.init()
        authenticatedKF = AuthenticatedImageRequestModifier(apiFetcher: self)
    }

    override public func perform<T: Decodable>(request: DataRequest,
                                               decoder: JSONDecoder = ApiFetcher.decoder) async throws -> ValidServerResponse<T> {
        do {
            return try await super.perform(request: request)
        } catch InfomaniakError.apiError(let apiError) {
            throw DriveError(apiError: apiError)
        } catch InfomaniakError.serverError(statusCode: let statusCode) {
            throw DriveError.serverError(statusCode: statusCode)
        }
    }

    // MARK: - API methods

    func userDrives() async throws -> DriveResponse {
        try await perform(request: authenticatedRequest(.initData))
    }

    public func createDirectory(in parentDirectory: ProxyFile, name: String, onlyForMe: Bool) async throws -> File {
        try await perform(request: authenticatedRequest(
            .createDirectory(in: parentDirectory),
            method: .post,
            parameters: ["name": name, "only_for_me": onlyForMe]
        ))
    }

    public func createCommonDirectory(drive: AbstractDrive, name: String, forAllUser: Bool) async throws -> File {
        try await perform(request: authenticatedRequest(
            .createTeamDirectory(drive: drive),
            method: .post,
            parameters: ["name": name, "for_all_user": forAllUser]
        ))
    }

    public func createFile(in parentDirectory: ProxyFile, name: String, type: String) async throws -> File {
        try await perform(request: authenticatedRequest(.createFile(in: parentDirectory), method: .post,
                                                        parameters: ["name": name, "type": type]))
    }

    public func createDropBox(directory: ProxyFile, settings: DropBoxSettings) async throws -> DropBox {
        try await perform(request: authenticatedRequest(.dropbox(file: directory), method: .post, parameters: settings))
    }

    public func getDropBox(directory: ProxyFile) async throws -> DropBox {
        try await perform(request: authenticatedRequest(.dropbox(file: directory)))
    }

    public func updateDropBox(directory: ProxyFile, settings: DropBoxSettings) async throws -> Bool {
        try await perform(request: authenticatedRequest(.dropbox(file: directory), method: .put, parameters: settings))
    }

    public func deleteDropBox(directory: ProxyFile) async throws -> Bool {
        try await perform(request: authenticatedRequest(.dropbox(file: directory), method: .delete))
    }

    public func rootFiles(drive: AbstractDrive,
                          cursor: String?,
                          sortType: SortType = .nameAZ) async throws -> ValidServerResponse<[File]> {
        try await perform(request: authenticatedRequest(
            .rootFiles(drive: drive)
                .sorted(by: [.type, sortType]),
            method: .get
        ))
    }

    public func files(in directory: ProxyFile,
                      cursor: String?,
                      sortType: SortType = .nameAZ) async throws -> ValidServerResponse<[File]> {
        try await perform(request: authenticatedRequest(
            .files(of: directory)
                .sorted(by: [.type, sortType])
                .cursored(cursor),
            method: .get
        ))
    }

    public func fileInfo(_ file: ProxyFile) async throws -> ValidServerResponse<File> {
        try await perform(request: authenticatedRequest(.fileInfo(file)))
    }

    public func favorites(drive: AbstractDrive,
                          cursor: String? = nil,
                          sortType: SortType = .nameAZ) async throws -> ValidServerResponse<[File]> {
        try await perform(request: authenticatedRequest(.favorites(drive: drive)
                .sorted(by: [.type, sortType])
                .cursored(cursor)))
    }

    public func mySharedFiles(drive: AbstractDrive,
                              cursor: String? = nil,
                              sortType: SortType = .nameAZ) async throws -> ValidServerResponse<[File]> {
        try await perform(request: authenticatedRequest(.mySharedFiles(drive: drive)
                .cursored(cursor)
                .sorted(by: [.type, sortType])))
    }

    public func sharedWithMeFiles(drive: AbstractDrive,
                                  cursor: String? = nil,
                                  sortType: SortType = .nameAZ) async throws -> ValidServerResponse<[File]> {
        try await perform(request: authenticatedRequest(.sharedWithMeFiles(drive: drive)
                .cursored(cursor)
                .sorted(by: [.type, sortType])))
    }

    public func lastModifiedFiles(drive: AbstractDrive,
                                  cursor: String? = nil) async throws -> ValidServerResponse<[File]> {
        try await perform(request: authenticatedRequest(.lastModifiedFiles(drive: drive).cursored(cursor)))
    }

    public func shareLink(for file: ProxyFile) async throws -> ShareLink {
        try await perform(request: authenticatedRequest(.shareLink(file: file)))
    }

    public func createShareLink(for file: ProxyFile, isFreeDrive: Bool) async throws -> ShareLink {
        try await perform(request: authenticatedRequest(
            .shareLink(file: file),
            method: .post,
            parameters: ShareLinkSettings(right: .public, isFreeDrive: isFreeDrive)
        ))
    }

    public func updateShareLink(for file: ProxyFile, settings: ShareLinkSettings) async throws -> Bool {
        try await perform(request: authenticatedRequest(.shareLink(file: file), method: .put, parameters: settings))
    }

    public func removeShareLink(for file: ProxyFile) async throws -> Bool {
        try await perform(request: authenticatedRequest(.shareLink(file: file), method: .delete))
    }

    public func access(for file: ProxyFile) async throws -> FileAccess {
        try await perform(request: authenticatedRequest(.access(file: file)))
    }

    public func checkAccessChange(to file: ProxyFile,
                                  settings: FileAccessSettings) async throws -> [CheckChangeAccessFeedbackResource] {
        try await perform(request: authenticatedRequest(.checkAccess(file: file), method: .post, parameters: settings))
    }

    public func addAccess(to file: ProxyFile, settings: FileAccessSettings) async throws -> AccessResponse {
        try await perform(request: authenticatedRequest(.access(file: file), method: .post, parameters: settings))
    }

    public func forceAccess(to file: ProxyFile) async throws -> Bool {
        try await perform(request: authenticatedRequest(.forceAccess(file: file), method: .post))
    }

    public func updateUserAccess(to file: ProxyFile, user: UserFileAccess, right: UserPermission) async throws -> Bool {
        try await perform(request: authenticatedRequest(.userAccess(file: file, id: user.id), method: .put,
                                                        parameters: ["right": right]))
    }

    public func removeUserAccess(to file: ProxyFile, user: UserFileAccess) async throws -> Bool {
        try await perform(request: authenticatedRequest(.userAccess(file: file, id: user.id), method: .delete))
    }

    public func updateTeamAccess(to file: ProxyFile, team: TeamFileAccess, right: UserPermission) async throws -> Bool {
        try await perform(request: authenticatedRequest(.teamAccess(file: file, id: team.id), method: .put,
                                                        parameters: ["right": right]))
    }

    public func removeTeamAccess(to file: ProxyFile, team: TeamFileAccess) async throws -> Bool {
        try await perform(request: authenticatedRequest(.teamAccess(file: file, id: team.id), method: .delete))
    }

    public func updateInvitationAccess(drive: AbstractDrive, invitation: ExternInvitationFileAccess,
                                       right: UserPermission) async throws -> Bool {
        try await perform(request: authenticatedRequest(.invitation(drive: drive, id: invitation.id), method: .put,
                                                        parameters: ["right": right]))
    }

    public func deleteInvitation(drive: AbstractDrive, invitation: ExternInvitationFileAccess) async throws -> Bool {
        try await perform(request: authenticatedRequest(.invitation(drive: drive, id: invitation.id), method: .delete))
    }

    public func comments(file: ProxyFile, page: Int) async throws -> [Comment] {
        try await perform(request: authenticatedRequest(.comments(file: file).paginated(page: page)))
    }

    public func addComment(to file: ProxyFile, body: String) async throws -> Comment {
        try await perform(request: authenticatedRequest(.comments(file: file), method: .post, parameters: ["body": body]))
    }

    public func likeComment(file: ProxyFile, liked: Bool, comment: Comment) async throws -> Bool {
        let endpoint: Endpoint = liked ? .unlikeComment(file: file, comment: comment) : .likeComment(file: file, comment: comment)

        return try await perform(request: authenticatedRequest(endpoint, method: .post))
    }

    public func deleteComment(file: ProxyFile, comment: Comment) async throws -> Bool {
        try await perform(request: authenticatedRequest(.comment(file: file, comment: comment), method: .delete))
    }

    public func editComment(file: ProxyFile, body: String, comment: Comment) async throws -> Bool {
        try await perform(request: authenticatedRequest(.comment(file: file, comment: comment), method: .put,
                                                        parameters: ["body": body]))
    }

    public func answerComment(file: ProxyFile, body: String, comment: Comment) async throws -> Comment {
        try await perform(request: authenticatedRequest(.comment(file: file, comment: comment), method: .post,
                                                        parameters: ["body": body]))
    }

    public func delete(file: ProxyFile) async throws -> CancelableResponse {
        try await perform(request: authenticatedRequest(.fileInfoV2(file), method: .delete))
    }

    public func emptyTrash(drive: AbstractDrive) async throws -> Bool {
        try await perform(request: authenticatedRequest(.trash(drive: drive), method: .delete))
    }

    public func deleteDefinitely(file: ProxyFile) async throws -> Bool {
        try await perform(request: authenticatedRequest(.trashedInfo(file: file), method: .delete))
    }

    public func rename(file: ProxyFile, newName: String) async throws -> CancelableResponse {
        try await perform(request: authenticatedRequest(.rename(file: file), method: .post, parameters: ["name": newName]))
    }

    public func duplicate(file: ProxyFile, duplicateName: String) async throws -> File {
        try await perform(request: authenticatedRequest(.duplicate(file: file), method: .post,
                                                        parameters: ["name": duplicateName]))
    }

    public func copy(file: ProxyFile, to destination: ProxyFile) async throws -> File {
        try await perform(request: authenticatedRequest(.copy(file: file, destination: destination), method: .post))
    }

    public func move(file: ProxyFile, to destination: ProxyFile) async throws -> CancelableResponse {
        try await perform(request: authenticatedRequest(.move(file: file, destination: destination), method: .post))
    }

    public func recentActivity(drive: AbstractDrive, cursor: String? = nil)
        async throws -> ValidServerResponse<[FileActivity]> {
        try await perform(request: authenticatedRequest(.recentActivity(drive: drive).cursored(cursor)))
    }

    public func fileActivities(file: ProxyFile, page: Int) async throws -> [FileActivity] {
        var queryItems = [URLQueryItem(name: "with", value: "user")]
        queryItems
            .append(contentsOf: FileActivityType.displayedFileActivities
                .map { URLQueryItem(name: "actions[]", value: $0.rawValue) })
        let endpoint = Endpoint.fileActivities(file: file)
            .appending(path: "", queryItems: queryItems)
            .paginated(page: page)
        return try await perform(request: authenticatedRequest(endpoint))
    }

    public func fileActivities(file: ProxyFile, from date: Date,
                               page: Int) async throws -> ValidServerResponse<[FileActivity]> {
        var queryItems = [
            FileWith.fileActivitiesWithExtra.toQueryItem(),
            URLQueryItem(name: "depth", value: "children"),
            URLQueryItem(name: "from_date", value: "\(Int(date.timeIntervalSince1970))")
        ]
        queryItems.append(contentsOf: FileActivityType.fileActivities.map { URLQueryItem(name: "actions[]", value: $0.rawValue) })
        let endpoint = Endpoint.fileActivities(file: file)
            .appending(path: "", queryItems: queryItems)
            .paginated(page: page)
        let activities: ValidServerResponse<[FileActivity]> = try await perform(request: authenticatedRequest(endpoint))
        return activities
    }

    public func filesActivities(drive: AbstractDrive, files: [ProxyFile],
                                from date: Date) async throws
        -> ValidServerResponse<[ActivitiesForFile]> {
        try await perform(request: authenticatedRequest(.filesActivities(drive: drive, fileIds: files.map(\.id), from: date)))
    }

    public func favorite(file: ProxyFile) async throws -> Bool {
        try await perform(request: authenticatedRequest(.favorite(file: file), method: .post))
    }

    public func unfavorite(file: ProxyFile) async throws -> Bool {
        try await perform(request: authenticatedRequest(.favorite(file: file), method: .delete))
    }

    public func performAuthenticatedRequest(token: ApiToken, request: @escaping (ApiToken?, Error?) -> Void) {
        accountManager.refreshTokenLockedQueue.async {
            guard token.requiresRefresh else {
                request(token, nil)
                return
            }

            self.accountManager.reloadTokensAndAccounts()
            guard let reloadedToken = self.accountManager.getTokenForUserId(token.userId) else {
                request(nil, DriveError.unknownToken)
                return
            }

            guard !reloadedToken.requiresRefresh else {
                request(reloadedToken, nil)
                return
            }

            let group = DispatchGroup()
            group.enter()
            self.tokenable.refreshToken(token: reloadedToken) { newToken, error in
                if let newToken {
                    self.accountManager.didUpdateToken(newToken: newToken, oldToken: reloadedToken)
                    request(newToken, nil)
                } else {
                    request(nil, error)
                }
                group.leave()
            }
            group.wait()
        }
    }

    // MARK: -

    public func trashedFiles(drive: AbstractDrive,
                             cursor: String? = nil,
                             sortType: SortType = .nameAZ) async throws -> ValidServerResponse<[File]> {
        try await perform(request: authenticatedRequest(.trash(drive: drive)
                .sorted(by: [sortType])
                .cursored(cursor)))
    }

    public func trashedFile(_ file: ProxyFile) async throws -> File {
        try await perform(request: authenticatedRequest(.trashedInfo(file: file)))
    }

    public func trashedFiles(of directory: ProxyFile,
                             cursor: String? = nil,
                             sortType: SortType = .nameAZ) async throws -> ValidServerResponse<[File]> {
        try await perform(request: authenticatedRequest(.trashedFiles(of: directory)
                .sorted(by: [sortType])
                .cursored(cursor)))
    }

    public func restore(file: ProxyFile, in directory: ProxyFile? = nil) async throws -> CancelableResponse {
        let parameters: Parameters?
        if let directory {
            parameters = ["destination_directory_id": directory.id]
        } else {
            parameters = nil
        }
        return try await perform(request: authenticatedRequest(.restore(file: file), method: .post, parameters: parameters))
    }

    public func searchFiles(
        drive: AbstractDrive,
        query: String? = nil,
        date: DateInterval? = nil,
        fileTypes: [ConvertedType] = [],
        categories: [Category],
        belongToAllCategories: Bool,
        cursor: String? = nil,
        sortType: SortType = .nameAZ
    ) async throws -> ValidServerResponse<[File]> {
        try await perform(request: authenticatedRequest(.search(
            drive: drive,
            query: query,
            date: date,
            fileTypes: fileTypes,
            categories: categories,
            belongToAllCategories: belongToAllCategories
        )
        .cursored(cursor)
        .sorted(by: [sortType])))
    }

    public func add(category: Category, to file: ProxyFile) async throws -> CategoryResponse {
        try await perform(request: authenticatedRequest(.fileCategory(file: file, category: category), method: .post))
    }

    public func add(drive: AbstractDrive, category: Category, to files: [ProxyFile]) async throws -> [CategoryResponse] {
        let parameters: Parameters = ["file_ids": files.map(\.id)]
        return try await perform(request: authenticatedRequest(.fileCategory(drive: drive, category: category), method: .post,
                                                               parameters: parameters))
    }

    public func remove(category: Category, from file: ProxyFile) async throws -> Bool {
        try await perform(request: authenticatedRequest(.fileCategory(file: file, category: category), method: .delete))
    }

    public func remove(drive: AbstractDrive, category: Category, from files: [ProxyFile]) async throws -> [CategoryResponse] {
        let parameters: Parameters = ["file_ids": files.map(\.id)]
        return try await perform(request: authenticatedRequest(.fileCategory(drive: drive, category: category), method: .delete,
                                                               parameters: parameters))
    }

    public func createCategory(drive: AbstractDrive, name: String, color: String) async throws -> Category {
        try await perform(request: authenticatedRequest(.categories(drive: drive), method: .post,
                                                        parameters: ["name": name, "color": color]))
    }

    public func editCategory(drive: AbstractDrive, category: Category, name: String?, color: String) async throws -> Category {
        var body = ["color": color]
        if let name {
            body["name"] = name
        }

        return try await perform(request: authenticatedRequest(.category(drive: drive, category: category), method: .put,
                                                               parameters: body))
    }

    public func deleteCategory(drive: AbstractDrive, category: Category) async throws -> Bool {
        try await perform(request: authenticatedRequest(.category(drive: drive, category: category), method: .delete))
    }

    @discardableResult
    public func undoAction(drive: AbstractDrive, cancelId: String) async throws -> Empty {
        try await perform(request: authenticatedRequest(.undoAction(drive: drive), method: .post,
                                                        parameters: ["cancel_id": cancelId]))
    }

    public func convert(file: ProxyFile) async throws -> File {
        try await perform(request: authenticatedRequest(.convert(file: file), method: .post))
    }

    public func bulkAction(drive: AbstractDrive, action: BulkAction) async throws -> CancelableResponse {
        try await perform(request: authenticatedRequest(.bulkFiles(drive: drive), method: .post, parameters: action))
    }

    public func count(of directory: ProxyFile) async throws -> FileCount {
        try await perform(request: authenticatedRequest(.count(of: directory)))
    }

    public func buildArchive(drive: AbstractDrive, body: ArchiveBody) async throws -> DownloadArchiveResponse {
        try await perform(request: authenticatedRequest(.buildArchive(drive: drive), method: .post, parameters: body))
    }

    public func updateColor(directory: ProxyFile, color: String) async throws -> Bool {
        try await perform(request: authenticatedRequest(.directoryColor(file: directory), method: .post,
                                                        parameters: ["color": color]))
    }

    public func cancelImport(drive: AbstractDrive, id: Int) async throws -> Bool {
        try await perform(request: authenticatedRequest(.cancelImport(drive: drive, id: id), method: .put))
    }

    public func file(_ file: AbstractFile) async throws -> File {
        try await perform(request: authenticatedRequest(.file(file)))
    }
}

class SyncedAuthenticator: OAuthAuthenticator {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var tokenable: InfomaniakTokenable
    @LazyInjectService var appContextService: AppContextServiceable
    @LazyInjectService var keychainHelper: KeychainHelper

    override func refresh(
        _ credential: OAuthAuthenticator.Credential,
        for session: Session,
        completion: @escaping (Result<OAuthAuthenticator.Credential, Error>) -> Void
    ) {
        // Only resolve locally to break init loop
        accountManager.refreshTokenLockedQueue.async {
            let message = "Refreshing token - Starting"
            let metadata = (credential as ApiToken).breadcrumbMetadata()
            SentryDebug.addBreadcrumb(message: message, category: .apiToken, level: .info, metadata: metadata)

            if !self.keychainHelper.isKeychainAccessible {
                let message = "Refreshing token failed - Keychain unaccessible"
                SentryDebug.addBreadcrumb(message: message, category: .apiToken, level: .error, metadata: metadata)

                completion(.failure(DriveError.refreshToken))
                return
            }

            if let storedToken = self.accountManager.getTokenForUserId(credential.userId) {
                // Someone else refreshed our token and we already have an infinite token
                if storedToken.expirationDate == nil && credential.expirationDate != nil {
                    let message = "Refreshing token - Success with local (infinite)"
                    SentryDebug.addBreadcrumb(message: message, category: .apiToken, level: .info, metadata: metadata)
                    completion(.success(storedToken))
                    return
                }
                // Someone else refreshed our token and we don't have an infinite token
                if let storedTokenExpirationDate = storedToken.expirationDate,
                   let tokenExpirationDate = credential.expirationDate,
                   tokenExpirationDate > storedTokenExpirationDate {
                    let message = "Refreshing token - Success with local"
                    SentryDebug.addBreadcrumb(message: message, category: .apiToken, level: .info, metadata: metadata)
                    completion(.success(storedToken))
                    return
                }
            }

            let group = DispatchGroup()
            group.enter()
            var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
            if !self.appContextService.isExtension {
                // It is absolutely necessary that the app stays awake while we refresh the token
                taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "Refresh token") {
                    let message = "Refreshing token failed - Background task expired"
                    SentryDebug.addBreadcrumb(message: message, category: .apiToken, level: .error, metadata: metadata)

                    // If we didn't fetch the new token in the given time there is not much we can do apart from hoping that it
                    // wasn't revoked
                    if taskIdentifier != .invalid {
                        UIApplication.shared.endBackgroundTask(taskIdentifier)
                        taskIdentifier = .invalid
                    }
                }

                if taskIdentifier == .invalid {
                    // We couldn't request additional time to refresh token maybe try later...
                    completion(.failure(DriveError.refreshToken))
                    return
                }
            }
            self.tokenable.refreshToken(token: credential) { token, error in
                // New token has been fetched correctly
                if let token {
                    let message = "Refreshing token - Success with remote"
                    SentryDebug.addBreadcrumb(message: message, category: .apiToken, level: .info, metadata: metadata)

                    self.refreshTokenDelegate?.didUpdateToken(newToken: token, oldToken: credential)
                    completion(.success(token))
                } else {
                    // Couldn't refresh the token, API says it's invalid
                    if let error = error as NSError?, error.domain == "invalid_grant" {
                        let message = "Refreshing token failed - Invalid grant"
                        SentryDebug.addBreadcrumb(message: message, category: .apiToken, level: .error, metadata: metadata)

                        self.refreshTokenDelegate?.didFailRefreshToken(credential)
                        completion(.failure(error))
                    } else {
                        // Couldn't refresh the token, keep the old token and fetch it later. Maybe because of bad network ?
                        let message = "Refreshing token failed - Other \(error.debugDescription)"
                        SentryDebug.addBreadcrumb(message: message, category: .apiToken, level: .error, metadata: metadata)

                        completion(.success(credential))
                    }
                }
                if taskIdentifier != .invalid {
                    UIApplication.shared.endBackgroundTask(taskIdentifier)
                    taskIdentifier = .invalid
                }
                group.leave()
            }
            group.wait()
        }
    }
}

class NetworkRequestRetrier: RequestInterceptor {
    let maxRetry: Int
    private var retriedRequests: [String: Int] = [:]
    let timeout = -1001
    let connectionLost = -1005

    init(maxRetry: Int = 3) {
        self.maxRetry = maxRetry
    }

    func retry(_ request: Alamofire.Request,
               for session: Session,
               dueTo error: Error,
               completion: @escaping (RetryResult) -> Void) {
        guard request.task?.response == nil,
              let url = request.request?.url?.absoluteString else {
            removeCachedUrlRequest(url: request.request?.url?.absoluteString)
            completion(.doNotRetry)
            return
        }

        let errorGenerated = error as NSError
        switch errorGenerated.code {
        case timeout, connectionLost:
            guard let retryCount = retriedRequests[url] else {
                retriedRequests[url] = 1
                completion(.retryWithDelay(0.5))
                return
            }

            if retryCount < maxRetry {
                retriedRequests[url] = retryCount + 1
                completion(.retryWithDelay(0.5))
            } else {
                removeCachedUrlRequest(url: url)
                completion(.doNotRetry)
            }

        default:
            removeCachedUrlRequest(url: url)
            completion(.doNotRetry)
        }
    }

    private func removeCachedUrlRequest(url: String?) {
        guard let url else {
            return
        }

        retriedRequests.removeValue(forKey: url)
    }
}
