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

import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import KSuite
import UIKit

enum RightsSelectionType {
    case shareLinkSettings
    case addUserRights
    case officeOnly
}

protocol RightsSelectionDelegate: AnyObject {
    func didUpdateRightValue(newValue value: String)
    func didDeleteUserRight()
    func didRemoveUserDriveAccess()
}

extension RightsSelectionDelegate {
    func didDeleteUserRight() {
        // META: keep SonarCloud happy
    }

    func didRemoveUserDriveAccess() {
        // META: keep SonarCloud happy
    }
}

struct Right {
    var key: String
    var title: String
    var icon: UIImage
    var fileDescription: String?
    var folderDescription: String?
    var documentDescription: String?
    var upgradeDescription: String?
    var detailDescription: String?

    static func shareLinkRights(driveFileManager: DriveFileManager) -> [Right] {
        var upgradeDescription: String?
        var detailDescription: String?
        if driveFileManager.drive.pack.kSuiteProUpgradePath != nil {
            if driveFileManager.drive.sharedLinkQuotaExceeded {
                upgradeDescription = KDriveResourcesStrings.Localizable.buttonUpgradeOffer
            }
        } else if driveFileManager.drive.pack.drivePackId == .kSuiteEntreprise && driveFileManager.drive.sharedLinkQuotaExceeded {
            if driveFileManager.drive.accountAdmin {
                detailDescription = KSuiteLocalizable.kSuiteUpgradeDetails
            } else {
                detailDescription = KSuiteLocalizable.kSuiteUpgradeDetailsContactAdmin
            }
        }

        return [Right(key: ShareLinkPermission.restricted.rawValue,
                      title: KDriveResourcesStrings.Localizable.shareLinkPrivateRightTitle,
                      icon: KDriveResourcesAsset.lock.image,
                      fileDescription: KDriveResourcesStrings.Localizable.shareLinkRestrictedRightFileDescriptionShort,
                      folderDescription: KDriveResourcesStrings.Localizable.shareLinkRestrictedRightFolderDescriptionShort,
                      documentDescription: KDriveResourcesStrings.Localizable.shareLinkRestrictedRightDocumentDescriptionShort),
                Right(key: ShareLinkPermission.public.rawValue,
                      title: KDriveResourcesStrings.Localizable.shareLinkPublicRightTitle,
                      icon: KDriveResourcesAsset.unlock.image,
                      fileDescription: KDriveResourcesStrings.Localizable.shareLinkPublicRightFileDescriptionShort,
                      folderDescription: KDriveResourcesStrings.Localizable.shareLinkPublicRightFolderDescriptionShort,
                      documentDescription: KDriveResourcesStrings.Localizable.shareLinkPublicRightDocumentDescriptionShort,
                      upgradeDescription: upgradeDescription,
                      detailDescription: detailDescription)]
    }

    static let onlyOfficeRights = [
        Right(key: EditPermission.read.rawValue,
              title: KDriveResourcesStrings.Localizable.shareLinkOfficePermissionReadTitle,
              icon: KDriveResourcesAsset.view.image,
              fileDescription: KDriveResourcesStrings.Localizable.shareLinkOfficePermissionReadFileDescription,
              folderDescription: KDriveResourcesStrings.Localizable.shareLinkOfficePermissionReadFolderDescription,
              documentDescription: KDriveResourcesStrings.Localizable.shareLinkOfficePermissionReadFileDescription),
        Right(key: EditPermission.write.rawValue,
              title: KDriveResourcesStrings.Localizable.shareLinkOfficePermissionWriteTitle,
              icon: KDriveResourcesAsset.edit.image,
              fileDescription: KDriveResourcesStrings.Localizable.shareLinkOfficePermissionWriteFileDescription,
              folderDescription: KDriveResourcesStrings.Localizable.shareLinkOfficePermissionWriteFolderDescription,
              documentDescription: KDriveResourcesStrings.Localizable.shareLinkOfficePermissionWriteFileDescription)
    ]
}

class RightsSelectionViewController: UIViewController {
    @IBOutlet var tableView: UITableView!
    @IBOutlet var closeButton: UIButton!

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var router: AppNavigable

    var fileAccessElement: FileAccessElement?

    var rightSelectionType = RightsSelectionType.addUserRights

    var rights = [Right]()
    var selectedRight = ""

    weak var delegate: RightsSelectionDelegate?

    var file: File!

    var canDelete = true

