/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

@testable import kDrive
import kDriveResources
import Testing
import UIKit

@MainActor
@Suite("Shared assets in app nibs")
struct ResourceAssetsTests {
    @Test(arguments: [
        "SelectPhotoFormatFooterView", "RootMenuHeaderView", "ManageCategoriesTableViewCell",
        "DropBoxDisableTableViewCell", "DropBoxLinkTableViewCell", "FileDetailActivityTableViewCell",
        "FileDetailCommentTableViewCell", "FileInformationOwnerTableViewCell", "InfoTableViewCell",
        "ShareLinkAccessRightTableViewCell", "UsersAccessTableViewCell", "NoPreviewCollectionViewCell",
        "PhotoFormatTableViewCell", "RecentSearchCollectionViewCell", "FilesHeaderView",
        "HomeLastPicCollectionViewCell", "InsufficientStorageCollectionViewCell", "RecentActivityCollectionViewCell",
        "UploadsInProgressTableViewCell", "UploadsPausedTableViewCell", "PhotoAccessDeniedTableViewCell",
        "StoreFeatureTableViewCell", "NewFolderLocationTableViewCell"
    ])
    func decorativeOutletsConnectWhenLoadingNib(_ name: String) throws {
        let _: UIView = try loadNib(name)
    }

    @Test func nibResolvesImagesAndDynamicColorsWithoutMainCatalog() throws {
        let view: SelectView = try loadNib("SelectView")
        let button = try #require(view.actionsView.arrangedSubviews.first as? UIButton)
        #expect(button.image(for: .normal) == KDriveResourcesAsset.menu.image)

        let color = try #require(view.backgroundColor)
        for style: UIUserInterfaceStyle in [.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            #expect(color.resolvedColor(with: traits) == KDriveResourcesAsset.backgroundColor.color.resolvedColor(with: traits))
        }
    }

    @Test func fileListAndGridNibsResolveInheritedOutlets() throws {
        let list: FileCollectionViewCell = try loadNib("FileCollectionViewCell")
        let grid: FileGridCollectionViewCell = try loadNib("FileGridCollectionViewCell")
        for cell in [list, grid] {
            #expect(cell.moreButton.image(for: .normal) == KDriveResourcesAsset.menu.image)
            #expect(cell.availableOfflineImageView.image == KDriveResourcesAsset.check.image)
            #expect(cell.highlightedView.backgroundColor == KDriveResourcesAsset.backgroundCardViewSelectedColor.color)
        }
        #expect(grid.largeIconImageView.image == KDriveResourcesAsset.folderFilled.image)
        #expect(grid.iconImageView.image == KDriveResourcesAsset.fileImage.image)
    }

    @Test func uploadNibsConfigureSharedViewInBothLayouts() throws {
        let home: UploadCardCell = try loadNib("UploadCardCell")
        let queue: UploadTableViewCell = try loadNib("UploadTableViewCell")
        for card in [home.uploadCardView!, queue.cardContentView!] {
            #expect(card.titleLabel.textColor == KDriveResourcesAsset.titleColor.color)
            #expect(card.detailsLabel.textColor == KDriveResourcesAsset.secondaryTextColor.color)
        }
        #expect(queue.cardContentView.retryButton?.image(for: .normal) == KDriveResourcesAsset.retry.image)
        #expect(queue.cardContentView.cancelButton?.image(for: .normal) == KDriveResourcesAsset.close.image)
    }

    @Test func buttonTitleStatesSurviveNibLoading() throws {
        let cell: RightsSelectionTableViewCell = try loadNib("RightsSelectionTableViewCell")
        #expect(cell.updateButton.titleColor(for: .normal) == KDriveResourcesAsset.infomaniakColor.color)
    }

    private func loadNib<View: UIView>(_ name: String) throws -> View {
        let objects = try #require(Bundle.main.loadNibNamed(name, owner: nil))
        return try #require(objects.first as? View)
    }
}
