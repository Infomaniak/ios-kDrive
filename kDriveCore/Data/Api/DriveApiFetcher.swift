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
import InfomaniakLogin
import Kingfisher
import Sentry
import UIKit

extension ApiFetcher {
    public convenience init(token: ApiToken, delegate: RefreshTokenDelegate) {
        self.init()
        setToken(token, authenticator: SyncedAuthenticator(refreshTokenDelegate: delegate))
    }

    // MARK: - User methods

    func userProfile() async throws -> UserProfile {
        try await perform(request: authenticatedSession.request("\(apiURL)profile?with=avatar,phones,emails")).data
    }

    func userDrives() async throws -> DriveResponse {
        try await perform(request: authenticatedRequest(.initData)).data
    }

    // MARK: - New request helpers

    func authenticatedRequest(_ endpoint: Endpoint, method: HTTPMethod = .get, parameters: Parameters? = nil) -> DataRequest {
        return authenticatedSession
            .request(endpoint.url, method: method, parameters: parameters, encoding: JSONEncoding.default)
    }

    func authenticatedRequest<Parameters: Encodable>(_ endpoint: Endpoint, method: HTTPMethod = .get, parameters: Parameters? = nil) -> DataRequest {
        return authenticatedSession
            .request(endpoint.url, method: method, parameters: parameters, encoder: JSONParameterEncoder.convertToSnakeCase)
    }

