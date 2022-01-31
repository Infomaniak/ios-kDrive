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

public enum ApiRoutes {
    static let driveApiUrl = "https://drive.preprod.dev.infomaniak.ch/drive/"
    static let officeApiUrl = "https://drive.infomaniak.com/app/office/"
    static let with = "with=parent,children,rights,collaborative_folder,favorite,mobile,share_link,categories"
    static let shopUrl = "https://shop.infomaniak.com/order/"

    static func fileURL(file: File) -> String {
        return "\(driveApiUrl)\(file.driveId)/file/\(file.id)/"
    }

    static func getAllDrivesData() -> String { return "\(driveApiUrl)init?with=drives,users,teams,categories" }

    static func getMyShared(driveId: Int, sortType: SortType) -> String {
        return "\(driveApiUrl)\(driveId)/file/my_shared?\(with)&order=\(sortType.value.order)&order_by=\(sortType.value.apiValue)"
    }

    static func getFileDetailActivity(file: File) -> String {
        return "\(fileURL(file: file))activity"
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

    static func renameFile(file: File) -> String {
        return "\(fileURL(file: file))rename?\(with)"
    }

    static func duplicateFile(file: File) -> String {
        return "\(fileURL(file: file))copy?\(with)"
    }

    static func copyFile(file: File, newParentId: Int) -> String {
        return "\(fileURL(file: file))copy/\(newParentId)"
    }

    static func uploadFile(file: UploadFile) -> String {
        var url = "\(driveApiUrl)\(file.driveId)/public/file/\(file.parentDirectoryId)/upload?file_name=\(file.urlEncodedName)&conflict=\(file.conflictOption.rawValue)&relative_path=\(file.urlEncodedRelativePath)\(file.urlEncodedName)&with=parent,children,rights,collaborative_folder,favorite,share_link"
        if let creationDate = file.creationDate {
            url += "&file_created_at=\(Int(creationDate.timeIntervalSince1970))"
        }
        if let modificationDate = file.modificationDate {
            url += "&last_modified_at=\(Int(modificationDate.timeIntervalSince1970))"
        }
        return url
    }

    static func getRecentActivity(driveId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/activity?with=file,rights,collaborative_folder,favorite,mobile,share_link,categories&depth=unlimited" +
            "&actions[]=file_create" +
            "&actions[]=file_update" +
            "&actions[]=comment_create" +
            "&actions[]=file_restore" +
            "&actions[]=file_trash"
    }

    static func getFileActivitiesFromDate(file: File, date: Int) -> String {
        let activitiesParam = FileActivityType.fileActivities.map { "&actions[]=\($0.rawValue)" }.joined()
        return "\(fileURL(file: file))activity?depth=children&with=file,rights,collaborative_folder,favorite,mobile,share_link,categories&from_date=\(date)" + activitiesParam
    }

    static func getFilesActivities(driveId: Int, files: [File], from date: Int) -> String {
        let fileIds = files.map { String($0.id) }
        return "\(driveApiUrl)\(driveId)/files/\(fileIds.joined(separator: ","))/activity?with=file,rights,collaborative_folder,favorite,mobile,share_link,categories&actions[]=file_rename&actions[]=file_delete&actions[]=file_update&from_date=\(date)"
    }

    static func getTrashFiles(driveId: Int, fileId: Int? = nil, sortType: SortType) -> String {
        let fileId = fileId == nil ? "" : "\(fileId!)"
        return "\(driveApiUrl)\(driveId)/file/trash/\(fileId)?with=children,parent&order=\(sortType.value.order)&order_by=\(sortType.value.apiValue)"
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

    public static func getUploadToken(driveId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/1/upload/token"
    }

    public static func convertFile(file: File) -> String {
        return "\(fileURL(file: file))convert"
    }

    public static func fileCount(driveId: Int, fileId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/\(fileId)/count"
    }
}
