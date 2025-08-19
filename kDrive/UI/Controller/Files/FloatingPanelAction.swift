/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

import kDriveCore
import kDriveResources
import UIKit

public class FloatingPanelAction: Equatable {
    let id: ActionIdentifier
    let name: String
    var reverseName: String?
    let image: UIImage
    var tintColor: UIColor = KDriveResourcesAsset.iconColor.color
    var isLoading = false
    var isEnabled = true

    enum ActionIdentifier {
        case openWith
        case edit
        case manageCategories
        case favorite
        case convertToDropbox
        case folderColor
        case manageDropbox
        case seeFolder
        case offline
        case download
        case move
        case duplicate
        case rename
        case delete
        case leaveShare
        case cancelImport
        case informations
        case add
        case sendCopy
        case shareAndRights
        case shareLink
        case upsaleColor
        case addToMyDrive
    }

    init(
        id: ActionIdentifier,
        name: String,
        reverseName: String? = nil,
        image: UIImage,
        tintColor: UIColor = KDriveResourcesAsset.iconColor.color
    ) {
        self.id = id
        self.name = name
        self.reverseName = reverseName
        self.image = image
        self.tintColor = tintColor
    }

    func reset() -> FloatingPanelAction {
        isEnabled = true
        isLoading = false
        return self
    }

    static let openWith = FloatingPanelAction(
        id: .openWith,
        name: KDriveResourcesStrings.Localizable.buttonOpenWith,
        image: KDriveResourcesAsset.openWith.image
    )
    static let edit = FloatingPanelAction(
        id: .edit,
        name: KDriveResourcesStrings.Localizable.buttonEdit,
        image: KDriveResourcesAsset.editDocument.image
    )
    static let manageCategories = FloatingPanelAction(
        id: .manageCategories,
        name: KDriveResourcesStrings.Localizable.manageCategoriesTitle,
        image: KDriveResourcesAsset.categories.image
    )
    static let favorite = FloatingPanelAction(
        id: .favorite,
        name: KDriveResourcesStrings.Localizable.buttonAddFavorites,
        reverseName: KDriveResourcesStrings.Localizable.buttonRemoveFavorites,
        image: KDriveResourcesAsset.favorite.image
    )
    static let convertToDropbox = FloatingPanelAction(
        id: .convertToDropbox,
        name: KDriveResourcesStrings.Localizable.buttonConvertToDropBox,
        image: KDriveResourcesAsset.folderDropBox.image.withRenderingMode(.alwaysTemplate)
    )
    static let folderColor = FloatingPanelAction(
        id: .folderColor,
        name: KDriveResourcesStrings.Localizable.buttonChangeFolderColor,
        image: KDriveResourcesAsset.colorBucket.image
    )
    static let manageDropbox = FloatingPanelAction(
        id: .manageDropbox,
        name: KDriveResourcesStrings.Localizable.buttonManageDropBox,
        image: KDriveResourcesAsset.folderDropBox.image.withRenderingMode(.alwaysTemplate)
    )
    static let seeFolder = FloatingPanelAction(
        id: .seeFolder,
        name: KDriveResourcesStrings.Localizable.buttonSeeFolder,
        image: KDriveResourcesAsset.folderFilled.image.withRenderingMode(.alwaysTemplate)
    )
    static let offline = FloatingPanelAction(
        id: .offline,
        name: KDriveResourcesStrings.Localizable.buttonAvailableOffline,
        image: KDriveResourcesAsset.availableOffline.image
    )
    static let download = FloatingPanelAction(
        id: .download,
        name: KDriveResourcesStrings.Localizable.buttonDownload,
        image: KDriveResourcesAsset.download.image
    )
    static let move = FloatingPanelAction(
        id: .move,
        name: KDriveResourcesStrings.Localizable.buttonMoveTo,
        image: KDriveResourcesAsset.folderSelect.image
    )
    static let duplicate = FloatingPanelAction(
        id: .duplicate,
        name: KDriveResourcesStrings.Localizable.buttonDuplicate,
        image: KDriveResourcesAsset.duplicate.image
    )
    static let rename = FloatingPanelAction(
        id: .rename,
        name: KDriveResourcesStrings.Localizable.buttonRename,
        image: KDriveResourcesAsset.edit.image
    )
    static let delete = FloatingPanelAction(
        id: .delete,
        name: KDriveResourcesStrings.Localizable.modalMoveTrashTitle,
        image: KDriveResourcesAsset.delete.image,
        tintColor: KDriveResourcesAsset.binColor.color
    )
    static let leaveShare = FloatingPanelAction(
        id: .leaveShare,
        name: KDriveResourcesStrings.Localizable.buttonLeaveShare,
        image: KDriveResourcesAsset.linkBroken.image
    )
    static let cancelImport = FloatingPanelAction(
        id: .cancelImport,
        name: KDriveResourcesStrings.Localizable.buttonCancelImport,
        image: KDriveResourcesAsset.remove.image,
        tintColor: KDriveCoreAsset.binColor.color
    )
    static let informations = FloatingPanelAction(
        id: .informations,
        name: KDriveResourcesStrings.Localizable.fileDetailsInfosTitle,
        image: KDriveResourcesAsset.info.image
    )
    static let add = FloatingPanelAction(
        id: .add,
        name: KDriveResourcesStrings.Localizable.buttonAdd,
        image: KDriveResourcesAsset.add.image
    )
    static let sendCopy = FloatingPanelAction(
        id: .sendCopy,
        name: KDriveResourcesStrings.Localizable.buttonSendCopy,
        image: KDriveResourcesAsset.exportIos.image
    )
    static let shareAndRights = FloatingPanelAction(
        id: .shareAndRights,
        name: KDriveResourcesStrings.Localizable.buttonFileRights,
        image: KDriveResourcesAsset.share.image
    )
    static let shareLink = FloatingPanelAction(
        id: .shareLink,
        name: KDriveResourcesStrings.Localizable.buttonCreatePublicLink,
        reverseName: KDriveResourcesStrings.Localizable.buttonSharePublicLink,
        image: KDriveResourcesAsset.link.image
    )
    static let upsaleColor = FloatingPanelAction(
        id: .upsaleColor,
        name: KDriveResourcesStrings.Localizable.buttonChangeFolderColor,
        image: KDriveResourcesAsset.colorBucket.image
    )
    static let addToMyDrive = FloatingPanelAction(
        id: .addToMyDrive,
        name: KDriveResourcesStrings.Localizable.buttonAddToKDrive,
        image: KDriveResourcesAsset.drive.image
    )

