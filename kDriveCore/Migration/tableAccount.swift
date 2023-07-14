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

class tableAccount: Object {
    @objc dynamic var account = ""
    @objc dynamic var active = false
    @objc dynamic var address = ""
    @objc dynamic var autoUpload = false
    @objc dynamic var autoUploadBackground = false
    @objc dynamic var autoUploadCreateSubfolder = false
    @objc dynamic var autoUploadDeleteAssetLocalIdentifier = true
    @objc dynamic var autoUploadDirectory = ""
    @objc dynamic var autoUploadFileName = ""
    @objc dynamic var autoUploadFull = false
    @objc dynamic var autoUploadImage = false
    @objc dynamic var autoUploadVideo = false
    @objc dynamic var autoUploadWWAnPhoto = false
    @objc dynamic var autoUploadWWAnVideo = false
    @objc dynamic var backend = ""
    @objc dynamic var backendCapabilitiesSetDisplayName = false
    @objc dynamic var backendCapabilitiesSetPassword = false
    @objc dynamic var businessSize = ""
    @objc dynamic var businessType = ""
    @objc dynamic var city = ""
    @objc dynamic var company = ""
    @objc dynamic var country = ""
    @objc dynamic var displayName = ""
    @objc dynamic var email = ""
    @objc dynamic var enabled = false
    @objc dynamic var groups = ""
    @objc dynamic var language = ""
    @objc dynamic var lastLogin: Double = 0
    @objc dynamic var locale = ""
    @objc dynamic var mediaPath = ""
    @objc dynamic var password = ""
    @objc dynamic var phone = ""
    @objc dynamic var quota: Double = 0
    @objc dynamic var quotaFree: Double = 0
    @objc dynamic var quotaRelative: Double = 0
    @objc dynamic var quotaTotal: Double = 0
    @objc dynamic var quotaUsed: Double = 0
    @objc dynamic var role = ""
    @objc dynamic var storageLocation = ""
    @objc dynamic var subadmin = ""
    @objc dynamic var twitter = ""
    @objc dynamic var urlBase = ""
    @objc dynamic var user = ""
    @objc dynamic var userID = ""
    @objc dynamic var userStatusClearAt: NSDate?
    @objc dynamic var userStatusIcon: String?
    @objc dynamic var userStatusMessage: String?
    @objc dynamic var userStatusMessageId: String?
    @objc dynamic var userStatusMessageIsPredefined = false
    @objc dynamic var userStatusStatus: String?
    @objc dynamic var userStatusStatusIsUserDefined = false
    @objc dynamic var webpage = ""
    @objc dynamic var zip = ""
    // HC
    @objc dynamic var hcIsTrial = false
    @objc dynamic var hcTrialExpired = false
    @objc dynamic var hcTrialRemainingSec: Double = 0
    @objc dynamic var hcTrialEndTime: NSDate?
    @objc dynamic var hcAccountRemoveExpired = false
    @objc dynamic var hcAccountRemoveRemainingSec: Double = 0
    @objc dynamic var hcAccountRemoveTime: NSDate?
    @objc dynamic var hcNextGroupExpirationGroup = ""
    @objc dynamic var hcNextGroupExpirationGroupExpired = false
    @objc dynamic var hcNextGroupExpirationExpiresTime: NSDate?
    @objc dynamic var hcNextGroupExpirationExpires = ""

    override static func primaryKey() -> String {
        return "account"
    }
}
