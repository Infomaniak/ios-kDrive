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

public class ApiRoutes {

    static let driveApiUrl = "https://drive.infomaniak.com/drive/"
    static let officeApiUrl = "https://drive.infomaniak.com/app/office/"
    static let with = "with=parent,children,rights,collaborative_folder,favorite,mobile,share_link"
    static let shopUrl = "https://shop.infomaniak.com/order/"

    static func fileURL(file: File) -> String {
        return "\(driveApiUrl)\(file.driveId)/file/\(file.id)/"
    }

    static func getAllDrivesData() -> String { return "\(driveApiUrl)init?with=drives,users,tags" }

    static func createDirectory(driveId: Int, parentId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/folder/\(parentId)?\(with)"
    }

    static func createCommonDirectory(driveId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/folder/team?\(with)"
    }

    static func createOfficeFile(driveId: Int, parentId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/file/\(parentId)?\(with)"
    }

    static func setupDropBox(directory: File) -> String {
        return "\(fileURL(file: directory))collaborate"
    }

    static func getFileListForDirectory(driveId: Int, parentId: Int, sortType: SortType) -> String {
        return "\(driveApiUrl)\(driveId)/file/\(parentId)?\(with)&order=\(sortType.value.order)&order_by=\(sortType.value.apiValue)"
    }

    static func getFileDetail(driveId: Int, fileId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/\(fileId)?with=parent,extras,user,rights,collaborative_folder,share_link,mobile"
    }

    static func getMyShared(driveId: Int, sortType: SortType) -> String {
        return "\(driveApiUrl)\(driveId)/file/my_shared?\(with)&order=\(sortType.value.order)&order_by=\(sortType.value.apiValue)"
    }

    static func getFileDetailActivity(file: File) -> String {
        return "\(fileURL(file: file))activity"
    }

    static func getFileDetailComment(file: File) -> String {
        return "\(fileURL(file: file))comment"
    }

    static func likeComment(file: File, comment: Comment) -> String {
        return "\(fileURL(file: file))comment/\(comment.id)/like"
    }

    static func unlikeComment(file: File, comment: Comment) -> String {
        return "\(fileURL(file: file))comment/\(comment.id)/unlike"
    }

    static func getComment(file: File, comment: Comment) -> String {
        return "\(fileURL(file: file))comment/\(comment.id)"
    }

    static func getFavoriteFiles(driveId: Int, sortType: SortType) -> String {
        return "\(driveApiUrl)\(driveId)/file/favorite?\(with)&order=\(sortType.value.order)&order_by=\(sortType.value.apiValue)"
    }

    static func getLastModifiedFiles(driveId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/last_modified?\(with)"
    }

    static func getLastPictures(driveId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/search?order=desc&order_by=last_modified_at&\(with)&converted_type=image"
    }

    static func getShareListFor(file: File) -> String {
        return "\(fileURL(file: file))share?with=*"
    }

    static func activateShareLinkFor(file: File) -> String {
        return "\(fileURL(file: file))link?permission=public"
    }

    static func updateShareLinkWith(file: File) -> String {
        return "\(fileURL(file: file))link"
    }

    static func removeShareLinkFor(file: File) -> String {
        return "\(fileURL(file: file))link"
    }

    static func updateUserRights(file: File, user: DriveUser) -> String {
        return "\(fileURL(file: file))share/\(user.id)"
    }

    static func addUserRights(file: File) -> String {
        return "\(fileURL(file: file))share"
    }

    static func checkUserRights(file: File) -> String {
        return "\(fileURL(file: file))share/check"
    }

    static func updateInvitationRights(driveId: Int, invitation: Invitation) -> String {
        return "\(driveApiUrl)\(driveId)/user/invitation/\(invitation.id)"
    }

    static func deleteInvitationRights(driveId: Int, invitation: Invitation) -> String {
        return "\(driveApiUrl)\(driveId)/file/invitation/\(invitation.id)"
    }

    static func deleteFile(file: File) -> String {
        return fileURL(file: file)
    }

    static func renameFile(file: File) -> String {
        return "\(fileURL(file: file))rename?\(with)"
    }

    static func duplicateFile(file: File) -> String {
        return "\(fileURL(file: file))copy?\(with)"
    }

    static func moveFile(file: File, newParentId: Int) -> String {
        return "\(fileURL(file: file))move/\(newParentId)"
    }

    public static func downloadFile(file: File) -> String {
        return "\(fileURL(file: file))download"
    }

    static func uploadFile(file: UploadFile) -> String {
        var url = "\(driveApiUrl)\(file.driveId)/public/file/\(file.parentDirectoryId)/upload?file_name=\(file.urlEncodedName)&relative_path=\(file.urlEncodedRelativePath)\(file.urlEncodedName)&with=parent,children,rights,collaborative_folder,favorite,share_link"
        if let creationDate = file.creationDate {
            url += "&file_created_at=\(Int(creationDate.timeIntervalSince1970))"
        }
        if let modificationDate = file.modificationDate {
            url += "&last_modified_at=\(Int(modificationDate.timeIntervalSince1970))"
        }
        return url
    }

    static func getRecentActivity(driveId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/activity?with=file,rights,collaborative_folder,favorite,mobile,share_link&depth=unlimited" +
            "&actions[]=file_create" +
            "&actions[]=file_update" +
            "&actions[]=comment_create" +
            "&actions[]=file_restore" +
            "&actions[]=file_trash"
    }

    static func getFileActivitiesFromDate(file: File, date: Int) -> String {
        return "\(fileURL(file: file))activity?depth=children&with=file,rights,collaborative_folder,favorite,mobile,share_link&from_date=\(date)"
    }

    static func favorite(file: File) -> String {
        return "\(fileURL(file: file))favorite"
    }

    static func getTrashFiles(driveId: Int, fileId: Int? = nil, sortType: SortType) -> String {
        let fileId = fileId == nil ? "" : "\(fileId!)"
        return "\(driveApiUrl)\(driveId)/file/trash/\(fileId)?with=children,parent&order=\(sortType.value.order)&order_by=\(sortType.value.apiValue)"
    }

    static func deleteAllFilesDefinitely(driveId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/trash"
    }

    static func deleteFileDefinitely(file: File) -> String {
        return "\(driveApiUrl)\(file.driveId)/file/trash/\(file.id)"
    }

    static func restoreTrashedFile(file: File) -> String {
        return "\(driveApiUrl)\(file.driveId)/file/trash/\(file.id)/restore"
    }

    static func searchFiles(driveId: Int, sortType: SortType) -> String {
        return "\(driveApiUrl)\(driveId)/file/search?\(with)&order=\(sortType.value.order)&order_by=\(sortType.value.apiValue)"
    }

    public static func showOffice(file: File) -> String {
        return "\(officeApiUrl)\(file.driveId)/\(file.id)"
    }

    public static func mobileLogin(url: String) -> String {
        return "https://manager.infomaniak.com/v3/mobile_login?url=\(url)"
    }

    static func requireFileAccess(file: File) -> String {
        return "\(fileURL(file: file))share/access"
    }

    public static func orderDrive() -> String {
        return "\(shopUrl)drive"
    }

    public static func getUploadToken(driveId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/1/upload/token"
    }

    public static func cancelAction(driveId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/cancel"
    }

    public static func convertFile(file: File) -> String {
        return "\(fileURL(file: file))convert"
    }

    public static func registerIkDriveUser() -> String {
        return "https://welcome.infomaniak.com/signup/ikdrive/steps"
    }

}
