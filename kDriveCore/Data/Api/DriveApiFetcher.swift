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
    convenience init(token: ApiToken, delegate: RefreshTokenDelegate) {
        self.init()
        setToken(token, authenticator: SyncedAuthenticator(refreshTokenDelegate: delegate))
    }

    public func getUserDrives(completion: @escaping (ApiResponse<DriveResponse>?, Error?) -> Void) {
        authenticatedSession.request(ApiRoutes.getAllDrivesData(), method: .get)
            .validate()
            .responseDecodable(of: ApiResponse<DriveResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response) { response, error in
                    if let driveResponse = response?.data,
                       driveResponse.drives.main.isEmpty {
                        completion(nil, DriveError.noDrive)
                    } else {
                        completion(response, error)
                    }
                }
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
    public static let itemPerPage = 200
    public var authenticatedKF: AuthenticatedImageRequestModifier!

    override public init() {
        super.init()
        authenticatedKF = AuthenticatedImageRequestModifier(apiFetcher: self)
    }

    override public func handleResponse<Type>(response: DataResponse<Type, AFError>, completion: @escaping (Type?, Error?) -> Void) {
        super.handleResponse(response: response) { res, error in
            if let error = error as? InfomaniakCore.ApiError {
                completion(res, DriveError(apiError: error))
            } else {
                completion(res, error)
            }
        }
    }

    private func pagination(page: Int) -> String {
        return "&page=\(page)&per_page=\(DriveApiFetcher.itemPerPage)"
    }

    public func createDirectory(parentDirectory: File, name: String, onlyForMe: Bool, completion: @escaping (ApiResponse<File>?, Error?) -> Void) {
        let url = ApiRoutes.createDirectory(driveId: parentDirectory.driveId, parentId: parentDirectory.id)
        let body: [String: Any] = [
            "name": name,
            "only_for_me": onlyForMe,
            "share": false
        ]

        authenticatedSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
            .validate()
            .responseDecodable(of: ApiResponse<File>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func createCommonDirectory(driveId: Int, name: String, forAllUser: Bool, completion: @escaping (ApiResponse<File>?, Error?) -> Void) {
        let url = ApiRoutes.createCommonDirectory(driveId: driveId)
        let body: [String: Any] = [
            "name": name,
            "for_all_user": forAllUser
        ]

        authenticatedSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
            .validate()
            .responseDecodable(of: ApiResponse<File>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func createOfficeFile(driveId: Int, parentDirectory: File, name: String, type: String, completion: @escaping (ApiResponse<File>?, Error?) -> Void) {
        let url = ApiRoutes.createOfficeFile(driveId: driveId, parentId: parentDirectory.id)
        let body: [String: Any] = [
            "name": name,
            "type": type
        ]

        authenticatedSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
            .validate()
            .responseDecodable(of: ApiResponse<File>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func setupDropBox(directory: File,
                             password: String?,
                             validUntil: Date?,
                             emailWhenFinished: Bool,
                             limitFileSize: Int?,
                             completion: @escaping (ApiResponse<DropBox>?, Error?) -> Void) {
        let url = ApiRoutes.setupDropBox(directory: directory)
        var sizeLimit: Int?
        if let limitFileSize = limitFileSize {
            let size = Double(limitFileSize) * pow(Double(1024), Double(3))
            sizeLimit = Int(size)
        }
        var body: [String: Any] = [
            "password": password ?? "",
            "email_when_finished": emailWhenFinished,
            "limit_file_size": sizeLimit ?? ""
        ]
        if let validUntil = validUntil?.timeIntervalSince1970 {
            body.updateValue(Int(validUntil), forKey: "valid_until")
        }

        authenticatedSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
            .responseDecodable(of: ApiResponse<DropBox>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getDropBoxSettings(directory: File, completion: @escaping (ApiResponse<DropBox>?, Error?) -> Void) {
        let url = ApiRoutes.setupDropBox(directory: directory)

        authenticatedSession.request(url, method: .get)
            .responseDecodable(of: ApiResponse<DropBox>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func updateDropBox(directory: File,
                              password: String?,
                              validUntil: Date?,
                              emailWhenFinished: Bool,
                              limitFileSize: Int?,
                              completion: @escaping (ApiResponse<EmptyResponse>?, Error?) -> Void) {
        let url = ApiRoutes.setupDropBox(directory: directory)
        var sizeLimit: Int?
        if let limitFileSize = limitFileSize {
            let size = Double(limitFileSize) * pow(Double(1024), Double(3))
            sizeLimit = Int(size)
        }
        var timestamp: Int?
        if let validUntil = validUntil?.timeIntervalSince1970 {
            timestamp = Int(validUntil)
        }
        var body: [String: Any] = ["email_when_finished": emailWhenFinished, "limit_file_size": sizeLimit ?? "", "valid_until": timestamp ?? ""]
        if let password = password {
            body["password"] = password
        }

        authenticatedSession.request(url, method: .put, parameters: body, encoding: JSONEncoding.default)
            .responseDecodable(of: ApiResponse<EmptyResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func disableDropBox(directory: File, completion: @escaping (ApiResponse<EmptyResponse>?, Error?) -> Void) {
        let url = ApiRoutes.setupDropBox(directory: directory)

        authenticatedSession.request(url, method: .delete)
            .responseDecodable(of: ApiResponse<EmptyResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getFileListForDirectory(driveId: Int, parentId: Int, page: Int = 1, sortType: SortType = .nameAZ, completion: @escaping (ApiResponse<File>?, Error?) -> Void) {
        let url = "\(ApiRoutes.getFileListForDirectory(driveId: driveId, parentId: parentId, sortType: sortType))\(pagination(page: page))"

        authenticatedSession.request(url, method: .get)
            .validate()
            .responseDecodable(of: ApiResponse<File>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getFavoriteFiles(driveId: Int, page: Int = 1, sortType: SortType = .nameAZ, completion: @escaping (ApiResponse<[File]>?, Error?) -> Void) {
        let url = "\(ApiRoutes.getFavoriteFiles(driveId: driveId, sortType: sortType))\(pagination(page: page))"

        authenticatedSession.request(url, method: .get)
            .responseDecodable(of: ApiResponse<[File]>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getMyShared(driveId: Int, page: Int = 1, sortType: SortType = .nameAZ, completion: @escaping (ApiResponse<[File]>?, Error?) -> Void) {
        let url = "\(ApiRoutes.getMyShared(driveId: driveId, sortType: sortType))\(pagination(page: page))"

        authenticatedSession.request(url, method: .get).responseDecodable(of: ApiResponse<[File]>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func getLastModifiedFiles(driveId: Int, page: Int? = nil, completion: @escaping (ApiResponse<[File]>?, Error?) -> Void) {
        var url = ApiRoutes.getLastModifiedFiles(driveId: driveId)
        if let page = page {
            url += pagination(page: page)
        }

        authenticatedSession.request(url, method: .get)
            .responseDecodable(of: ApiResponse<[File]>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getLastPictures(driveId: Int, page: Int = 1, completion: @escaping (ApiResponse<[File]>?, Error?) -> Void) {
        let url = ApiRoutes.getLastPictures(driveId: driveId) + pagination(page: page)

        authenticatedSession.request(url, method: .get)
            .responseDecodable(of: ApiResponse<[File]>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getShareListFor(file: File, completion: @escaping (ApiResponse<SharedFile>?, Error?) -> Void) {
        let url = ApiRoutes.getShareListFor(file: file)

        authenticatedSession.request(url, method: .get).responseDecodable(of: ApiResponse<SharedFile>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func activateShareLinkFor(file: File, completion: @escaping (ApiResponse<ShareLink>?, Error?) -> Void) {
        let url = ApiRoutes.activateShareLinkFor(file: file)

        authenticatedSession.request(url, method: .post)
            .validate()
            .responseDecodable(of: ApiResponse<ShareLink>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    // swiftlint:disable function_parameter_count
    public func updateShareLinkWith(file: File, canEdit: Bool, permission: String, password: String? = "", date: TimeInterval?, blockDownloads: Bool, blockComments: Bool, blockInformation: Bool, isFree: Bool, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = ApiRoutes.updateShareLinkWith(file: file)

        var body: [String: Any]
        if isFree {
            body = ["can_edit": canEdit, "permission": permission, "block_comments": blockComments, "block_downloads": blockDownloads, "block_information": blockInformation]
        } else {
            body = ["can_edit": canEdit, "permission": permission, "block_comments": blockComments, "block_downloads": blockDownloads, "block_information": blockInformation, "valid_until": date as Any]
        }
        if permission == "password" {
            body.updateValue(password!, forKey: "password")
        }

        authenticatedSession.request(url, method: .put, parameters: body, encoding: JSONEncoding.default).responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func addUserRights(file: File, users: [Int], tags: [Int], emails: [String], message: String, permission: String, completion: @escaping (ApiResponse<SharedUsers>?, Error?) -> Void) {
        let url = ApiRoutes.addUserRights(file: file)
        let body: [String: Any] = ["user_ids": users, "tag_ids": tags, "emails": emails, "permission": permission, "lang": "fr", "message": message]

        authenticatedSession.request(url, method: .post, parameters: body).responseDecodable(of: ApiResponse<SharedUsers>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func checkUserRights(file: File, users: [Int], tags: [Int], emails: [String], permission: String, completion: @escaping (ApiResponse<[FileCheckResult]>?, Error?) -> Void) {
        let url = ApiRoutes.checkUserRights(file: file)
        let body: [String: Any] = ["user_ids": users, "tag_ids": tags, "emails": emails, "permission": permission]

        authenticatedSession.request(url, method: .post, parameters: body).responseDecodable(of: ApiResponse<[FileCheckResult]>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func updateUserRights(file: File, user: DriveUser, permission: String, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = ApiRoutes.updateUserRights(file: file, user: user)
        let body: [String: Any] = ["permission": permission]

        authenticatedSession.request(url, method: .put, parameters: body).responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func deleteUserRights(file: File, user: DriveUser, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = ApiRoutes.updateUserRights(file: file, user: user)

        authenticatedSession.request(url, method: .delete).responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func updateInvitationRights(driveId: Int, invitation: Invitation, permission: String, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = ApiRoutes.updateInvitationRights(driveId: driveId, invitation: invitation)
        let body: [String: Any] = ["permission": permission]

        authenticatedSession.request(url, method: .put, parameters: body).responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func deleteInvitationRights(driveId: Int, invitation: Invitation, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = ApiRoutes.deleteInvitationRights(driveId: driveId, invitation: invitation)

        authenticatedSession.request(url, method: .delete).responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func removeShareLinkFor(file: File, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = ApiRoutes.removeShareLinkFor(file: file)

        authenticatedSession.request(url, method: .delete).responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func getFileDetail(driveId: Int, fileId: Int, completion: @escaping (ApiResponse<File>?, Error?) -> Void) {
        let url = ApiRoutes.getFileDetail(driveId: driveId, fileId: fileId)

        authenticatedSession.request(url, method: .get)
            .validate()
            .responseDecodable(of: ApiResponse<File>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getFileDetailActivity(file: File, page: Int, completion: @escaping (ApiResponse<[FileDetailActivity]>?, Error?) -> Void) {
        let url = "\(ApiRoutes.getFileDetailActivity(file: file))?with=user,mobile\(pagination(page: page))"

        authenticatedSession.request(url, method: .get).responseDecodable(of: ApiResponse<[FileDetailActivity]>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func getFileDetailComment(file: File, page: Int, completion: @escaping (ApiResponse<[Comment]>?, Error?) -> Void) {
        let url = "\(ApiRoutes.getFileDetailComment(file: file))?with=like,response\(pagination(page: page))"

        authenticatedSession.request(url, method: .get).responseDecodable(of: ApiResponse<[Comment]>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func addCommentTo(file: File, comment: String, completion: @escaping (ApiResponse<Comment>?, Error?) -> Void) {
        let url = ApiRoutes.getFileDetailComment(file: file)
        let body: [String: Any] = ["body": comment]

        authenticatedSession.request(url, method: .post, parameters: body).responseDecodable(of: ApiResponse<Comment>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func likeComment(file: File, liked: Bool, comment: Comment, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = liked ? ApiRoutes.unlikeComment(file: file, comment: comment) : ApiRoutes.likeComment(file: file, comment: comment)

        authenticatedSession.request(url, method: .post).responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func deleteComment(file: File, comment: Comment, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = ApiRoutes.getComment(file: file, comment: comment)

        authenticatedSession.request(url, method: .delete).responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func editComment(file: File, text: String, comment: Comment, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = ApiRoutes.getComment(file: file, comment: comment)
        let body: [String: Any] = ["body": text]

        authenticatedSession.request(url, method: .put, parameters: body).responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func answerComment(file: File, text: String, comment: Comment, completion: @escaping (ApiResponse<Comment>?, Error?) -> Void) {
        let url = ApiRoutes.getComment(file: file, comment: comment)
        let body: [String: Any] = ["body": text]

        authenticatedSession.request(url, method: .post, parameters: body).responseDecodable(of: ApiResponse<Comment>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func deleteFile(file: File, completion: @escaping (ApiResponse<CancelableResponse>?, Error?) -> Void) {
        let url = ApiRoutes.deleteFile(file: file)

        authenticatedSession.request(url, method: .delete)
            .responseDecodable(of: ApiResponse<CancelableResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func deleteAllFilesDefinitely(driveId: Int, completion: @escaping (ApiResponse<EmptyResponse>?, Error?) -> Void) {
        let url = ApiRoutes.deleteAllFilesDefinitely(driveId: driveId)

        authenticatedSession.request(url, method: .delete)
            .responseDecodable(of: ApiResponse<EmptyResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func deleteFileDefinitely(file: File, completion: @escaping (ApiResponse<EmptyResponse>?, Error?) -> Void) {
        let url = ApiRoutes.deleteFileDefinitely(file: file)

        authenticatedSession.request(url, method: .delete)
            .responseDecodable(of: ApiResponse<EmptyResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func renameFile(file: File, newName: String, completion: @escaping (ApiResponse<File>?, Error?) -> Void) {
        let url = ApiRoutes.renameFile(file: file)
        let body: [String: Any] = ["name": newName]

        authenticatedSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
            .responseDecodable(of: ApiResponse<File>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func duplicateFile(file: File, duplicateName: String, completion: @escaping (ApiResponse<File>?, Error?) -> Void) {
        let url = ApiRoutes.duplicateFile(file: file)
        let body: [String: Any] = ["name": duplicateName]

        authenticatedSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
            .responseDecodable(of: ApiResponse<File>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func moveFile(file: File, newParent: File, completion: @escaping (ApiResponse<CancelableResponse>?, Error?) -> Void) {
        let url = ApiRoutes.moveFile(file: file, newParentId: newParent.id)

        authenticatedSession.request(url, method: .post)
            .responseDecodable(of: ApiResponse<CancelableResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getRecentActivity(driveId: Int, page: Int = 1, completion: @escaping (ApiResponse<[FileActivity]>?, Error?) -> Void) {
        let url = ApiRoutes.getRecentActivity(driveId: driveId) + pagination(page: page)

        authenticatedSession.request(url, method: .get)
            .responseDecodable(of: ApiResponse<[FileActivity]>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getFileActivitiesFromDate(file: File, date: Int, page: Int, completion: @escaping (ApiResponse<[FileActivity]>?, Error?) -> Void) {
        let url = ApiRoutes.getFileActivitiesFromDate(file: file, date: date) + pagination(page: page)

        authenticatedSession.request(url, method: .get)
            .validate()
            .responseDecodable(of: ApiResponse<[FileActivity]>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getFilesActivities(driveId: Int, files: [File], from date: Int, completion: @escaping (ApiResponse<FilesActivities>?, Error?) -> Void) {
        let url = ApiRoutes.getFilesActivities(driveId: driveId, files: files, from: date)

        authenticatedSession.request(url, method: .get).responseDecodable(of: ApiResponse<FilesActivities>.self, decoder: ApiFetcher.decoder) { response in
            self.handleResponse(response: response, completion: completion)
        }
    }

    public func postFavoriteFile(file: File, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = ApiRoutes.favorite(file: file)

        authenticatedSession.request(url, method: .post)
            .responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func deleteFavoriteFile(file: File, completion: @escaping (ApiResponse<Bool>?, Error?) -> Void) {
        let url = ApiRoutes.favorite(file: file)

        authenticatedSession.request(url, method: .delete)
            .responseDecodable(of: ApiResponse<Bool>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
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

    public func getPublicUploadTokenWithToken(_ token: ApiToken, driveId: Int, completion: @escaping (ApiResponse<UploadToken>?, Error?) -> Void) {
        let url = ApiRoutes.getUploadToken(driveId: driveId)
        performAuthenticatedRequest(token: token) { token, error in
            if let token = token {
                AF.request(url, method: .get, headers: ["Authorization": "Bearer \(token.accessToken)"])
                    .responseDecodable(of: ApiResponse<UploadToken>.self, decoder: ApiFetcher.decoder) { response in
                        self.handleResponse(response: response, completion: completion)
                    }
            } else {
                completion(nil, error)
            }
        }
    }

    public func getTrashedFiles(driveId: Int, page: Int = 1, sortType: SortType = .nameAZ, completion: @escaping (ApiResponse<[File]>?, Error?) -> Void) {
        let url = "\(ApiRoutes.getTrashFiles(driveId: driveId, sortType: sortType))\(pagination(page: page))"

        authenticatedSession.request(url, method: .get)
            .responseDecodable(of: ApiResponse<[File]>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getChildrenTrashedFiles(driveId: Int, fileId: Int?, page: Int = 1, sortType: SortType = .nameAZ, completion: @escaping (ApiResponse<File>?, Error?) -> Void) {
        let url = "\(ApiRoutes.getTrashFiles(driveId: driveId, fileId: fileId, sortType: sortType))\(pagination(page: page))"

        authenticatedSession.request(url, method: .get)
            .validate()
            .responseDecodable(of: ApiResponse<File>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func restoreTrashedFile(file: File, completion: @escaping (ApiResponse<EmptyResponse>?, Error?) -> Void) {
        let url = ApiRoutes.restoreTrashedFile(file: file)

        authenticatedSession.request(url, method: .post)
            .validate()
            .responseDecodable(of: ApiResponse<EmptyResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func restoreTrashedFile(file: File, in folderId: Int, completion: @escaping (ApiResponse<EmptyResponse>?, Error?) -> Void) {
        let url = ApiRoutes.restoreTrashedFile(file: file)
        let body: [String: Any] = ["destination_directory_id": folderId as Any]

        authenticatedSession.request(url, method: .post, parameters: body)
            .validate()
            .responseDecodable(of: ApiResponse<EmptyResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    @discardableResult
    public func searchFiles(driveId: Int, query: String? = nil, fileType: String? = nil, page: Int = 1, sortType: SortType = .nameAZ, completion: @escaping (ApiResponse<[File]>?, Error?) -> Void) -> DataRequest {
        var url = ApiRoutes.searchFiles(driveId: driveId, sortType: sortType) + pagination(page: page)
        if let query = query {
            url += "&query=\(query)"
        }
        if let fileType = fileType {
            url += "&converted_type=\(fileType)"
        }

        return authenticatedSession.request(url, method: .get)
            .responseDecodable(of: ApiResponse<[File]>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func requireFileAccess(file: File, completion: @escaping (ApiResponse<EmptyResponse>?, Error?) -> Void) {
        let url = ApiRoutes.requireFileAccess(file: file)

        authenticatedSession.request(url, method: .post)
            .responseDecodable(of: ApiResponse<EmptyResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func cancelAction(driveId: Int, cancelId: String, completion: @escaping (ApiResponse<EmptyResponse>?, Error?) -> Void) {
        let url = ApiRoutes.cancelAction(driveId: driveId)
        let body: [String: Any] = ["cancel_id": cancelId]

        authenticatedSession.request(url, method: .post, parameters: body)
            .responseDecodable(of: ApiResponse<EmptyResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func convertFile(file: File, completion: @escaping (ApiResponse<File>?, Error?) -> Void) {
        let url = ApiRoutes.convertFile(file: file)

        authenticatedSession.request(url, method: .post)
            .responseDecodable(of: ApiResponse<File>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func bulkAction(driveId: Int, action: BulkAction, completion: @escaping (ApiResponse<CancelableResponse>?, Error?) -> Void) {
        let url = ApiRoutes.bulkAction(driveId: driveId)

        // Create encoder
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let parameterEncoder = JSONParameterEncoder(encoder: encoder)

        authenticatedSession.request(url, method: .post, parameters: action, encoder: parameterEncoder)
            .responseDecodable(of: ApiResponse<CancelableResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getFileCount(driveId: Int, fileId: Int, completion: @escaping (ApiResponse<FileCount>?, Error?) -> Void) {
        let url = ApiRoutes.fileCount(driveId: driveId, fileId: fileId)

        authenticatedSession.request(url, method: .get)
            .responseDecodable(of: ApiResponse<FileCount>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
    }

    public func getDownloadArchiveLink(driveId: Int, for files: [File], completion: @escaping (ApiResponse<DownloadArchiveResponse>?, Error?) -> Void) {
        let url = ApiRoutes.downloadArchiveLink(driveId: driveId)
        let body: [String: Any] = ["file_ids": files.map(\.id)]

        authenticatedSession.request(url, method: .post, parameters: body, encoding: JSONEncoding.default)
            .validate()
            .responseDecodable(of: ApiResponse<DownloadArchiveResponse>.self, decoder: ApiFetcher.decoder) { response in
                self.handleResponse(response: response, completion: completion)
            }
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
    let timeout = -1001
    let connectionLost = -1005

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
