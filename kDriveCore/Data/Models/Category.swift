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
import InfomaniakCoreUIKit
import kDriveResources
import RealmSwift
import UIKit

public class Category: EmbeddedObject, Codable {
    @Persisted public var id: Int
    @Persisted public var name: String
    @Persisted public var isPredefined: Bool
    @Persisted public var colorHex: String
    @Persisted public var createdBy: Int
    @Persisted public var createdAt: Date
    @Persisted public var userUsageCount: Int?

    public var isSelected = false

    public var color: UIColor? {
        return UIColor(hex: colorHex)
    }

    public var localizedName: String {
        if isPredefined, let predefinedCategory = PredefinedCategory(rawValue: name) {
            return predefinedCategory.title
        } else {
            return name
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isPredefined
        case colorHex = "color"
        case createdBy
        case createdAt
        case userUsageCount
    }
}

public enum PredefinedCategory: String {
    case banking = "PREDEF_CAT_BANKING"
    case bill = "PREDEF_CAT_BILL"
    case contract = "PREDEF_CAT_CONTRACT"
    case form = "PREDEF_CAT_FORM"
    case hobbies = "PREDEF_CAT_HOBBIES"
    case id = "PREDEF_CAT_ID"
    case insurance = "PREDEF_CAT_INSURANCE"
    case quotation = "PREDEF_CAT_QUOTATION"
    case resume = "PREDEF_CAT_RESUME"
    case taxation = "PREDEF_CAT_TAXATION"
    case transportation = "PREDEF_CAT_TRANSPORTATION"
    case warranty = "PREDEF_CAT_WARRANTY"
    case work = "PREDEF_CAT_WORK"

    var title: String {
        switch self {
        case .banking:
            return KDriveResourcesStrings.Localizable.categoryBanking
        case .bill:
            return KDriveResourcesStrings.Localizable.categoryBill
        case .contract:
            return KDriveResourcesStrings.Localizable.categoryContract
        case .form:
            return KDriveResourcesStrings.Localizable.categoryForm
        case .hobbies:
            return KDriveResourcesStrings.Localizable.categoryHobbies
        case .id:
            return KDriveResourcesStrings.Localizable.categoryID
        case .insurance:
            return KDriveResourcesStrings.Localizable.categoryInsurance
        case .quotation:
            return KDriveResourcesStrings.Localizable.categoryQuotation
        case .resume:
            return KDriveResourcesStrings.Localizable.categoryResume
        case .taxation:
            return KDriveResourcesStrings.Localizable.categoryTaxation
        case .transportation:
            return KDriveResourcesStrings.Localizable.categoryTransportation
        case .warranty:
            return KDriveResourcesStrings.Localizable.categoryWarranty
        case .work:
            return KDriveResourcesStrings.Localizable.categoryWork
        }
    }
}
