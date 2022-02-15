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
    static let driveApiUrl = "https://\(ApiEnvironment.current.driveHost)/drive/"

    static func getAllDrivesData() -> String { return "\(driveApiUrl)init?with=drives,users,teams,categories" }

    static func upload(file: UploadFile) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = ApiEnvironment.current.driveHost
        components.path = "/drive/\(file.driveId)/public/file/\(file.parentDirectoryId)/upload"
        components.queryItems = file.queryItems
        return components.url
    }

    static func getFilesActivities(driveId: Int, files: [File], from date: Int) -> String {
        let fileIds = files.map { String($0.id) }
        return "\(driveApiUrl)\(driveId)/files/\(fileIds.joined(separator: ","))/activity?with=file,rights,collaborative_folder,favorite,mobile,share_link,categories&actions[]=file_rename&actions[]=file_delete&actions[]=file_update&from_date=\(date)"
    }

    public static func mobileLogin(url: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = ApiEnvironment.current.managerHost
        components.path = "/v3/mobile_login"
        components.queryItems = [URLQueryItem(name: "url", value: url)]
        return components.url
    }

    public static func getUploadToken(driveId: Int) -> String {
        return "\(driveApiUrl)\(driveId)/file/1/upload/token"
    }
}
