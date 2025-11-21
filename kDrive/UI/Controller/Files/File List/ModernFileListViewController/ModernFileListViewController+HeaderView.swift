/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import kDriveCore
import kDriveResources
import UIKit

extension ModernFileListViewController {
    func setUpHeaderView(_ headerView: FilesHeaderView, isEmptyViewHidden: Bool) {
        headerView.delegate = self

        if viewModel.currentDirectory.visibility == .isTeamSpace {
            let driveOrganisationName = viewModel.driveFileManager.drive.account.name
            let commonDocumentsDescription = KDriveResourcesStrings.Localizable.commonDocumentsDescription(driveOrganisationName)

            headerView.commonDocumentsDescriptionLabel.text = commonDocumentsDescription
            headerView.commonDocumentsDescriptionLabel.isHidden = false
        } else {
            headerView.commonDocumentsDescriptionLabel.isHidden = true
        }

        let isTrash = viewModel.currentDirectory.id == DriveFileManager.trashRootFile.id
        headerView.updateInformationView(drivePackId: packId, isTrash: isTrash)
        headerView.sortView.isHidden = !isEmptyViewHidden

        headerView.sortButton.isHidden = viewModel.configuration.sortingOptions.isEmpty
        UIView.performWithoutAnimation {
            headerView.sortButton.setTitle(viewModel.sortType.value.translation, for: .normal)
            headerView.sortButton.layoutIfNeeded()
            headerView.listOrGridButton.setImage(viewModel.listStyle.icon, for: .normal)
            headerView.listOrGridButton.layoutIfNeeded()
        }

        if let uploadViewModel = viewModel.uploadViewModel {
            headerView.uploadCardView.isHidden = uploadViewModel.uploadCount == 0
            headerView.uploadCardView.titleLabel.text = KDriveResourcesStrings.Localizable.uploadInThisFolderTitle
            headerView.uploadCardView.setUploadCount(uploadViewModel.uploadCount)
            headerView.uploadCardView.progressView.enableIndeterminate()
        }
    }
}

// MARK: - FilesHeaderViewDelegate

extension ModernFileListViewController: FilesHeaderViewDelegate {
    func headerViewHeightDidChange(_ headerView: FilesHeaderView) {
        collectionView.contentInset.top = headerView.frame.height
    }

    func sortButtonPressed() {
        viewModel.sortButtonPressed()
    }

    func gridButtonPressed() {
        viewModel.listStyleButtonPressed()
    }

    #if !ISEXTENSION
    func uploadCardSelected() {
        let uploadViewController = UploadQueueViewController.instantiate()
        uploadViewController.currentDirectory = viewModel.currentDirectory
        navigationController?.pushViewController(uploadViewController, animated: true)
    }
    #endif

    func multipleSelectionActionButtonPressed(_ button: SelectView.MultipleSelectionActionButton) {
        viewModel.multipleSelectionViewModel?.actionButtonPressed(action: button.action)
    }

    func removeFilterButtonPressed(_ filter: Filterable) {
        // Overriden in subclasses
    }

    func upsaleButtonPressed() {
        if packId == .myKSuite {
            router.presentUpSaleSheet()
            matomo.track(eventWithCategory: .myKSuiteUpgradeBottomSheet, name: "trashStorageLimit")
        } else if packId == .kSuiteEssential {
            router.presentKDriveProUpSaleSheet(driveFileManager: driveFileManager)
            matomo.track(eventWithCategory: .kSuiteProUpgradeBottomSheet, name: "trashStorageLimit")
        } else {
            UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
        }
    }
}
