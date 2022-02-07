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

    static func fileURL(file: File) -> String {
        return "\(driveApiUrl)\(file.driveId)/file/\(file.id)/"
    }

    static func getAllDrivesData() -> String { return "\(driveApiUrl)init?with=drives,users,teams,categories" }

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

    static func getFilesActivities(driveId: Int, files: [File], from date: Int) -> String {
        let fileIds = files.map { String($0.id) }
        return "\(driveApiUrl)\(driveId)/files/\(fileIds.joined(separator: ","))/activity?with=file,rights,collaborative_folder,favorite,mobile,share_link,categories&actions[]=file_rename&actions[]=file_delete&actions[]=file_update&from_date=\(date)"
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

    public static func fileCount(driveId: Int, fileId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/\(fileId)/count"
    }
}
