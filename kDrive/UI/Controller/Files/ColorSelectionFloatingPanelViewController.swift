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

import FloatingPanel
import InfomaniakCoreUI
import kDriveCore
import kDriveResources
import UIKit

class ColorSelectionFloatingPanelViewController: UICollectionViewController {
    enum Section: CaseIterable {
        case header, colorSelection
    }

    class var sections: [Section] {
        return Section.allCases
    }

    private let folderColors = [
        FolderColor(hex: "#9f9f9f"),
        FolderColor(hex: "#F44336"),
        FolderColor(hex: "#E91E63"),
        FolderColor(hex: "#9C26B0"),
        FolderColor(hex: "#673AB7"),
        FolderColor(hex: "#4051B5"),
        FolderColor(hex: "#4BAF50"),
        FolderColor(hex: "#009688"),
        FolderColor(hex: "#00BCD4"),
        FolderColor(hex: "#02A9F4"),
        FolderColor(hex: "#2196F3"),
        FolderColor(hex: "#8BC34A"),
        FolderColor(hex: "#CDDC3A"),
        FolderColor(hex: "#FFC10A"),
        FolderColor(hex: "#FF9802"),
        FolderColor(hex: "#607D8B"),
        FolderColor(hex: "#795548")
    ]

    struct FolderColor {
        let hex: String

        var color: UIColor? {
            return UIColor(hex: hex)
        }
    }

    var driveFileManager: DriveFileManager!
    var files = [File]()
    weak var floatingPanelController: FloatingPanelController?
    var width = 0.0

    var completionHandler: ((Bool) -> Void)?

    // MARK: - Public methods

    init(files: [File], driveFileManager: DriveFileManager) {
        super.init(collectionViewLayout: ColorSelectionFloatingPanelViewController.createLayout())
        self.files = files
        self.driveFileManager = driveFileManager
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(cellView: ColorSelectionCollectionViewCell.self)
        collectionView.register(WrapperCollectionViewCell.self, forCellWithReuseIdentifier: "WrapperCollectionViewCell")

        setSelectedColor()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        width = Double(floatingPanelController?.view.frame.width ?? 0)
        setUpHeight()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        width = size.width
        setUpHeight()
    }

    // MARK: - Private methods

    private static func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { section, _ in
            switch sections[section] {
            case .header:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(58))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            case .colorSelection:
                let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(40), heightDimension: .absolute(40))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(40))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                group.interItemSpacing = .flexible(16)
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 16
                section.contentInsets = NSDirectionalEdgeInsets(top: 30, leading: 20, bottom: 0, trailing: 20)
                return section
            }
        }
    }

    func setUpHeight() {
        let headerCellHeight = 80.0
        let topInset = 30.0
        let colorWidthAndHeight = 40.0
        let colorSpacing = 16.0
        let leadingTrailingPading = 40.0
        let numberOfColorInARow = ((width - leadingTrailingPading) / (colorWidthAndHeight + colorSpacing)).rounded(.down)
        let numberOfRow = (CGFloat(folderColors.count) / numberOfColorInARow).rounded(.up)
        let height = numberOfRow * (colorWidthAndHeight + colorSpacing) + headerCellHeight + topInset
        floatingPanelController?.layout = PlusButtonFloatingPanelLayout(height: height)
        floatingPanelController?.invalidateLayout()
    }

    func setSelectedColor() {
        if files.count == 1 {
            let selectedColorIndex = folderColors.firstIndex { $0.hex == files.first?.color } ?? 0
            collectionView.selectItem(
                at: IndexPath(row: selectedColorIndex, section: 1),
                animated: true,
                scrollPosition: .init(rawValue: 0)
            )
        }
    }

    // MARK: - Collection view data source & delegate

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Self.sections.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Self.sections[section] {
        case .header:
            return 1
        case .colorSelection:
            return folderColors.count
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Self.sections[indexPath.section] {
        case .header:
            let wrapperCell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "WrapperCollectionViewCell",
                for: indexPath
            ) as! WrapperCollectionViewCell
            let cell = wrapperCell.reuse(withCellType: FloatingPanelSortOptionTableViewCell.self)
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.buttonChangeFolderColor
            cell.isHeader = true
            cell.iconImageView.image = KDriveResourcesAsset.colorBucket.image
            cell.iconImageView.tintColor = KDriveResourcesAsset.iconColor.color
            cell.iconImageView.isHidden = false
            return wrapperCell
        case .colorSelection:
            let cell = collectionView.dequeueReusableCell(type: ColorSelectionCollectionViewCell.self, for: indexPath)
            let color = folderColors[indexPath.row]
            cell.backgroundColor = color.color
            cell.configureCell()
            return cell
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let color = folderColors[indexPath.row]
        let frozenFiles = files.map { $0.freeze() }
        MatomoUtils.track(eventWithCategory: .colorFolder, name: "switch")
        Task {
            do {
                let success = try await withThrowingTaskGroup(of: Bool.self, returning: Bool.self) { group in
                    for file in frozenFiles where file.canBeColored {
                        group.addTask {
                            try await self.driveFileManager.updateColor(directory: file, color: color.hex)
                        }
                    }
                    return try await group.allSatisfy { $0 }
                }
                self.completionHandler?(success)
                self.dismiss(animated: true)
            } catch {
                self.completionHandler?(false)
                UIConstants.showSnackBarIfNeeded(error: error)
                self.dismiss(animated: true)
            }
        }
    }
}
