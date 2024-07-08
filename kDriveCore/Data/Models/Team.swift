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
import kDriveResources
import RealmSwift
import UIKit

public class Team: Object, Codable {
    public static let allUsersId = 0

    @Persisted(primaryKey: true) public var id = UUID().uuidString.hashValue
    @Persisted public var name: String
    @Persisted public var usersCount: Int?
    @Persisted public var colorId: Int

    public var isAllUsers: Bool {
        return id == Team.allUsersId
    }

    public var colorHex: String {
        guard !isAllUsers else { return "#4051b5" }
        let colors = [
            "#F44336",
            "#E91E63",
            "#9C26B0",
            "#673AB7",
            "#4051B5",
            "#4BAF50",
            "#009688",
            "#00BCD4",
            "#02A9F4",
            "#2196F3",
            "#8BC34A",
            "#CDDC3A",
            "#FFC10A",
            "#FF9802",
            "#607D8B",
            "#9E9E9E",
            "#795548"
        ]
        return colorId < colors.count ? colors[colorId] : "#E91E63"
    }

    public var icon: UIImage {
        let size = CGSize(width: 35, height: 35)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(hex: colorHex)?.setFill()
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            ctx.cgContext.fill(rect)
            UIColor.white.setFill()
            let icon = isAllUsers ? KDriveResourcesAsset.drive.image : KDriveResourcesAsset.team.image
            icon.draw(in: CGRect(x: 8.5, y: 8.5, width: 18, height: 18))
        }
    }

    override public init() {
        // Required by Realm
        super.init()
        // primary key is set as default value
    }
}

extension Team: Comparable {
    public static func < (lhs: Team, rhs: Team) -> Bool {
        return lhs.isAllUsers || lhs.name.lowercased() < rhs.name.lowercased()
    }
}