    static var listActions: [FloatingPanelAction] {
        return [
            openWith,
            edit,
            manageCategories,
            favorite,
            seeFolder,
            offline,
            download,
            move,
            duplicate,
            rename,
            leaveShare,
            delete
        ].map { $0.reset() }
    }

    static var folderListActions: [FloatingPanelAction] {
        return [
            manageCategories,
            favorite,
            upsaleColor,
            folderColor,
            convertToDropbox,
            manageDropbox,
            seeFolder,
            download,
            move,
            duplicate,
            rename,
            leaveShare,
            delete,
            cancelImport
        ].map { $0.reset() }
    }

    static var publicShareActions: [FloatingPanelAction] {
        return [openWith, sendCopy, download, addToMyDrive].map { $0.reset() }
    }

    static var publicShareFolderActions: [FloatingPanelAction] {
        return [download].map { $0.reset() }
    }

    static var multipleSelectionPublicShareActions: [FloatingPanelAction] {
        return [download].map { $0.reset() }
    }

    static var quickActions: [FloatingPanelAction] {
        return [informations, sendCopy, shareAndRights, shareLink].map { $0.reset() }
    }

    static var folderQuickActions: [FloatingPanelAction] {
        return [informations, add, shareAndRights, shareLink].map { $0.reset() }
    }

    static var multipleSelectionActions: [FloatingPanelAction] {
        return [manageCategories, favorite, offline, download, move, duplicate].map { $0.reset() }
    }

    static var multipleSelectionActionsOnlyFolders: [FloatingPanelAction] {
        return [manageCategories, favorite, upsaleColor, folderColor, offline, download, move, duplicate].map { $0.reset() }
    }

    static var multipleSelectionSharedWithMeActions: [FloatingPanelAction] {
        return [download].map { $0.reset() }
    }

    static var multipleSelectionPhotosListActions: [FloatingPanelAction] {
        return [manageCategories, favorite, download, move, duplicate, .offline].map { $0.reset() }
    }

    static var multipleSelectionBulkActions: [FloatingPanelAction] {
        return [offline, download, move, duplicate].map { $0.reset() }
    }

    static var selectAllActions: [FloatingPanelAction] {
        return [.offline, download, move, duplicate].map { $0.reset() }
    }

    static var selectAllOfflineActions: [FloatingPanelAction] {
        return [.offline, download].map { $0.reset() }
    }

    public static func == (lhs: FloatingPanelAction, rhs: FloatingPanelAction) -> Bool {
        return lhs.id == rhs.id
    }
}