    var driveFileManager: DriveFileManager!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: RightsSelectionTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.List.paddingBottom, right: 0)

        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .stop,
            target: self,
            action: #selector(cancelButtonPressed)
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
        navigationItem.largeTitleDisplayMode = .always

        setupView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Necessary for the large display to show up on initial view display, but why ?
        navigationController?.navigationBar.sizeToFit()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        matomo.track(view: [MatomoUtils.View.shareAndRights.displayName, "RightsSelection"])
    }

    private func setupView() {
        switch rightSelectionType {
        case .shareLinkSettings:
            rights = Right.shareLinkRights(driveFileManager: driveFileManager)

        case .addUserRights:
            let getUserRightDescription = { (permission: UserPermission) -> (String?) in
                switch permission {
                case .read:
                    return KDriveResourcesStrings.Localizable.userPermissionReadDescription
                case .write:
                    let isInvitation = self.fileAccessElement is ExternInvitationFileAccess
                    let isNonInternalUser = {
                        if let userId = self.fileAccessElement?.user?.id {
                            return !self.driveFileManager.drive.users.internalUsers.contains(userId)
                        }
                        return false
                    }()

                    if isInvitation || isNonInternalUser {
                        return KDriveResourcesStrings.Localizable.userPermissionWriteExternalDescription
                    }
                    return KDriveResourcesStrings.Localizable.userPermissionWriteDescription
                case .manage:
                    return KDriveResourcesStrings.Localizable.userPermissionManageDescription
                case .delete:
                    return KDriveResourcesStrings.Localizable.userPermissionRemove
                case .removeDriveAccess:
                    return nil
                }
            }
            let userPermissions = UserPermission.allCases
                .filter { $0 != .delete || canDelete } // Remove delete permission is `canDelete` is false
            rights = userPermissions.map {
                Right(
                    key: $0.rawValue,
                    title: $0.title,
                    icon: $0.icon,
                    fileDescription: getUserRightDescription($0),
                    folderDescription: getUserRightDescription($0),
                    documentDescription: getUserRightDescription($0)
                )
            }

            if fileAccessElement is ExternInvitationFileAccess {
                rights.removeAll { $0.key == UserPermission.removeDriveAccess.rawValue }
            }

        case .officeOnly:
            rights = Right.onlyOfficeRights
        }
        selectRight()
        closeButton.setTitle(KDriveResourcesStrings.Localizable.buttonSave, for: .normal)
    }

    private func selectRight() {
        guard let index = rights.firstIndex(where: { $0.key == selectedRight }) else {
            return
        }
        tableView.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .none)
    }

    @IBAction func closeButtonPressed(_ sender: Any) {
        let rightKey = rights[tableView.indexPathForSelectedRow?.row ?? 0].key
        delegate?.didUpdateRightValue(newValue: rightKey)
        trackRightSelection(type: rightSelectionType, selected: rightKey)
        dismiss(animated: true)
    }

    @objc func cancelButtonPressed() {
        dismiss(animated: true)
    }

    class func instantiateInNavigationController(file: File,
                                                 driveFileManager: DriveFileManager) -> TitleSizeAdjustingNavigationController {
        let navigationController = TitleSizeAdjustingNavigationController(rootViewController: instantiate(
            file: file,
            driveFileManager: driveFileManager
        ))
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    class func instantiate(file: File, driveFileManager: DriveFileManager) -> RightsSelectionViewController {
        let viewController = Storyboard.files
            .instantiateViewController(withIdentifier: "RightsSelectionViewController") as! RightsSelectionViewController
        viewController.file = file
        viewController.driveFileManager = driveFileManager
        return viewController
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension RightsSelectionViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rights.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: RightsSelectionTableViewCell.self, for: indexPath)
        let right = rights[indexPath.row]
        var disable = false
        if right.key == UserPermission.manage.rawValue {
            if let userId = fileAccessElement?.user?.id {
                disable = !driveFileManager.drive.users.internalUsers.contains(userId)
            }

            if fileAccessElement is ExternInvitationFileAccess {
                disable = true
            }
        }
        cell.configureCell(
            right: right,
            type: rightSelectionType,
            disable: disable,
            file: file
        )

        return cell
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if let cell = tableView.cellForRow(at: indexPath) as? RightsSelectionTableViewCell, cell.isSelectable {
            return indexPath
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if driveFileManager.drive.pack.isAnyKSuiteProOffer,
           driveFileManager.drive.sharedLinkQuotaExceeded,
           indexPath.row == 1 {
            if driveFileManager.drive.pack.kSuiteProUpgradePath != nil {
                router.presentKDriveProUpSaleSheet(driveFileManager: driveFileManager)
                matomo.track(eventWithCategory: .kSuiteProUpgradeBottomSheet, name: "shareLinkQuotaExceeded")
            }

            tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: true, scrollPosition: .top)
            return
        }

        let right = rights[indexPath.row]
        switch right.key {
        case UserPermission.delete.rawValue:
            let deleteUser = fileAccessElement?.name ?? ""
            let attrString = NSMutableAttributedString(
                string: KDriveResourcesStrings.Localizable.modalUserPermissionRemoveDescription(deleteUser),
                boldText: deleteUser
            )
            let alert = AlertTextViewController(
                title: KDriveResourcesStrings.Localizable.buttonDelete,
                message: attrString,
                action: KDriveResourcesStrings.Localizable.buttonDelete,
                destructive: true
            ) {
                self.delegate?.didDeleteUserRight()
                self.presentingViewController?.dismiss(animated: true)
            }
            present(alert, animated: true)
            selectRight()

        case UserPermission.removeDriveAccess.rawValue:
            let deleteUser = fileAccessElement?.name ?? ""
            let attrString = NSMutableAttributedString(
                string: KDriveResourcesStrings.Localizable.modalUserPermissionRemoveDescription(deleteUser),
                boldText: deleteUser
            )
            let alert = AlertTextViewController(
                title: KDriveResourcesStrings.Localizable.buttonDelete,
                message: attrString,
                action: KDriveResourcesStrings.Localizable.buttonDelete,
                destructive: true
            ) {
                self.delegate?.didRemoveUserDriveAccess()
                self.presentingViewController?.dismiss(animated: true)
            }
            present(alert, animated: true)
            selectRight()

        default:
            selectedRight = right.key
        }
    }
}