    func perform<T: Decodable>(request: DataRequest) async throws -> (data: T, responseAt: Int?) {
        let response = await request.serializingDecodable(ApiResponse<T>.self, automaticallyCancelling: true, decoder: ApiFetcher.decoder).response
        let json = try response.result.get()
        if let result = json.data {
            return (result, json.responseAt)
        } else if let apiError = json.error {
            throw DriveError(apiError: apiError)
        } else {
            throw DriveError.serverError(statusCode: response.response?.statusCode ?? -1)
        }
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
    public static let clientId = "9473D73C-C20F-4971-9E10-D957C563FA68"
    public var authenticatedKF: AuthenticatedImageRequestModifier!

    override public init() {
        super.init()
        authenticatedKF = AuthenticatedImageRequestModifier(apiFetcher: self)
    }

    // MARK: - API methods

    public func createDirectory(in parentDirectory: File, name: String, onlyForMe: Bool) async throws -> File {
        try await perform(request: authenticatedRequest(.createDirectory(in: parentDirectory), method: .post, parameters: ["name": name, "only_for_me": onlyForMe])).data
    }

    public func createCommonDirectory(drive: AbstractDrive, name: String, forAllUser: Bool) async throws -> File {
        try await perform(request: authenticatedRequest(.createTeamDirectory(drive: drive), method: .post, parameters: ["name": name, "for_all_user": forAllUser])).data
    }

    public func createFile(in parentDirectory: File, name: String, type: String) async throws -> File {
        try await perform(request: authenticatedRequest(.createFile(in: parentDirectory), method: .post, parameters: ["name": name, "type": type])).data
    }

    public func createDropBox(directory: File, settings: DropBoxSettings) async throws -> DropBox {
        try await perform(request: authenticatedRequest(.dropbox(file: directory), method: .post, parameters: settings)).data
    }

    public func getDropBox(directory: File) async throws -> DropBox {
        try await perform(request: authenticatedRequest(.dropbox(file: directory))).data
    }

    public func updateDropBox(directory: File, settings: DropBoxSettings) async throws -> Bool {
        try await perform(request: authenticatedRequest(.dropbox(file: directory), method: .put, parameters: settings)).data
    }

    public func deleteDropBox(directory: File) async throws -> Bool {
        try await perform(request: authenticatedRequest(.dropbox(file: directory), method: .delete)).data
    }

    public func rootFiles(drive: AbstractDrive, page: Int = 1, sortType: SortType = .nameAZ) async throws -> (data: [File], responseAt: Int?) {
        try await perform(request: authenticatedRequest(.rootFiles(drive: drive).paginated(page: page).sorted(by: [.type, sortType])))
    }

    public func files(in directory: File, page: Int = 1, sortType: SortType = .nameAZ) async throws -> (data: [File], responseAt: Int?) {
        try await perform(request: authenticatedRequest(.files(of: directory).paginated(page: page).sorted(by: [.type, sortType])))
    }

    public func fileInfo(_ file: AbstractFile) async throws -> (data: File, responseAt: Int?) {
        try await perform(request: authenticatedRequest(.fileInfo(file)))
    }

    public func favorites(drive: AbstractDrive, page: Int = 1, sortType: SortType = .nameAZ) async throws -> [File] {
        try await perform(request: authenticatedRequest(.favorites(drive: drive).paginated(page: page).sorted(by: [.type, sortType]))).data
    }

    public func mySharedFiles(drive: AbstractDrive, page: Int = 1, sortType: SortType = .nameAZ) async throws -> [File] {
        try await perform(request: authenticatedRequest(.mySharedFiles(drive: drive).paginated(page: page).sorted(by: [.type, sortType]))).data
    }

    public func lastModifiedFiles(drive: AbstractDrive, page: Int = 1) async throws -> [File] {
        try await perform(request: authenticatedRequest(.lastModifiedFiles(drive: drive).paginated(page: page))).data
    }

    public func shareLink(for file: File) async throws -> ShareLink {
        try await perform(request: authenticatedRequest(.shareLink(file: file))).data
    }

    public func createShareLink(for file: File) async throws -> ShareLink {
        try await perform(request: authenticatedRequest(.shareLink(file: file), method: .post, parameters: ShareLinkSettings(right: .public))).data
    }

    public func updateShareLink(for file: File, settings: ShareLinkSettings) async throws -> Bool {
        try await perform(request: authenticatedRequest(.shareLink(file: file), method: .put, parameters: settings)).data
    }

    public func removeShareLink(for file: File) async throws -> Bool {
        try await perform(request: authenticatedRequest(.shareLink(file: file), method: .delete)).data
    }

    public func access(for file: File) async throws -> FileAccess {
        try await perform(request: authenticatedRequest(.access(file: file))).data
    }

    public func checkAccessChange(to file: File, settings: FileAccessSettings) async throws -> [CheckChangeAccessFeedbackResource] {
        try await perform(request: authenticatedRequest(.checkAccess(file: file), method: .post, parameters: settings)).data
    }

    public func addAccess(to file: File, settings: FileAccessSettings) async throws -> AccessResponse {
        try await perform(request: authenticatedRequest(.access(file: file), method: .post, parameters: settings)).data
    }

    public func forceAccess(to file: File) async throws -> Bool {
        try await perform(request: authenticatedRequest(.forceAccess(file: file), method: .post)).data
    }

    public func updateUserAccess(to file: File, user: UserFileAccess, right: UserPermission) async throws -> Bool {
        try await perform(request: authenticatedRequest(.userAccess(file: file, id: user.id), method: .put, parameters: ["right": right])).data
    }

    public func removeUserAccess(to file: File, user: UserFileAccess) async throws -> Bool {
        try await perform(request: authenticatedRequest(.userAccess(file: file, id: user.id), method: .delete)).data
    }

    public func updateTeamAccess(to file: File, team: TeamFileAccess, right: UserPermission) async throws -> Bool {
        try await perform(request: authenticatedRequest(.teamAccess(file: file, id: team.id), method: .put, parameters: ["right": right])).data
    }

    public func removeTeamAccess(to file: File, team: TeamFileAccess) async throws -> Bool {
        try await perform(request: authenticatedRequest(.teamAccess(file: file, id: team.id), method: .delete)).data
    }

    public func updateInvitationAccess(drive: AbstractDrive, invitation: ExternInvitationFileAccess, right: UserPermission) async throws -> Bool {
        try await perform(request: authenticatedRequest(.invitation(drive: drive, id: invitation.id), method: .put, parameters: ["right": right])).data
    }

    public func deleteInvitation(drive: AbstractDrive, invitation: ExternInvitationFileAccess) async throws -> Bool {
        try await perform(request: authenticatedRequest(.invitation(drive: drive, id: invitation.id), method: .delete)).data
    }

    public func comments(file: File, page: Int) async throws -> [Comment] {
        try await perform(request: authenticatedRequest(.comments(file: file).paginated(page: page))).data
    }

    public func addComment(to file: File, body: String) async throws -> Comment {
        try await perform(request: authenticatedRequest(.comments(file: file), method: .post, parameters: ["body": body])).data
    }

    public func likeComment(file: File, liked: Bool, comment: Comment) async throws -> Bool {
        let endpoint: Endpoint = liked ? .unlikeComment(file: file, comment: comment) : .likeComment(file: file, comment: comment)

        return try await perform(request: authenticatedRequest(endpoint, method: .post)).data
    }

    public func deleteComment(file: File, comment: Comment) async throws -> Bool {
        try await perform(request: authenticatedRequest(.comment(file: file, comment: comment), method: .delete)).data
    }

    public func editComment(file: File, body: String, comment: Comment) async throws -> Bool {
        try await perform(request: authenticatedRequest(.comment(file: file, comment: comment), method: .put, parameters: ["body": body])).data
    }

    public func answerComment(file: File, body: String, comment: Comment) async throws -> Comment {
        try await perform(request: authenticatedRequest(.comment(file: file, comment: comment), method: .post, parameters: ["body": body])).data
    }

    public func delete(file: File) async throws -> CancelableResponse {
        try await perform(request: authenticatedRequest(.fileInfo(file), method: .delete)).data
    }

    public func emptyTrash(drive: AbstractDrive) async throws -> Bool {
        try await perform(request: authenticatedRequest(.trash(drive: drive), method: .delete)).data
    }

    public func deleteDefinitely(file: AbstractFile) async throws -> Bool {
        try await perform(request: authenticatedRequest(.trashedInfo(file: file), method: .delete)).data
    }

    public func rename(file: File, newName: String) async throws -> CancelableResponse {
        try await perform(request: authenticatedRequest(.rename(file: file), method: .post, parameters: ["name": newName])).data
    }

    public func duplicate(file: File, duplicateName: String) async throws -> File {
        try await perform(request: authenticatedRequest(.duplicate(file: file), method: .post, parameters: ["name": duplicateName])).data
    }

    public func copy(file: File, to destination: File) async throws -> File {
        try await perform(request: authenticatedRequest(.copy(file: file, destination: destination), method: .post)).data
    }

    public func move(file: File, to destination: File) async throws -> CancelableResponse {
        try await perform(request: authenticatedRequest(.move(file: file, destination: destination), method: .post)).data
    }

    public func recentActivity(drive: AbstractDrive, page: Int = 1) async throws -> [FileActivity] {
        try await perform(request: authenticatedRequest(.recentActivity(drive: drive).paginated(page: page))).data
    }

    public func fileActivities(file: File, page: Int) async throws -> [FileActivity] {
        let endpoint = Endpoint.fileActivities(file: file)
            .appending(path: "", queryItems: [URLQueryItem(name: "with", value: "user")])
            .paginated(page: page)
        return try await perform(request: authenticatedRequest(endpoint)).data
    }

    public func fileActivities(file: File, from date: Date, page: Int) async throws -> (data: [FileActivity], responseAt: Int?) {
        var queryItems = [
            Endpoint.fileActivitiesWithQueryItem,
            URLQueryItem(name: "depth", value: "children"),
            URLQueryItem(name: "from_date", value: "\(Int(date.timeIntervalSince1970))")
        ]
        queryItems.append(contentsOf: FileActivityType.fileActivities.map { URLQueryItem(name: "actions[]", value: $0.rawValue) })
        let endpoint = Endpoint.fileActivities(file: file)
            .appending(path: "", queryItems: queryItems)
            .paginated(page: page)
        return try await perform(request: authenticatedRequest(endpoint))
    }

    public func filesActivities(drive: AbstractDrive, files: [File], from date: Date) async throws -> (data: [ActivitiesForFile], responseAt: Int?) {
        try await perform(request: authenticatedRequest(.filesActivities(drive: drive, fileIds: files.map(\.id), from: date)))
    }

    public func favorite(file: File) async throws -> Bool {
        try await perform(request: authenticatedRequest(.favorite(file: file), method: .post)).data
    }

    public func unfavorite(file: File) async throws -> Bool {
        try await perform(request: authenticatedRequest(.favorite(file: file), method: .delete)).data
    }

    public func performAuthenticatedRequest(token: ApiToken, request: @escaping (ApiToken?, Error?) -> Void) {
        AccountManager.instance.refreshTokenLockedQueue.async {
            if token.requiresRefresh {
                AccountManager.instance.reloadTokensAndAccounts()
                if let reloadedToken = AccountManager.instance.getTokenForUserId(token.userId) {
                    if reloadedToken.requiresRefresh {
                        let group = DispatchGroup()
                        group.enter()
                        InfomaniakLogin.refreshToken(token: reloadedToken) { newToken, error in
                            if let newToken = newToken {
                                AccountManager.instance.updateToken(newToken: newToken, oldToken: reloadedToken)
                                request(newToken, nil)
                            } else {
                                request(nil, error)
                            }
                            group.leave()
                        }
                        group.wait()
                    } else {
                        request(reloadedToken, nil)
                    }
                } else {
                    request(nil, DriveError.unknownToken)
                }
            } else {
                request(token, nil)
            }
        }
    }

    public func getPublicUploadToken(with token: ApiToken, drive: AbstractDrive, completion: @escaping (Result<UploadToken, Error>) -> Void) {
        let url = Endpoint.uploadToken(drive: drive).url
        performAuthenticatedRequest(token: token) { token, error in
            if let token = token {
                Task {
                    do {
                        let token: UploadToken = try await self.perform(request: AF.request(url, method: .get, headers: ["Authorization": "Bearer \(token.accessToken)"])).data
                        completion(.success(token))
                    } catch {
                        completion(.failure(error))
                    }
                }
            } else {
                completion(.failure(error ?? DriveError.unknownError))
            }
        }
    }

    public func trashedFiles(drive: AbstractDrive, page: Int = 1, sortType: SortType = .nameAZ) async throws -> [File] {
        try await perform(request: authenticatedRequest(.trash(drive: drive).paginated(page: page).sorted(by: [sortType]))).data
    }

    public func trashedFile(_ file: AbstractFile) async throws -> File {
        try await perform(request: authenticatedRequest(.trashedInfo(file: file))).data
    }

    public func trashedFiles(of directory: File, page: Int = 1, sortType: SortType = .nameAZ) async throws -> [File] {
        try await perform(request: authenticatedRequest(.trashedFiles(of: directory).paginated(page: page).sorted(by: [sortType]))).data
    }

    public func restore(file: AbstractFile, in directory: AbstractFile? = nil) async throws -> CancelableResponse {
        let parameters: Parameters?
        if let directory = directory {
            parameters = ["destination_directory_id": directory.id]
        } else {
            parameters = nil
        }
        return try await perform(request: authenticatedRequest(.restore(file: file), method: .post, parameters: parameters)).data
    }

    public func searchFiles(drive: AbstractDrive, query: String? = nil, date: DateInterval? = nil, fileType: ConvertedType? = nil, categories: [Category], belongToAllCategories: Bool, page: Int = 1, sortType: SortType = .nameAZ) async throws -> [File] {
        try await perform(request: authenticatedRequest(.search(drive: drive, query: query, date: date, fileType: fileType, categories: categories, belongToAllCategories: belongToAllCategories).paginated(page: page).sorted(by: [.type, sortType]))).data
    }

    public func add(category: Category, to file: File) async throws -> Bool {
        try await perform(request: authenticatedRequest(.fileCategory(file: file, category: category), method: .post)).data
    }

    public func remove(category: Category, from file: File) async throws -> Bool {
        try await perform(request: authenticatedRequest(.fileCategory(file: file, category: category), method: .delete)).data
    }

    public func createCategory(drive: AbstractDrive, name: String, color: String) async throws -> Category {
        try await perform(request: authenticatedRequest(.categories(drive: drive), method: .post, parameters: ["name": name, "color": color])).data
    }

    public func editCategory(drive: AbstractDrive, category: Category, name: String?, color: String) async throws -> Category {
        var body = ["color": color]
        if let name = name {
            body["name"] = name
        }

        return try await perform(request: authenticatedRequest(.category(drive: drive, category: category), method: .put, parameters: body)).data
    }

    public func deleteCategory(drive: AbstractDrive, category: Category) async throws -> Bool {
        try await perform(request: authenticatedRequest(.category(drive: drive, category: category), method: .delete)).data
    }

    @discardableResult
    public func undoAction(drive: AbstractDrive, cancelId: String) async throws -> EmptyResponse {
        try await perform(request: authenticatedRequest(.undoAction(drive: drive), method: .post, parameters: ["cancel_id": cancelId])).data
    }

    public func convert(file: File) async throws -> File {
        try await perform(request: authenticatedRequest(.convert(file: file), method: .post)).data
    }

    public func bulkAction(drive: AbstractDrive, action: BulkAction) async throws -> CancelableResponse {
        try await perform(request: authenticatedRequest(.bulkFiles(drive: drive), method: .post, parameters: action)).data
    }

    public func count(of file: AbstractFile) async throws -> FileCount {
        try await perform(request: authenticatedRequest(.count(of: file))).data
    }

    public func buildArchive(drive: AbstractDrive, for files: [File]) async throws -> DownloadArchiveResponse {
        try await perform(request: authenticatedRequest(.buildArchive(drive: drive), method: .post, parameters: ["file_ids": files.map(\.id)])).data
    }

    public func updateColor(directory: File, color: String) async throws -> Bool {
        try await perform(request: authenticatedRequest(.directoryColor(file: directory), method: .post, parameters: ["color": color])).data
    }
}

class SyncedAuthenticator: OAuthAuthenticator {
    override func refresh(_ credential: OAuthAuthenticator.Credential, for session: Session, completion: @escaping (Result<OAuthAuthenticator.Credential, Error>) -> Void) {
        AccountManager.instance.refreshTokenLockedQueue.async {
            SentrySDK.addBreadcrumb(crumb: (credential as ApiToken).generateBreadcrumb(level: .info, message: "Refreshing token - Starting"))

            if !KeychainHelper.isKeychainAccessible {
                SentrySDK.addBreadcrumb(crumb: (credential as ApiToken).generateBreadcrumb(level: .error, message: "Refreshing token failed - Keychain unaccessible"))

                completion(.failure(DriveError.refreshToken))
                return
            }

            // Maybe someone else refreshed our token
            AccountManager.instance.reloadTokensAndAccounts()
            if let token = AccountManager.instance.getTokenForUserId(credential.userId),
               token.expirationDate > credential.expirationDate {
                SentrySDK.addBreadcrumb(crumb: token.generateBreadcrumb(level: .info, message: "Refreshing token - Success with local"))
                completion(.success(token))
                return
            }

            let group = DispatchGroup()
            group.enter()
            var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
            if !Constants.isInExtension {
                // It is absolutely necessary that the app stays awake while we refresh the token
                taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "Refresh token") {
                    SentrySDK.addBreadcrumb(crumb: (credential as ApiToken).generateBreadcrumb(level: .error, message: "Refreshing token failed - Background task expired"))
                    // If we didn't fetch the new token in the given time there is not much we can do apart from hoping that it wasn't revoked
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
            InfomaniakLogin.refreshToken(token: credential) { token, error in
                // New token has been fetched correctly
                if let token = token {
                    SentrySDK.addBreadcrumb(crumb: token.generateBreadcrumb(level: .info, message: "Refreshing token - Success with remote"))
                    self.refreshTokenDelegate?.didUpdateToken(newToken: token, oldToken: credential)
                    completion(.success(token))
                } else {
                    // Couldn't refresh the token, API says it's invalid
                    if let error = error as NSError?, error.domain == "invalid_grant" {
                        SentrySDK.addBreadcrumb(crumb: (credential as ApiToken).generateBreadcrumb(level: .error, message: "Refreshing token failed - Invalid grant"))
                        self.refreshTokenDelegate?.didFailRefreshToken(credential)
                        completion(.failure(error))
                    } else {
                        // Couldn't refresh the token, keep the old token and fetch it later. Maybe because of bad network ?
                        SentrySDK.addBreadcrumb(crumb: (credential as ApiToken).generateBreadcrumb(level: .error, message: "Refreshing token failed - Other \(error.debugDescription)"))
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
    let timeout = -1_001
    let connectionLost = -1_005

    init(maxRetry: Int = 3) {
        self.maxRetry = maxRetry
    }

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
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
        guard let url = url else {
            return
        }
        retriedRequests.removeValue(forKey: url)
    }
}
