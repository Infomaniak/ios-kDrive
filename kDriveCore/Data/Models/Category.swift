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
import RealmSwift
import UIKit

public class Category: Object, Codable {
    @Persisted(primaryKey: true) public var id: Int
    @Persisted public var name: String
    @Persisted public var isPredefined: Bool
    @Persisted private var _color: String
    @Persisted public var createdBy: Int
    @Persisted public var createdAt: Date
    public var isGeneratedByIA: Bool?
    public var IACategoryUserValidation: String?

    public var color: UIColor? {
        return UIColor(hex: _color)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isPredefined = "is_predefined"
        case _color = "color"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case isGeneratedByIA = "is_generated_by_ia"
        case IACategoryUserValidation = "ia_category_user_validation"
    }
}

public enum PredefinedCategory: String {
    // Document types

    case contract = "PREDEF_CAT_CONTRACT"
    case bill = "PREDEF_CAT_BILL"
    case receipt = "PREDEF_CAT_RECEIPT"
    case certificate = "PREDEF_CAT_CERTIFICAT"
    case testimony = "PREDEF_CAT_TESTIMONY"
    case warranty = "PREDEF_CAT_WARRANTY"
    case id = "PREDEF_CAT_ID"
    case form = "PREDEF_CAT_FORM"
    case quotation = "PREDEF_CAT_QUOTATION"
    case mail = "PREDEF_CAT_MAIL"

    // Themes

    case employees = "PREDEF_CAT_EMPLOYEES"
    case provider = "PREDEF_CAT_PROVIDER"
    case banking = "PREDEF_CAT_BANKING"
    case realEstate = "PREDEF_CAT_REAL_ESTATE"
    case taxation = "PREDEF_CAT_TAXATION"
    case legal = "PREDEF_CAT_LEGAL"
    case insurance = "PREDEF_CAT_INSURANCE"
    case transportation = "PREDEF_CAT_TRANSPORTATION"
    case phoneAndInternet = "PREDEF_CAT_PHONE_INTERNET"
    case personal = "PREDEF_CAT_PERSONAL"
    case family = "PREDEF_CAT_FAMILY"
    case work = "PREDEF_CAT_WORK"
    case hobbies = "PREDEF_CAT_HOBBIES"
}
